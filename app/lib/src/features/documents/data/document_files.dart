import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/image_metadata.dart';
import 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder.dart';

/// A file the landlord picked, before it is checked and made smaller.
@immutable
final class ChosenFile {
  const new({required this.name, required this.bytes});

  /// Its name where it was picked ("IMG_2034.jpg"), without folders.
  final String name;
  final Uint8List bytes;
}

/// Where files come from: the camera and the device's files. Each method
/// returns null when the landlord cancels, and throws [AppFailure].
abstract interface class DocumentPicker {
  /// A photo taken now with the camera.
  Future<ChosenFile?> takePhoto();

  /// A photo or PDF chosen from the device.
  Future<ChosenFile?> chooseFile();

  /// The photo the camera took after Android closed the app behind it (a
  /// phone short of memory may), which the camera plugin keeps for the
  /// app's next start: it is handed over once, and null means there is
  /// none. Throws [AppFailure] when taking it had failed, as [takePhoto]
  /// would have.
  ///
  /// Only Android loses photos this way: on iOS and the web there is
  /// nothing to recover, and this is not called there (`lostPhotoProvider`
  /// asks `cameraLosesPhotosProvider` first).
  Future<ChosenFile?> recoverLostPhoto();
}

/// The extensions the file chooser offers: the types the bucket accepts.
const pickableExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'pdf',
];

/// The largest photo read to be made smaller (a 200-megapixel camera's
/// JPEG is about 40 MB); a PDF must fit the bucket as it is.
const int maxPickedImageBytes = 50 * 1024 * 1024;

/// [DocumentPicker] over image_picker (the camera, which it asks to keep
/// photos to 2048 px and to compress them, and the photo it keeps when
/// Android closed the app behind it) and file_picker (the device's files,
/// filtered to [pickableExtensions]); both work on Android, iOS and the
/// web.
///
/// On a phone both plugins hand over a copy in the app's cache or
/// temporary folder (a photo of a CNIC, an agreement under its own name).
/// Once its bytes are read, or it is refused, the copy goes to `discard`
/// (the app's `DeviceScratch.discard`), so it does not wait on the phone
/// for the next sign-out.
final class PluginDocumentPicker implements DocumentPicker {
  new({ImagePicker? camera, this._discard = _keepCopies})
    : _camera = camera ?? ImagePicker();

  final ImagePicker _camera;
  final Future<void> Function(Iterable<String> paths) _discard;

  static Future<void> _keepCopies(Iterable<String> paths) async {}

  /// The longest side the camera keeps, before [prepareFile] makes the
  /// photo smaller still.
  static const cameraMaxSide = 2048.0;

  @override
  Future<ChosenFile?> takePhoto() => _guard(() async {
    final photo = await _camera.pickImage(
      source: ImageSource.camera,
      maxWidth: cameraMaxSide,
      maxHeight: cameraMaxSide,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (photo == null) return null;
    try {
      return ChosenFile(name: photo.name, bytes: await photo.readAsBytes());
    } finally {
      await _discard([photo.path]);
    }
  });

  @override
  Future<ChosenFile?> recoverLostPhoto() => _guard(() async {
    final lost = await _camera.retrieveLostData();
    if (lost.isEmpty) return null;
    // The camera's refusal before the app closed, as takePhoto throws it.
    if (lost.exception case final exception?) throw exception;
    final photo = lost.file;
    if (photo == null) return null;
    try {
      // The app takes only photos (never videos) with image_picker.
      if (lost.type != RetrieveType.image) return null;
      return ChosenFile(name: photo.name, bytes: await photo.readAsBytes());
    } on Exception catch (error) {
      // The kept photo is gone: Android cleared the app's cache since.
      throw AppFailure.from(error);
    } finally {
      // image_picker resized the photo only now, and left the camera's
      // full-size original next to the copy it handed over.
      await _discard([photo.path, ?cameraOriginalOf(photo.path)]);
    }
  });

  @override
  Future<ChosenFile?> chooseFile() => _guard(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: pickableExtensions,
    );
    if (file == null) return null;
    try {
      final length = file.lengthSync() ?? await file.length();
      if (length != null && length > maxPickedImageBytes) {
        throw const RejectedFailure('file_too_large');
      }
      return ChosenFile(name: file.name, bytes: await file.readAsBytes());
    } finally {
      // On the web the file is in memory and has no path.
      await _discard([?file.path]);
    }
  });

  Future<T> _guard<T>(Future<T> Function() pick) async {
    try {
      return await pick();
    } on PlatformException catch (error) {
      // image_picker's `camera_access_denied` and `photo_access_denied`,
      // and the file pickers' refusals of the same kind.
      if (error.code.contains('denied') || error.code.contains('permission')) {
        throw const RejectedFailure('picker_access_denied');
      }
      throw AppFailure.from(error);
    }
  }
}

final Provider<DocumentPicker> documentPickerProvider =
    Provider<DocumentPicker>(
      (ref) => PluginDocumentPicker(
        discard: ref.watch(deviceScratchProvider).discard,
      ),
    );

/// Makes picked files ready to upload. Tests replace it.
typedef FilePreparer = Future<PreparedFile> Function(ChosenFile file);

final Provider<FilePreparer> filePreparerProvider = Provider<FilePreparer>(
  (ref) => prepareFile,
);

/// The size a photo is made smaller to (DOC-02: about 300 KB).
const int targetImageBytes = 300 * 1024;

/// The longest side and JPEG quality tried in turn, until a photo fits
/// [targetImageBytes]: 1600 px keeps a CNIC or an agreement readable.
const compressionSteps = <(int, int)>[
  (1600, 80),
  (1600, 65),
  (1280, 65),
  (1024, 60),
  (800, 55),
];

/// [file] checked and ready to upload (DOC-01, DOC-02):
///
/// - its type is read from its bytes, and must be one the bucket accepts
///   (`file_type_not_allowed`);
/// - a photo this device can decode is saved again from its pixels, as a
///   JPEG: decoded by the platform (which turns it upright), scaled down
///   and encoded in the steps of [compressionSteps] until it fits
///   [targetImageBytes], transparent parts turned white. Whatever its
///   size, this leaves behind the metadata the camera wrote into it:
///   where it was taken, the device and the time;
/// - a photo this device cannot decode (HEIC in a browser) is kept as it
///   is, without its metadata ([withoutMetadata]); one whose structure
///   cannot be read either is refused (`file_unreadable`);
/// - a PDF is kept as it is;
/// - what is left must fit the bucket's 10 MB (`file_too_large`).
Future<PreparedFile> prepareFile(ChosenFile file) async {
  final bytes = file.bytes;
  final type = DocumentFileType.sniff(bytes);
  if (type == null) throw const RejectedFailure('file_type_not_allowed');
  final name = _baseName(file.name);
  var prepared = PreparedFile(
    name: name,
    bytes: bytes,
    type: type,
    originalSize: bytes.length,
  );
  if (type.isImage) {
    final jpeg = await _saveAgain(bytes);
    if (jpeg != null) {
      prepared = PreparedFile(
        name: name,
        bytes: jpeg,
        type: DocumentFileType.jpeg,
        originalSize: bytes.length,
      );
    } else {
      final kept = withoutMetadata(bytes, type);
      if (kept == null) throw const RejectedFailure('file_unreadable');
      // Taking the metadata out is not making the photo smaller.
      prepared = PreparedFile(
        name: name,
        bytes: kept,
        type: type,
        originalSize: kept.length,
      );
    }
  }
  if (prepared.size > Document.maxSizeBytes) {
    throw const RejectedFailure('file_too_large');
  }
  return prepared;
}

/// [name] without its folders and its extension: "IMG_2034".
String _baseName(String name) {
  final file = name.split(RegExp(r'[/\\]')).last;
  final dot = file.lastIndexOf('.');
  return dot > 0 ? file.substring(0, dot) : file;
}

/// [bytes] saved again as a JPEG: the first of the steps that fits, or
/// the smallest when none does; null when this device cannot decode
/// them.
Future<Uint8List?> _saveAgain(Uint8List bytes) async {
  Uint8List? best;
  int? decodedSide;
  RgbaPixels? pixels;
  for (final (side, quality) in compressionSteps) {
    if (side != decodedSide) {
      pixels = await _decode(bytes, side);
      if (pixels == null) return best;
      decodedSide = side;
    }
    final jpeg = await encodeJpeg(pixels!, quality);
    if (best == null || jpeg.length < best.length) best = jpeg;
    if (jpeg.length <= targetImageBytes) break;
  }
  return best;
}

/// [bytes] decoded by the platform's codecs (on the web, the browser's),
/// scaled so that the longer side is at most [maxSide]; null when they
/// cannot be decoded here.
Future<RgbaPixels?> _decode(Uint8List bytes, int maxSide) async {
  try {
    final codec = await ui.instantiateImageCodecWithSize(
      // The codec takes the buffer and disposes it.
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (width, height) {
        final longer = math.max(width, height);
        if (longer <= maxSide) return const ui.TargetImageSize();
        final scale = maxSide / longer;
        return ui.TargetImageSize(
          width: math.max(1, (width * scale).round()),
          height: math.max(1, (height * scale).round()),
        );
      },
    );
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) return null;
        return (
          width: image.width,
          height: image.height,
          rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } on Object {
    return null;
  }
}
