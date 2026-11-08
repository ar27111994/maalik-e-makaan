import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/image_metadata.dart';

List<int> _u16(int value) => [value >> 8 & 0xFF, value & 0xFF];
List<int> _u32(int value) => [..._u16(value >> 16), ..._u16(value & 0xFFFF)];
List<int> _u32le(int value) => _u32(value).reversed.toList();
List<int> _text(String text) => latin1.encode(text);

/// A JPEG segment: its marker and its data, with the length before it.
List<int> _segment(int marker, List<int> data) => [
  0xFF,
  marker,
  ..._u16(data.length + 2),
  ...data,
];

/// An Exif block that says where the photo was taken (a GPS IFD with
/// "N"), as cameras write it: "Exif", then a TIFF header and IFDs.
final List<int> _exif = [
  ..._text('Exif\u0000\u0000'),
  ..._text('MM\u0000*'),
  ..._u32(8),
  // IFD0: one entry, the GPS IFD's offset (tag 0x8825, a LONG).
  ..._u16(1), ..._u16(0x8825), ..._u16(4), ..._u32(1), ..._u32(26),
  ..._u32(0),
  // The GPS IFD: GPSLatitudeRef "N".
  ..._u16(1), ..._u16(1), ..._u16(2), ..._u32(2), ..._text('N\u0000'),
  ..._u16(0), ..._u32(0),
];

final List<int> _xmp = _text(
  'http://ns.adobe.com/xap/1.0/\u0000<x:xmpmeta>'
  '<exif:GPSLatitude>31,31.5N</exif:GPSLatitude></x:xmpmeta>',
);

/// A small real JPEG, as package:image writes it (SOI, APP0, tables,
/// one scan, EOI).
final Uint8List _plainJpeg = img.encodeJpg(
  img.Image(width: 16, height: 8)..clear(img.ColorRgb8(10, 120, 60)),
);

/// [_plainJpeg] with [segments] after its start.
Uint8List _jpegWith(List<List<int>> segments, {List<int> after = const []}) =>
    Uint8List.fromList([
      ..._plainJpeg.sublist(0, 2),
      for (final segment in segments) ...segment,
      ..._plainJpeg.sublist(2),
      ...after,
    ]);

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// A PNG chunk; its checksum is not read, so it is left at zero.
List<int> _chunk(String type, List<int> data) => [
  ..._u32(data.length),
  ..._text(type),
  ...data,
  ..._u32(0),
];

/// A WebP chunk, padded to an even length.
List<int> _webpChunk(String type, List<int> data) => [
  ..._text(type),
  ..._u32le(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

Uint8List _riff(List<int> chunks, {int? size}) => _bytes([
  ..._text('RIFF'),
  ..._u32le(size ?? 4 + chunks.length),
  ..._text('WEBP'),
  ...chunks,
]);

/// An ISO box, and a full box (a version and flags first).
List<int> _box(String type, List<int> body) => [
  ..._u32(8 + body.length),
  ..._text(type),
  ...body,
];
List<int> _fullBox(String type, int version, List<int> body) =>
    _box(type, [version, 0, 0, 0, ...body]);

List<int> _infe(int version, int id, String type, {String? contentType}) =>
    _fullBox('infe', version, [
      if (version == 2) ..._u16(id) else ..._u32(id),
      ..._u16(0), // protection index
      ..._text(type),
      0, // an empty name
      if (contentType != null) ...[..._text(contentType), 0],
    ]);

List<int> _iinf(List<List<int>> entries, {int version = 0}) =>
    _fullBox('iinf', version, [
      if (version == 0) ..._u16(entries.length) else ..._u32(entries.length),
      for (final entry in entries) ...entry,
    ]);

/// An item's location: its id, how it is reached (0: the file, 1: the
/// idat box), and its extents (offset, length).
typedef _Location = ({int id, int method, List<(int, int)> extents});

/// An `iloc` box of [version] with 4-byte offsets and lengths, a 4-byte
/// base offset of [base] when [withBase], and 4-byte extent indexes when
/// [withIndex].
List<int> _iloc(
  List<_Location> items, {
  int version = 0,
  bool withBase = false,
  int base = 0,
  bool withIndex = false,
  int reference = 0,
}) => _fullBox('iloc', version, [
  ..._u16(4 << 12 | 4 << 8 | (withBase ? 4 : 0) << 4 | (withIndex ? 4 : 0)),
  if (version < 2) ..._u16(items.length) else ..._u32(items.length),
  for (final item in items) ...[
    if (version < 2) ..._u16(item.id) else ..._u32(item.id),
    if (version > 0) ..._u16(item.method),
    ..._u16(reference),
    if (withBase) ..._u32(base),
    ..._u16(item.extents.length),
    for (final (offset, length) in item.extents) ...[
      if (withIndex) ..._u32(0),
      ..._u32(offset),
      ..._u32(length),
    ],
  ],
]);

final List<int> _ftyp = _box('ftyp', [
  ..._text('heic'),
  ..._u32(0),
  ..._text('mif1heic'),
]);
final List<int> _picture = _text('HEVC-CODED-PICTURE');
final List<int> _xmpPacket = _text('<x:xmpmeta GPS="31N"/>');

/// A HEIC file: ftyp, then mdat (the picture, the Exif block, the XMP
/// packet), then meta with [meta]'s boxes, which [meta] builds from where
/// each part of mdat starts.
Uint8List _heic(
  List<List<int>> Function(int picture, int exif, int xmp) meta, {
  List<List<int>> after = const [],
}) {
  final mdatBody = [..._picture, ..._exif, ..._xmpPacket];
  final picture = _ftyp.length + 8;
  final exif = picture + _picture.length;
  final xmp = exif + _exif.length;
  return _bytes([
    ..._ftyp,
    ..._box('mdat', mdatBody),
    ..._fullBox('meta', 0, [
      for (final box in meta(picture, exif, xmp)) ...box,
    ]),
    for (final box in after) ...box,
  ]);
}

/// The three items of [_heic]: the picture, Exif and XMP.
List<List<int>> _items({int version = 2}) => [
  _iinf([
    _infe(version, 1, 'hvc1'),
    _infe(version, 2, 'Exif'),
    _infe(version, 3, 'mime', contentType: 'application/rdf+xml'),
  ]),
];

void main() {
  group('JPEG', () {
    test('drops Exif, XMP, IPTC, comments and pictures appended', () {
      final icc = _segment(0xE2, _text('ICC_PROFILE\u0000\u0001\u0001abc'));
      final photo = _jpegWith(
        [
          _segment(0xE1, _exif),
          _segment(0xE1, _xmp),
          _segment(0xED, _text('Photoshop 3.0\u00008BIM')),
          _segment(0xFE, _text('Taken at home')),
          _segment(0xE2, _text('MPF\u0000II*\u0000')),
          icc,
        ],
        // A second picture after the end of the image, with its own Exif.
        after: [0xFF, 0xD8, ..._segment(0xE1, _exif), 0xFF, 0xD9],
      );
      final cleaned = withoutMetadata(photo, DocumentFileType.jpeg)!;
      expect(cleaned, [
        ..._plainJpeg.sublist(0, 2),
        ...icc,
        ..._plainJpeg.sublist(2),
      ]);
      expect(_contains(cleaned, _text('Exif')), isFalse);
      expect(_contains(cleaned, _text('GPS')), isFalse);
      expect(img.decodeJpg(cleaned)!.width, 16);
    });

    test('a JPEG without metadata is unchanged', () {
      expect(withoutMetadata(_plainJpeg, DocumentFileType.jpeg), _plainJpeg);
    });

    test('reads fill bytes, restart markers and progressive scans', () {
      final scanHeader = _segment(0xDA, [1, 1, 0, 0, 63, 0]);
      final photo = _bytes([
        0xFF, 0xD8,
        0xFF, 0xFF, 0xFF, 0x01, // a fill byte, then TEM
        ..._segment(0xDB, List.filled(65, 1)),
        ...scanHeader,
        0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD0, 0x56, // stuffed byte, RST0
        ..._segment(0xE1, _exif), // between scans
        ..._segment(0xC4, [0, 1, 2]),
        ...scanHeader,
        0x78,
        0xFF, 0xD9,
      ]);
      expect(withoutMetadata(photo, DocumentFileType.jpeg), [
        0xFF,
        0xD8,
        0xFF,
        0x01,
        ..._segment(0xDB, List.filled(65, 1)),
        ...scanHeader,
        0x12,
        0xFF,
        0x00,
        0x34,
        0xFF,
        0xD0,
        0x56,
        ..._segment(0xC4, [0, 1, 2]),
        ...scanHeader,
        0x78,
        0xFF,
        0xD9,
      ]);
    });

    test('a damaged JPEG cannot be cleaned', () {
      Uint8List? clean(List<int> bytes) =>
          withoutMetadata(_bytes(bytes), DocumentFileType.jpeg);
      // Not a JPEG start; too short.
      expect(clean([0xFF, 0xD9, 0, 0]), isNull);
      expect(clean([0xFF, 0xD8]), isNull);
      // Something other than a marker where one should be.
      expect(clean([0xFF, 0xD8, 0x00, 0xE1, 0, 2]), isNull);
      // A segment's length cut short, too small, or past the end.
      expect(clean([0xFF, 0xD8, 0xFF, 0xE1, 0]), isNull);
      expect(clean([0xFF, 0xD8, 0xFF, 0xE1, 0, 1, 0xFF, 0xD9]), isNull);
      expect(clean([0xFF, 0xD8, 0xFF, 0xE1, 0, 9, 1, 2]), isNull);
      // A scan, or the file, that ends before the end of the image.
      expect(
        clean([
          0xFF,
          0xD8,
          ..._segment(0xDA, [1]),
          1,
          2,
          3,
        ]),
        isNull,
      );
      expect(
        clean([
          0xFF,
          0xD8,
          ..._segment(0xDB, [1]),
        ]),
        isNull,
      );
      expect(clean(_plainJpeg.sublist(0, _plainJpeg.length - 2)), isNull);
    });
  });

  group('PNG', () {
    final plain = img.encodePng(img.Image(width: 4, height: 4));
    // The chunks after the signature and IHDR (8 + 25 bytes).
    Uint8List withChunks(List<List<int>> chunks) => _bytes([
      ...plain.sublist(0, 33),
      for (final chunk in chunks) ...chunk,
      ...plain.sublist(33),
    ]);

    test('drops Exif, text, XMP and time chunks', () {
      final kept = _chunk('gAMA', _u32(45455));
      final photo = withChunks([
        _chunk('eXIf', _exif.sublist(6)),
        _chunk('tEXt', _text('Location\u0000Lahore')),
        _chunk('zTXt', _text('Comment\u0000\u0000x')),
        _chunk(
          'iTXt',
          _text('XML:com.adobe.xmp\u0000\u0000\u0000\u0000\u0000'),
        ),
        _chunk('tIME', [7, 234, 11, 1, 10, 0, 0]),
        kept,
      ]);
      final cleaned = withoutMetadata(photo, DocumentFileType.png)!;
      expect(cleaned, withChunks([kept]));
      expect(img.decodePng(cleaned)!.width, 4);
    });

    test('a damaged PNG cannot be cleaned', () {
      expect(
        withoutMetadata(_bytes(_text('GIF89a')), DocumentFileType.png),
        isNull,
      );
      // A chunk longer than the file; no end chunk.
      expect(
        withoutMetadata(
          _bytes([...plain.sublist(0, 8), ..._u32(999), ..._text('IDAT')]),
          DocumentFileType.png,
        ),
        isNull,
      );
      expect(
        withoutMetadata(
          plain.sublist(0, plain.length - 12),
          DocumentFileType.png,
        ),
        isNull,
      );
    });
  });

  group('WebP', () {
    // VP8X: flags (ICC 0x20, alpha 0x10, Exif 0x08, XMP 0x04), then three
    // reserved bytes and the canvas size.
    List<int> vp8x(int flags) =>
        _webpChunk('VP8X', [flags, 0, 0, 0, 1, 0, 0, 1, 0, 0]);
    final picture = _webpChunk('VP8L', [0x2F, 1, 2, 3, 4]);

    test('drops the Exif and XMP chunks and their flags', () {
      final photo = _riff([
        ...vp8x(0x10 | 0x08 | 0x04),
        ...picture,
        ..._webpChunk('EXIF', _exif.sublist(6)),
        ..._webpChunk('XMP ', _xmpPacket),
      ]);
      expect(
        withoutMetadata(photo, DocumentFileType.webp),
        _riff([...vp8x(0x10), ...picture]),
      );
    });

    test('a simple WebP is unchanged; trailing bytes are dropped', () {
      final simple = _riff(picture);
      expect(withoutMetadata(simple, DocumentFileType.webp), simple);
      expect(
        withoutMetadata(_bytes([...simple, 1, 2]), DocumentFileType.webp),
        simple,
      );
      final emptyHeader = _riff(_webpChunk('VP8X', const []));
      expect(withoutMetadata(emptyHeader, DocumentFileType.webp), emptyHeader);
    });

    test('a damaged WebP cannot be cleaned', () {
      expect(
        withoutMetadata(_bytes(_text('RIFF')), DocumentFileType.webp),
        isNull,
      );
      // The RIFF says it is longer than the file.
      expect(
        withoutMetadata(_riff(picture, size: 999), DocumentFileType.webp),
        isNull,
      );
      // A chunk longer than the RIFF; bytes left over that are no chunk.
      expect(
        withoutMetadata(
          _riff([..._text('VP8L'), ..._u32le(99), 1]),
          DocumentFileType.webp,
        ),
        isNull,
      );
      expect(
        withoutMetadata(_riff([...picture, 1, 2, 3]), DocumentFileType.webp),
        isNull,
      );
    });
  });

  group('HEIC', () {
    test('blanks the Exif and XMP items in place', () {
      final photo = _heic(
        (picture, exif, xmp) => [
          _fullBox('hdlr', 0, [
            ..._u32(0),
            ..._text('pict'),
            ...List.filled(13, 0),
          ]),
          ..._items(),
          _iloc([
            (id: 1, method: 0, extents: [(picture, _picture.length)]),
            (id: 2, method: 0, extents: [(exif, _exif.length)]),
            (id: 3, method: 0, extents: [(xmp, _xmpPacket.length)]),
          ]),
        ],
      );
      final exif = _ftyp.length + 8 + _picture.length;
      final xmp = exif + _exif.length;
      expect(
        withoutMetadata(photo, DocumentFileType.heic),
        Uint8List.fromList(photo)
          ..fillRange(exif, exif + _exif.length, 0)
          ..fillRange(xmp, xmp + _xmpPacket.length, 0),
      );
    });

    test('reads every version of the item boxes', () {
      for (final version in [1, 2]) {
        final photo = _heic(
          (picture, exif, xmp) => [
            _iinf([
              _infe(0, 9, 'ignored'),
              _infe(3, 2, 'Exif'),
              _infe(3, 3, 'mime', contentType: 'application/rdf+xml'),
              _infe(3, 4, 'mime', contentType: 'image/jpeg'),
              _box('free', const []),
            ], version: 1),
            _iloc(
              [
                // Base offsets and extent indexes; Exif in two extents.
                (
                  id: 2,
                  method: 0,
                  extents: [(exif - 4, 10), (exif + 6 - 4, _exif.length - 6)],
                ),
                (id: 3, method: 0, extents: [(xmp - 4, 0)]),
              ],
              version: version,
              withBase: true,
              base: 4,
              withIndex: true,
            ),
          ],
        );
        final cleaned = withoutMetadata(photo, DocumentFileType.heic)!;
        expect(_contains(cleaned, _text('Exif')), isFalse, reason: '$version');
        // A length of zero runs to the end: the XMP and the meta after it.
        expect(cleaned.sublist(photo.length - 10), List.filled(10, 0));
      }
    });

    test('blanks an item kept in the idat box', () {
      final photo = _heic(
        (picture, exif, xmp) => [
          _iinf([_infe(2, 2, 'Exif')]),
          _iloc([
            (id: 2, method: 1, extents: [(2, 6)]),
          ], version: 1),
          _box('idat', [7, 7, ..._text('Exif\u0000\u0000'), 1]),
        ],
      );
      final cleaned = withoutMetadata(photo, DocumentFileType.heic)!;
      expect(cleaned.sublist(cleaned.length - 9), [
        7,
        7,
        ...List.filled(6, 0),
        1,
      ]);
      expect(
        cleaned.sublist(0, cleaned.length - 9),
        photo.sublist(0, photo.length - 9),
      );
    });

    test('reads 8-byte base offsets', () {
      final photo = _heic(
        (picture, exif, xmp) => [
          _iinf([_infe(2, 2, 'Exif')]),
          _fullBox('iloc', 0, [
            ..._u16(4 << 12 | 4 << 8 | 8 << 4),
            ..._u16(1),
            ..._u16(2),
            ..._u16(0),
            ..._u32(0),
            ..._u32(exif),
            ..._u16(1),
            ..._u32(0),
            ..._u32(_exif.length),
          ]),
        ],
      );
      final exif = _ftyp.length + 8 + _picture.length;
      expect(
        withoutMetadata(photo, DocumentFileType.heic),
        Uint8List.fromList(photo)..fillRange(exif, exif + _exif.length, 0),
      );
    });

    test('files without metadata items are unchanged', () {
      final noMeta = _bytes([..._ftyp, ..._box('mdat', _picture)]);
      expect(withoutMetadata(noMeta, DocumentFileType.heic), noMeta);
      final noInfo = _heic((p, e, x) => [_box('pitm', _u16(1))]);
      expect(withoutMetadata(noInfo, DocumentFileType.heic), noInfo);
      final pictureOnly = _heic(
        (p, e, x) => [
          _iinf([_infe(2, 1, 'hvc1')]),
        ],
      );
      expect(withoutMetadata(pictureOnly, DocumentFileType.heic), pictureOnly);
      // A box of size 0 runs to the end; one of size 1 has a 64-bit size.
      final open = _bytes([..._ftyp, ..._u32(0), ..._text('mdat'), 1, 2]);
      expect(withoutMetadata(open, DocumentFileType.heic), open);
      final large = _bytes([
        ..._ftyp,
        ..._u32(1),
        ..._text('mdat'),
        ..._u32(0),
        ..._u32(18),
        1,
        2,
      ]);
      expect(withoutMetadata(large, DocumentFileType.heic), large);
    });

    test('a HEIF it cannot read through is refused', () {
      Uint8List? clean(Uint8List bytes) =>
          withoutMetadata(bytes, DocumentFileType.heic);
      List<List<int>> exifAt(int exif, {int method = 0}) => [
        ..._items(),
        _iloc([
          (id: 2, method: method, extents: [(exif, _exif.length)]),
        ], version: method == 0 ? 0 : 1),
      ];
      // Boxes that do not fit the file.
      expect(clean(_bytes([..._ftyp, ..._u32(99), ..._text('mdat')])), isNull);
      expect(clean(_bytes([..._ftyp, ..._u32(4), ..._text('mdat')])), isNull);
      expect(clean(_bytes([..._ftyp, 0, 0, 0])), isNull);
      expect(
        clean(_bytes([..._ftyp, ..._u32(1), ..._text('mdat'), 0])),
        isNull,
      );
      // An image sequence.
      expect(
        clean(_heic((p, e, x) => const [], after: [_box('moov', const [])])),
        isNull,
      );
      // A meta box whose boxes do not fit it.
      expect(
        clean(
          _heic(
            (p, e, x) => [
              [..._u32(99), ..._text('iinf')],
            ],
          ),
        ),
        isNull,
      );
      // Item boxes cut short.
      expect(clean(_heic((p, e, x) => [_box('iinf', const [])])), isNull);
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _fullBox('iinf', 1, [0]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _iinf([
                [..._u32(99), ..._text('infe')],
              ]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _iinf([_box('infe', const [])]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _iinf([
                _fullBox('infe', 2, [0, 1]),
              ]),
            ],
          ),
        ),
        isNull,
      );
      // A mime item without the zero that ends its name or its type.
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _iinf([
                _fullBox('infe', 2, [0, 3, 0, 0, ..._text('mime')]),
              ]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              _iinf([
                _fullBox('infe', 2, [
                  0,
                  3,
                  0,
                  0,
                  ..._text('mime'),
                  0,
                  ..._text('text'),
                ]),
              ]),
            ],
          ),
        ),
        isNull,
      );
      // Exif listed, but nowhere located.
      expect(clean(_heic((p, e, x) => _items())), isNull);
      // A location cut short, of an unknown version or field size.
      expect(
        clean(
          _heic(
            (p, e, x) => [
              ..._items(),
              _box('iloc', [0]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              ..._items(),
              _fullBox('iloc', 0, [0x44]),
            ],
          ),
        ),
        isNull,
      );
      expect(
        clean(_heic((p, e, x) => [..._items(), _fullBox('iloc', 3, _u16(0))])),
        isNull,
      );
      expect(
        clean(
          _heic(
            (p, e, x) => [
              ..._items(),
              _fullBox('iloc', 0, [
                ..._u16(0x3400),
                ..._u16(1),
                ..._u16(2),
                ..._u16(0),
                ..._u16(1),
                0,
                0,
                0,
                ..._u32(5),
              ]),
            ],
          ),
        ),
        isNull,
      );
      // Exif in another file, located inside another item, or in an idat
      // box that is not there.
      expect(
        clean(
          _heic(
            (p, e, x) => [
              ..._items(),
              _iloc([
                (id: 2, method: 0, extents: [(e, 4)]),
              ], reference: 1),
            ],
          ),
        ),
        isNull,
      );
      expect(clean(_heic((p, e, x) => exifAt(e, method: 2))), isNull);
      expect(clean(_heic((p, e, x) => exifAt(0, method: 1))), isNull);
      // Exif past the end of the file.
      expect(clean(_heic((p, e, x) => exifAt(99999))), isNull);
    });
  });

  test('a PDF is not a photo', () {
    expect(
      () => withoutMetadata(Uint8List(4), DocumentFileType.pdf),
      throwsArgumentError,
    );
  });
}
