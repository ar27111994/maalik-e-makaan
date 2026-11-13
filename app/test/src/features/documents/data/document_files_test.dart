import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';

/// A photo-like image: noise keeps detail, as a photo of paper does.
img.Image _noise(int width, int height, {bool transparent = false}) {
  final random = Random(7);
  final image = img.Image(
    width: width,
    height: height,
    numChannels: transparent ? 4 : 3,
  );
  for (final pixel in image) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
    if (transparent) pixel.a = 0;
  }
  return image;
}

Uint8List _pdf(int size) {
  return Uint8List(size)..setAll(0, latin1.encode('%PDF-1.7'));
}

List<int> _u16(int value) => [value >> 8 & 0xFF, value & 0xFF];
List<int> _u32(int value) => [..._u16(value >> 16), ..._u16(value & 0xFFFF)];
List<int> _box(String type, List<int> body) => [
  ..._u32(8 + body.length),
  ...latin1.encode(type),
  ...body,
];

/// A HEIC file of [size] bytes the platform here cannot decode: ftyp,
/// meta (one Exif item, at the start of mdat) and mdat.
Uint8List _heic(int size) {
  final ftyp = _box(
    'ftyp',
    latin1.encode('heic\u0000\u0000\u0000\u0000mif1heic'),
  );
  List<int> meta(int exifAt) => _box('meta', [
    0,
    0,
    0,
    0,
    ..._box('iinf', [
      0,
      0,
      0,
      0,
      ..._u16(1),
      ..._box('infe', [
        2,
        0,
        0,
        0,
        ..._u16(1),
        ..._u16(0),
        ...latin1.encode('Exif'),
        0,
      ]),
    ]),
    ..._box('iloc', [
      0,
      0,
      0,
      0,
      ..._u16(0x4400),
      ..._u16(1),
      ..._u16(1),
      ..._u16(0),
      ..._u16(1),
      ..._u32(exifAt),
      ..._u32(6),
    ]),
  ]);
  final head = ftyp.length + meta(0).length;
  return Uint8List(size)..setAll(0, [
    ...ftyp,
    ...meta(head + 8),
    ..._u32(size - head),
    ...latin1.encode('mdatExif'),
    0,
    0,
  ]);
}

/// Where [_heic]'s Exif item starts.
int _heicExifAt(Uint8List heic) {
  for (var i = 0; i + 8 <= heic.length; i++) {
    if (latin1.decode(heic.sublist(i, i + 8)) == 'mdatExif') return i + 4;
  }
  throw StateError('no Exif');
}

/// An APP1 segment with an Exif block: a GPS position ("N"), and the
/// [orientation] when given.
List<int> _app1Exif({int? orientation}) {
  final entries = orientation == null ? 1 : 2;
  // IFD0 starts at 8; the GPS IFD follows it.
  final gps = 8 + 2 + 12 * entries + 4;
  final tiff = [
    ...latin1.encode('MM\u0000*'),
    ..._u32(8),
    ..._u16(entries),
    if (orientation != null) ...[
      ..._u16(0x0112),
      ..._u16(3),
      ..._u32(1),
      ..._u16(orientation),
      0,
      0,
    ],
    ..._u16(0x8825),
    ..._u16(4),
    ..._u32(1),
    ..._u32(gps),
    ..._u32(0),
    ..._u16(1),
    ..._u16(1),
    ..._u16(2),
    ..._u32(2),
    ...latin1.encode('N\u0000GPS'),
    0,
    ..._u32(0),
  ];
  final data = [...latin1.encode('Exif\u0000\u0000'), ...tiff];
  return [0xFF, 0xE1, ..._u16(data.length + 2), ...data];
}

/// The markers of [jpeg]'s segments before its first scan.
List<int> _segments(Uint8List jpeg) {
  final markers = <int>[];
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF) {
    final marker = jpeg[i + 1];
    markers.add(marker);
    if (marker == 0xDA) break;
    i += 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
  }
  return markers;
}

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

Matcher _refused(String reason) =>
    throwsA(isA<RejectedFailure>().having((f) => f.reason, 'reason', reason));

/// A camera that answers [photo], and [lost] when asked for a photo kept
/// after Android closed the app, and records what it was asked.
final class _Camera extends ImagePicker {
  new(this.photo, {this.lost});

  final Future<XFile?> Function() photo;
  final Future<LostDataResponse> Function()? lost;
  final asked = <Map<String, Object?>>[];

  @override
  Future<LostDataResponse> retrieveLostData() =>
      lost?.call() ?? Future.value(LostDataResponse.empty());

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    asked.add({
      'source': source,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'imageQuality': imageQuality,
      'requestFullMetadata': requestFullMetadata,
    });
    return photo();
  }
}

final class _File extends PlatformFile {
  new(this.name, this.bytes, {this.knownLength});

  @override
  final String name;
  final Uint8List bytes;
  final int? knownLength;

  @override
  Uri get uri => Uri.file('/tmp/$name');

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => knownLength;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

/// The device's file chooser, answering [file].
final class _Files extends FilePickerPlatform {
  new(this.file);

  final Future<PlatformFile?> Function() file;
  final asked = <(FileType, List<String>?)>[];

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    asked.add((type, allowedExtensions));
    return file();
  }
}

void main() {
  group('prepareFile', () {
    test('a large photo becomes a JPEG of at most 300 KB', () async {
      final jpeg = img.encodeJpg(_noise(2400, 1800), quality: 95);
      expect(jpeg.length, greaterThan(targetImageBytes));
      final prepared = await prepareFile(
        ChosenFile(name: 'DCIM/Camera/IMG_2034.jpg', bytes: jpeg),
      );
      expect(prepared.name, 'IMG_2034');
      expect(prepared.type, DocumentFileType.jpeg);
      expect(prepared.size, lessThanOrEqualTo(targetImageBytes));
      expect(prepared.originalSize, jpeg.length);
      expect(prepared.compressed, isTrue);
      // Upright and in proportion, at most 1600 px long.
      final decoded = img.decodeJpg(prepared.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(1600));
      expect(decoded.width * 3, decoded.height * 4);
    });

    test('a photo too detailed for the first step goes on smaller', () async {
      // Noise at full size: no step at 1600 px fits, so it is scaled down
      // further; the smallest result is kept.
      final png = img.encodePng(_noise(1600, 1600));
      final prepared = await prepareFile(
        ChosenFile(name: 'detail.png', bytes: png),
      );
      expect(prepared.type, DocumentFileType.jpeg);
      expect(prepared.size, lessThan(png.length));
      final decoded = img.decodeJpg(prepared.bytes)!;
      expect(decoded.width, lessThan(1600));
    });

    test('transparent parts become white', () async {
      final png = img.encodePng(_noise(1200, 900, transparent: true));
      expect(png.length, greaterThan(targetImageBytes));
      final prepared = await prepareFile(
        ChosenFile(name: 'stamp.png', bytes: png),
      );
      expect(prepared.type, DocumentFileType.jpeg);
      final pixel = img.decodeJpg(prepared.bytes)!.getPixel(10, 10);
      expect((pixel.r, pixel.g, pixel.b), (255, 255, 255));
    });

    test('a small photo is saved again, without where it was taken', () async {
      // A small camera JPEG with an Exif block that holds a GPS position.
      final plain = img.encodeJpg(_noise(40, 30), quality: 90);
      final photo = Uint8List.fromList([
        ...plain.sublist(0, 2),
        ..._app1Exif(),
        ...plain.sublist(2),
      ]);
      expect(photo.length, lessThan(targetImageBytes));
      final prepared = await prepareFile(
        ChosenFile(name: 'IMG_0007.jpg', bytes: photo),
      );
      expect(prepared.type, DocumentFileType.jpeg);
      expect(_segments(prepared.bytes), isNot(contains(0xE1)));
      expect(_contains(prepared.bytes, latin1.encode('Exif')), isFalse);
      expect(_contains(prepared.bytes, latin1.encode('GPS')), isFalse);
      expect(prepared.originalSize, photo.length);
      final decoded = img.decodeJpg(prepared.bytes)!;
      expect((decoded.width, decoded.height), (40, 30));
    });

    test('a photo is turned upright as its camera said', () async {
      // Orientation 6: the camera was held on its side, and the picture
      // must be turned a quarter clockwise to be upright.
      final plain = img.encodeJpg(_noise(40, 30), quality: 90);
      final photo = Uint8List.fromList([
        ...plain.sublist(0, 2),
        ..._app1Exif(orientation: 6),
        ...plain.sublist(2),
      ]);
      final prepared = await prepareFile(
        ChosenFile(name: 'IMG_0008.jpg', bytes: photo),
      );
      final decoded = img.decodeJpg(prepared.bytes)!;
      expect((decoded.width, decoded.height), (30, 40));
    });

    test('a small PNG becomes a JPEG without its text chunks', () async {
      final png = img.encodePng(img.Image(width: 40, height: 30));
      expect(png.length, lessThan(targetImageBytes));
      final prepared = await prepareFile(
        ChosenFile(name: 'small.png', bytes: png),
      );
      expect(prepared.type, DocumentFileType.jpeg);
      expect(prepared.name, 'small');
    });

    test('a PDF is kept as it is, up to 10 MB', () async {
      final pdf = _pdf(2 * 1024 * 1024);
      final prepared = await prepareFile(
        ChosenFile(name: 'agreement.pdf', bytes: pdf),
      );
      expect(prepared.type, DocumentFileType.pdf);
      expect(prepared.name, 'agreement');
      expect(prepared.bytes, same(pdf));
      await expectLater(
        prepareFile(
          ChosenFile(name: 'big.pdf', bytes: _pdf(Document.maxSizeBytes + 1)),
        ),
        _refused('file_too_large'),
      );
    });

    test('a photo this device cannot decode is kept without its metadata, '
        'up to 10 MB', () async {
      final heic = _heic(400 * 1024);
      final prepared = await prepareFile(
        ChosenFile(name: '.heic', bytes: heic),
      );
      expect(prepared.type, DocumentFileType.heic);
      expect(prepared.name, '.heic');
      expect(prepared.size, heic.length);
      // Its Exif block is blanked, the rest kept byte for byte.
      final exif = _heicExifAt(heic);
      expect(prepared.bytes.sublist(exif, exif + 6), List.filled(6, 0));
      expect(prepared.bytes.sublist(0, exif), heic.sublist(0, exif));
      expect(prepared.bytes.sublist(exif + 6), heic.sublist(exif + 6));
      // Taking metadata out is not making it smaller.
      expect(prepared.compressed, isFalse);
      await expectLater(
        prepareFile(
          ChosenFile(
            name: 'huge.heic',
            bytes: _heic(Document.maxSizeBytes + 1),
          ),
        ),
        _refused('file_too_large'),
      );
    });

    test('a photo whose metadata cannot be found is refused', () async {
      // A HEIC whose second box says it is longer than the file.
      final damaged = Uint8List.fromList([
        ...latin1.encode(
          '\u0000\u0000\u0000\u0010ftypheic\u0000\u0000\u0000\u0000',
        ),
        0,
        0,
        0x10,
        0,
        ...latin1.encode('mdat'),
      ]);
      await expectLater(
        prepareFile(ChosenFile(name: 'IMG.heic', bytes: damaged)),
        _refused('file_unreadable'),
      );
    });

    test('other files are refused', () async {
      await expectLater(
        prepareFile(
          ChosenFile(
            name: 'cnic.gif',
            bytes: Uint8List.fromList(latin1.encode('GIF89a')),
          ),
        ),
        _refused('file_type_not_allowed'),
      );
    });
  });

  group('PluginDocumentPicker', () {
    late FilePickerPlatform original;
    setUp(() => original = FilePickerPlatform.instance);
    tearDown(() => FilePickerPlatform.instance = original);

    test('takes a photo, asking the camera to keep it small', () async {
      final camera = _Camera(
        () async => XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          path: '/tmp/scaled_1.jpg',
        ),
      );
      final discarded = <String>[];
      final photo = await PluginDocumentPicker(
        camera: camera,
        discard: (paths) async => discarded.addAll(paths),
      ).takePhoto();
      expect(photo!.name, 'scaled_1.jpg');
      expect(photo.bytes, [1, 2, 3]);
      // The camera's copy is let go once it is read.
      expect(discarded, ['/tmp/scaled_1.jpg']);
      expect(camera.asked.single, {
        'source': ImageSource.camera,
        'maxWidth': 2048.0,
        'maxHeight': 2048.0,
        'imageQuality': 85,
        'requestFullMetadata': false,
      });
      expect(
        await PluginDocumentPicker(camera: _Camera(() async => null))
            .takePhoto(),
        isNull,
      );
    });

    test('a camera the app may not use says so', () async {
      final denied = PluginDocumentPicker(
        camera: _Camera(
          () => throw PlatformException(code: 'camera_access_denied'),
        ),
      );
      await expectLater(denied.takePhoto(), _refused('picker_access_denied'));
      final broken = PluginDocumentPicker(
        camera: _Camera(
          () => throw PlatformException(code: 'no_available_camera'),
        ),
      );
      await expectLater(broken.takePhoto(), throwsA(isA<UnexpectedFailure>()));
    });

    test('a photo kept after Android closed the app comes back once', () async {
      final discarded = <String>[];
      Future<ChosenFile?> recover(LostDataResponse lost) =>
          PluginDocumentPicker(
            camera: _Camera(() async => null, lost: () async => lost),
            discard: (paths) async => discarded.addAll(paths),
          ).recoverLostPhoto();

      final photo = await recover(
        LostDataResponse(
          file: XFile.fromData(
            Uint8List.fromList([7, 8, 9]),
            path: '/data/cache/scaled_2.jpg',
          ),
          type: RetrieveType.image,
        ),
      );
      expect(photo!.name, 'scaled_2.jpg');
      expect(photo.bytes, [7, 8, 9]);
      expect(discarded, ['/data/cache/scaled_2.jpg']);
      // Nothing kept.
      expect(await recover(LostDataResponse.empty()), isNull);
      expect(
        await PluginDocumentPicker(camera: _Camera(() async => null))
            .recoverLostPhoto(),
        isNull,
      );
      // Not a photo: the app takes no videos.
      expect(
        await recover(
          LostDataResponse(
            file: XFile.fromData(Uint8List(1), path: '/data/cache/v.mp4'),
            type: RetrieveType.video,
          ),
        ),
        isNull,
      );
      // It is let go all the same.
      expect(discarded.last, '/data/cache/v.mp4');
      expect(await recover(LostDataResponse(type: RetrieveType.image)), isNull);
    });

    test("a lost photo's failure is the camera's", () async {
      Future<ChosenFile?> recover(LostDataResponse lost) =>
          PluginDocumentPicker(
            camera: _Camera(() async => null, lost: () async => lost),
          ).recoverLostPhoto();

      await expectLater(
        recover(
          LostDataResponse(
            exception: PlatformException(code: 'camera_access_denied'),
            type: RetrieveType.image,
          ),
        ),
        _refused('picker_access_denied'),
      );
      await expectLater(
        recover(
          LostDataResponse(
            exception: PlatformException(code: 'no_available_camera'),
            type: RetrieveType.image,
          ),
        ),
        throwsA(isA<UnexpectedFailure>()),
      );
      // The kept file is gone (the app's cache was cleared).
      await expectLater(
        recover(
          LostDataResponse(
            file: XFile('/nonexistent/scaled_3.jpg'),
            type: RetrieveType.image,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('chooses a photo or PDF of the accepted types', () async {
      final files = _Files(
        () async => _File('lease.pdf', Uint8List.fromList([4, 5])),
      );
      FilePickerPlatform.instance = files;
      final discarded = <String>[];
      final file = await PluginDocumentPicker(
        discard: (paths) async => discarded.addAll(paths),
      ).chooseFile();
      expect(file!.name, 'lease.pdf');
      expect(file.bytes, [4, 5]);
      // The picker's copy is let go once it is read.
      expect(discarded, ['/tmp/lease.pdf']);
      expect(files.asked.single, (FileType.custom, pickableExtensions));
      FilePickerPlatform.instance = _Files(() async => null);
      expect(await PluginDocumentPicker().chooseFile(), isNull);
    });

    test('a file too large to read is refused before it is read', () async {
      FilePickerPlatform.instance = _Files(
        () async => _File(
          'video.pdf',
          Uint8List(0),
          knownLength: maxPickedImageBytes + 1,
        ),
      );
      final discarded = <String>[];
      await expectLater(
        PluginDocumentPicker(discard: (paths) async => discarded.addAll(paths))
            .chooseFile(),
        _refused('file_too_large'),
      );
      // A refused file's copy is let go too.
      expect(discarded, ['/tmp/video.pdf']);
      FilePickerPlatform.instance = _Files(
        () => throw PlatformException(code: 'read_external_storage_denied'),
      );
      await expectLater(
        PluginDocumentPicker().chooseFile(),
        _refused('picker_access_denied'),
      );
    });

    test('the providers give the plugins and the real preparation', () {
      expect(PluginDocumentPicker.cameraMaxSide, 2048);
      expect(compressionSteps.first, (1600, 80));
    });
  });
}
