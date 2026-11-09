import 'dart:convert';
import 'dart:typed_data';

import 'package:maalik_e_makaan/src/features/documents/data/document.dart';

/// [bytes], a photo of [type], without the metadata cameras and phones
/// write into it: where it was taken (GPS), the device, the time, and
/// notes. The picture itself is left exactly as it is.
///
/// This is for photos kept as they are because this device cannot decode
/// them (HEIC in most browsers); every photo that can be decoded is saved
/// again from its pixels instead, which leaves all metadata behind.
///
/// - JPEG: the APP1 (Exif, XMP), APP13 (IPTC) and comment segments and
///   the multi-picture index are dropped, and so is anything after the
///   end of the image (the extra pictures phones append);
/// - PNG: the `eXIf`, `tEXt`, `zTXt`, `iTXt` and `tIME` chunks are dropped;
/// - WebP: the `EXIF` and `XMP ` chunks are dropped, with their flags;
/// - HEIC: the bytes of the Exif and XMP items are overwritten with
///   zeros, which keeps every offset in the file valid.
///
/// Returns null when the file's structure cannot be read (a damaged or
/// truncated file, or a HEIF image sequence), so that a file whose
/// metadata could not be removed is never uploaded.
Uint8List? withoutMetadata(Uint8List bytes, DocumentFileType type) =>
    switch (type) {
      DocumentFileType.jpeg => _jpeg(bytes),
      DocumentFileType.png => _png(bytes),
      DocumentFileType.webp => _webp(bytes),
      DocumentFileType.heic => _heif(bytes),
      DocumentFileType.pdf => throw ArgumentError.value(
        type,
        'type',
        'not a photo',
      ),
    };

// JPEG ----------------------------------------------------------------------

/// The segments that hold metadata: APP1 (Exif, XMP), APP13 (Photoshop's
/// IPTC) and comments.
const _jpegMetadata = {0xE1, 0xED, 0xFE};

/// The start of an APP2 segment's data that marks the multi-picture
/// index, whose pictures follow the end of the image and are dropped.
const _mpf = [0x4D, 0x50, 0x46, 0x00]; // MPF and a zero

Uint8List? _jpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  final out = BytesBuilder(copy: false)..add(_view(bytes, 0, 2));
  var i = 2;
  while (i + 1 < bytes.length) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    // Fill bytes before a marker.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    // The end of the image: anything after it is not part of it.
    if (marker == 0xD9) {
      out.add(_view(bytes, i, i + 2));
      return out.takeBytes();
    }
    // Markers without a length: TEM and the restart markers.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.add(_view(bytes, i, i + 2));
      i += 2;
      continue;
    }
    if (i + 4 > bytes.length) return null;
    final length = bytes[i + 2] << 8 | bytes[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > bytes.length) return null;
    if (marker == 0xDA) {
      // A scan: its header, then entropy-coded data up to the next marker
      // (a 0xFF in the data is followed by 0x00 or is a restart marker).
      var j = end;
      while (j + 1 < bytes.length) {
        if (bytes[j] == 0xFF) {
          final next = bytes[j + 1];
          if (next != 0x00 && (next < 0xD0 || next > 0xD7)) break;
          j += 2;
        } else {
          j++;
        }
      }
      if (j + 1 >= bytes.length) return null;
      out.add(_view(bytes, i, j));
      i = j;
      continue;
    }
    final multiPicture =
        marker == 0xE2 && _startsWith(bytes, _mpf, at: i + 4, before: end);
    if (!_jpegMetadata.contains(marker) && !multiPicture) {
      out.add(_view(bytes, i, end));
    }
    i = end;
  }
  // The file ends before the end of the image.
  return null;
}

// PNG -----------------------------------------------------------------------

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// The chunks that hold metadata: Exif, text (where XMP also goes) and the
/// time the image was last changed.
const _pngMetadata = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};

Uint8List? _png(Uint8List bytes) {
  if (!_startsWith(bytes, _pngSignature, at: 0, before: bytes.length)) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  final out = BytesBuilder(copy: false)..add(_view(bytes, 0, 8));
  var i = 8;
  // Each chunk: its length, its type, its data and a checksum.
  while (i + 12 <= bytes.length) {
    final end = i + 12 + data.getUint32(i);
    if (end > bytes.length) return null;
    final type = latin1.decode(_view(bytes, i + 4, i + 8));
    if (!_pngMetadata.contains(type)) out.add(_view(bytes, i, end));
    if (type == 'IEND') return out.takeBytes();
    i = end;
  }
  return null;
}

// WebP ----------------------------------------------------------------------

/// The flags of the `VP8X` chunk that say Exif or XMP chunks follow.
const _webpExifFlag = 0x08;
const _webpXmpFlag = 0x04;

Uint8List? _webp(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final data = ByteData.sublistView(bytes);
  final riffEnd = 8 + data.getUint32(4, Endian.little);
  if (riffEnd > bytes.length) return null;
  final chunks = BytesBuilder(copy: false);
  var i = 12;
  // Each chunk: its type, its length, its data and a padding byte when the
  // length is odd.
  while (i + 8 <= riffEnd) {
    final length = data.getUint32(i + 4, Endian.little);
    final end = i + 8 + length + (length & 1);
    if (end > riffEnd) return null;
    final type = latin1.decode(_view(bytes, i, i + 4));
    if (type == 'VP8X' && length > 0) {
      final chunk = Uint8List.fromList(_view(bytes, i, end));
      chunk[8] &= ~(_webpExifFlag | _webpXmpFlag);
      chunks.add(chunk);
    } else if (type != 'EXIF' && type != 'XMP ') {
      chunks.add(_view(bytes, i, end));
    }
    i = end;
  }
  if (i != riffEnd) return null;
  final body = chunks.takeBytes();
  final header = ByteData(12)
    ..setUint32(0, 0x52494646) // RIFF
    ..setUint32(4, 4 + body.length, Endian.little)
    ..setUint32(8, 0x57454250); // WEBP
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(body))
      .takeBytes();
}

// HEIF ----------------------------------------------------------------------

/// A box of an ISO base media file: its type, where its contents start
/// and where it ends.
typedef _Box = ({String type, int start, int end});

/// The boxes from [from] to [to], or null when one does not fit.
List<_Box>? _boxes(ByteData data, int from, int to) {
  final boxes = <_Box>[];
  var i = from;
  while (i < to) {
    if (i + 8 > to) return null;
    var size = data.getUint32(i);
    var header = 8;
    if (size == 1) {
      if (i + 16 > to) return null;
      size = _uint64(data, i + 8);
      header = 16;
    } else if (size == 0) {
      size = to - i;
    }
    if (size < header || i + size > to) return null;
    final type = latin1.decode(
      data.buffer.asUint8List(data.offsetInBytes + i + 4, 4),
    );
    boxes.add((type: type, start: i + header, end: i + size));
    i += size;
  }
  return boxes;
}

_Box? _find(List<_Box> boxes, String type) {
  for (final box in boxes) {
    if (box.type == type) return box;
  }
  return null;
}

/// The XMP item's content type.
const _xmpType = 'application/rdf+xml';

Uint8List? _heif(Uint8List bytes) {
  final copy = Uint8List.fromList(bytes);
  final data = ByteData.sublistView(copy);
  final top = _boxes(data, 0, copy.length);
  if (top == null) return null;
  // An image sequence keeps its metadata in its tracks too.
  if (_find(top, 'moov') != null) return null;
  final meta = _find(top, 'meta');
  if (meta == null) return copy;
  // The meta box is a full box: a version and flags before its boxes.
  final inside = _boxes(data, meta.start + 4, meta.end);
  if (inside == null) return null;
  final info = _find(inside, 'iinf');
  final locations = _find(inside, 'iloc');
  if (info == null) return copy;
  final items = _metadataItems(data, info);
  if (items == null) return null;
  if (items.isEmpty) return copy;
  if (locations == null) return null;
  final ranges = _itemRanges(data, locations, items, _find(inside, 'idat'));
  if (ranges == null) return null;
  for (final (start, end) in ranges) {
    copy.fillRange(start, end, 0);
  }
  return copy;
}

/// The ids of the Exif and XMP items listed in [info] (`iinf`), or null
/// when it cannot be read.
Set<int>? _metadataItems(ByteData data, _Box info) {
  if (info.start + 4 > info.end) return null;
  final version = data.getUint8(info.start);
  final first = info.start + 4 + (version == 0 ? 2 : 4);
  if (first > info.end) return null;
  final entries = _boxes(data, first, info.end);
  if (entries == null) return null;
  final ids = <int>{};
  for (final entry in entries) {
    if (entry.type != 'infe') continue;
    if (entry.start + 4 > entry.end) return null;
    final version = data.getUint8(entry.start);
    // Versions 0 and 1 describe files, not typed items.
    if (version < 2) continue;
    final idSize = version == 2 ? 2 : 4;
    var i = entry.start + 4;
    if (i + idSize + 6 > entry.end) return null;
    final id = idSize == 2 ? data.getUint16(i) : data.getUint32(i);
    // The protection index follows the id.
    i += idSize + 2;
    final type = latin1.decode(
      data.buffer.asUint8List(data.offsetInBytes + i, 4),
    );
    i += 4;
    if (type == 'Exif') {
      ids.add(id);
    } else if (type == 'mime') {
      // The item's name, then its content type, each ending with a zero.
      final name = _zeroEnded(data, i, entry.end);
      if (name == null) return null;
      final content = _zeroEnded(data, name.next, entry.end);
      if (content == null) return null;
      if (content.text == _xmpType) ids.add(id);
    }
  }
  return ids;
}

/// The text from [from] up to a zero byte before [to], and where the next
/// field starts; null without a zero.
({String text, int next})? _zeroEnded(ByteData data, int from, int to) {
  for (var i = from; i < to; i++) {
    if (data.getUint8(i) == 0) {
      return (
        text: utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes + from, i - from),
          allowMalformed: true,
        ),
        next: i + 1,
      );
    }
  }
  return null;
}

/// Where the bytes of [items] are, from [locations] (`iloc`): offsets in
/// the file, or in [idat]'s data. Null when it cannot be read, or an
/// item's bytes are somewhere this does not reach (another file, or
/// another item).
List<(int, int)>? _itemRanges(
  ByteData data,
  _Box locations,
  Set<int> items,
  _Box? idat,
) {
  // A full box: its version, and flags this does not need.
  if (locations.start + 4 > locations.end) return null;
  final version = data.getUint8(locations.start);
  if (version > 2) return null;
  var i = locations.start + 4;
  // The next field, of [size] bytes (0, 2, 4 or 8).
  int read(int size) {
    if (i + size > locations.end) throw const FormatException('iloc');
    final value = switch (size) {
      0 => 0,
      2 => data.getUint16(i),
      4 => data.getUint32(i),
      8 => _uint64(data, i),
      _ => throw const FormatException('iloc field size'),
    };
    i += size;
    return value;
  }

  try {
    final sizes = read(2);
    final offsetSize = sizes >> 12;
    final lengthSize = (sizes >> 8) & 0xF;
    final baseOffsetSize = (sizes >> 4) & 0xF;
    final indexSize = version == 0 ? 0 : sizes & 0xF;
    final count = read(version < 2 ? 2 : 4);
    final ranges = <(int, int)>[];
    for (var n = 0; n < count; n++) {
      final id = read(version < 2 ? 2 : 4);
      final method = version == 0 ? 0 : read(2) & 0xF;
      final reference = read(2);
      final baseOffset = read(baseOffsetSize);
      final extents = read(2);
      final wanted = items.contains(id);
      if (wanted && (reference != 0 || method > 1)) return null;
      final (origin, limit) = method == 1
          ? (idat?.start, idat?.end)
          : (0, data.lengthInBytes);
      for (var e = 0; e < extents; e++) {
        read(indexSize);
        final offset = read(offsetSize);
        final length = read(lengthSize);
        if (!wanted) continue;
        if (origin == null || limit == null) return null;
        final start = origin + baseOffset + offset;
        // A length of zero: to the end of the data.
        final end = length == 0 ? limit : start + length;
        if (start > end || end > limit) return null;
        ranges.add((start, end));
      }
    }
    return ranges;
  } on FormatException {
    return null;
  }
}

// Helpers -------------------------------------------------------------------

/// The 64-bit big-endian number at [i], read as two halves: compiled to
/// JavaScript, `ByteData.getUint64` is not supported.
int _uint64(ByteData data, int i) =>
    data.getUint32(i) * 0x100000000 + data.getUint32(i + 4);

Uint8List _view(Uint8List bytes, int start, int end) =>
    Uint8List.sublistView(bytes, start, end);

/// Whether [bytes] hold [prefix] at [at], ending before [before].
bool _startsWith(
  Uint8List bytes,
  List<int> prefix, {
  required int at,
  required int before,
}) {
  if (at + prefix.length > before) return false;
  for (var k = 0; k < prefix.length; k++) {
    if (bytes[at + k] != prefix[k]) return false;
  }
  return true;
}
