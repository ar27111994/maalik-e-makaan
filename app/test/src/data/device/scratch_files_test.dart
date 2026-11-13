import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/device/scratch_files_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// path_provider, answering [temporary] for the temporary directory.
final class _Paths extends PathProviderPlatform {
  new(this.temporary);

  final String? temporary;

  @override
  Future<String?> getTemporaryPath() async => temporary;
}

/// file_picker on Android, with a pick it kept after Android closed the
/// app.
final class _AndroidFiles extends FilePickerAndroid {
  new({this.lost, this.fails = false});

  final LostFilePickerResult? lost;
  final bool fails;
  int cleared = 0;
  int drained = 0;

  @override
  Future<void> clearTemporaryFiles() async => cleared++;

  @override
  Future<LostFilePickerResult?> retrieveLostData() async {
    drained++;
    if (fails) throw PlatformException(code: 'no_activity');
    return lost;
  }
}

/// file_picker elsewhere.
final class _Files extends FilePickerPlatform {
  int cleared = 0;

  @override
  Future<void> clearTemporaryFiles() async => cleared++;
}

/// The camera, with what it kept after Android closed the app.
final class _Camera extends ImagePicker {
  new(this.lost);

  final Future<LostDataResponse> Function() lost;
  int asked = 0;

  @override
  Future<LostDataResponse> retrieveLostData() {
    asked++;
    return lost();
  }
}

const _uuidA = '6f1c2d3e-4a5b-4c6d-8e7f-001122334455';
const _uuidB = '7a8b9c0d-1e2f-4a3b-9c4d-5e6f70819293';
const _uuidC = 'a1b2c3d4-e5f6-4071-8293-a4b5c6d7e8f9';
const _uuidD = 'b2c3d4e5-f6a7-4182-93a4-b5c6d7e8f9a0';
const _uuidE = 'c3d4e5f6-a7b8-4293-a4b5-c6d7e8f9a0b1';
const _uuidF = 'D4E5F6A7-B8C9-43A4-B5C6-D7E8F9A0B1C2';

void main() {
  late Directory root;
  late Directory cache;
  late Directory outside;
  late PathProviderPlatform paths;
  late FilePickerPlatform files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mm_scratch_');
    cache = Directory('${root.path}/cache')..createSync();
    outside = Directory('${root.path}/outside')..createSync();
    paths = PathProviderPlatform.instance;
    files = FilePickerPlatform.instance;
    PathProviderPlatform.instance = _Paths(cache.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = paths;
    FilePickerPlatform.instance = files;
    debugDefaultTargetPlatformOverride = null;
    root.deleteSync(recursive: true);
  });

  File file(String path, {DateTime? modified}) {
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  bool exists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  group('discard', () {
    test(
      "deletes the plugins' copies in the cache folder, nothing else",
      () async {
        final photo = file('${cache.path}/scaled_$_uuidA.jpg');
        final picked = file(
          '${cache.path}/file_picker/1731488400000/lease.pdf',
        );
        final mine = file('${outside.path}/cnic.jpg');
        final target = file('${outside.path}/target.jpg');
        final link = Link('${cache.path}/link.jpg')..createSync(target.path);
        final folder = Directory('${cache.path}/folder')..createSync();
        await PluginDeviceScratch(platform: TargetPlatform.android).discard([
          photo.path,
          picked.path,
          mine.path,
          // Out through the parent folder.
          '${cache.path}/../outside/cnic.jpg',
          link.path,
          folder.path,
          '${cache.path}/gone.jpg',
        ]);
        expect(exists(photo.path), isFalse);
        expect(exists(picked.path), isFalse);
        expect(exists(mine.path), isTrue);
        // A link is left, and what it points to.
        expect(exists(link.path), isTrue);
        expect(exists(target.path), isTrue);
        expect(exists(folder.path), isTrue);
      },
    );

    test('a file outside the cache through a linked folder stays', () async {
      final mine = file('${outside.path}/cnic.jpg');
      Link('${cache.path}/through').createSync(outside.path);
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .discard(['${cache.path}/through/cnic.jpg']);
      expect(exists(mine.path), isTrue);
    });

    test('without a cache folder nothing is deleted', () async {
      final photo = file('${cache.path}/scaled_$_uuidA.jpg');
      PathProviderPlatform.instance = _Paths(null);
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .discard([photo.path]);
      expect(exists(photo.path), isTrue);
      // A cache folder that does not exist holds nothing.
      PathProviderPlatform.instance = _Paths('${root.path}/missing');
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .discard([photo.path]);
      expect(exists(photo.path), isTrue);
    });

    test("on iOS the app's tmp folder is its own too", () async {
      // Tests run with the system's temporary folder as iOS's tmp/.
      final photo = file('${outside.path}/image_picker_$_uuidA.jpg');
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .discard([photo.path]);
      expect(exists(photo.path), isTrue);
      await PluginDeviceScratch(platform: TargetPlatform.iOS)
          .discard([photo.path]);
      expect(exists(photo.path), isFalse);
    });

    test('a copy that cannot be deleted does not stop the rest', () async {
      final first = file('${cache.path}/a.jpg');
      final second = file('${cache.path}/b.jpg');
      await deleteCopies(
        [cache.path],
        [first.path, second.path],
        delete: (entry) async {
          if (entry.path == first.path) {
            throw FileSystemException('busy', entry.path);
          }
          await entry.delete();
        },
      );
      expect(exists(first.path), isTrue);
      expect(exists(second.path), isFalse);
    });
  });

  group('sweep', () {
    final now = DateTime.now();
    final later = now.add(const Duration(hours: 2));
    // Everything made now is older than this.
    final cutOff = now.add(const Duration(hours: 1));

    test(
      'deletes old shared files and camera copies, and nothing else',
      () async {
        final oldShare = file('${cache.path}/$_uuidA/statement-Name.pdf');
        final newShare = file(
          '${cache.path}/$_uuidB/receipt.pdf',
          modified: later,
        );
        final oldCopy = file('${cache.path}/share_plus/old.pdf');
        final newCopy = file(
          '${cache.path}/share_plus/new.pdf',
          modified: later,
        );
        final photo = file('${cache.path}/${_uuidC}8754.jpg');
        final scaled = file('${cache.path}/scaled_${_uuidC}8754.jpg');
        final newPhoto = file('${cache.path}/${_uuidD}12.jpg', modified: later);
        final notes = file('${cache.path}/notes.txt');
        final engine = file('${cache.path}/flutter_engine/state');
        final picker = file('${cache.path}/file_picker/1/lease.pdf');
        // Links, at the top and inside an old share, to the person's own.
        final precious = file('${outside.path}/precious/cnic.jpg');
        final topLink = Link('${cache.path}/$_uuidE')
          ..createSync(precious.parent.path);
        Directory('${cache.path}/$_uuidF').createSync();
        final innerLink = Link('${cache.path}/$_uuidF/cnic.jpg')
          ..createSync(precious.path);

        await PluginDeviceScratch(platform: TargetPlatform.android)
            .sweep(sharedBefore: cutOff, copiesBefore: cutOff);

        for (final gone in [oldShare, oldCopy, photo, scaled, innerLink]) {
          expect(exists(gone.path), isFalse, reason: gone.path);
        }
        expect(exists('${cache.path}/$_uuidA'), isFalse);
        expect(exists('${cache.path}/$_uuidF'), isFalse);
        for (final kept in [
          newShare,
          newCopy,
          newPhoto,
          notes,
          engine,
          picker,
          precious,
          topLink,
        ]) {
          expect(exists(kept.path), isTrue, reason: kept.path);
        }
      },
    );

    test('keeps what is recent, and the camera copies unless asked', () async {
      final share = file('${cache.path}/$_uuidA/receipt.pdf');
      final photo = file('${cache.path}/scaled_${_uuidC}1.jpg');
      await PluginDeviceScratch(platform: TargetPlatform.iOS)
          .sweep(sharedBefore: now.subtract(const Duration(hours: 1)));
      expect(exists(share.path), isTrue);
      expect(exists(photo.path), isTrue);
    });

    test('a folder that does not exist holds nothing', () async {
      await expectLater(
        sweepFolder('${root.path}/missing', sharedBefore: cutOff),
        completes,
      );
    });

    test('an entry that cannot be deleted does not stop the rest', () async {
      final stuck = file('${cache.path}/$_uuidA/receipt.pdf');
      final other = file('${cache.path}/$_uuidB/receipt.pdf');
      final copy = file('${cache.path}/share_plus/old.pdf');
      await sweepFolder(
        cache.path,
        sharedBefore: cutOff,
        delete: (entry) async {
          if (entry.path.endsWith(_uuidA)) {
            throw FileSystemException('busy', entry.path);
          }
          await entry.delete(recursive: true);
        },
      );
      expect(exists(stuck.path), isTrue);
      expect(exists(other.path), isFalse);
      expect(exists(copy.path), isFalse);
    });
  });

  group('the plugins', () {
    test("clears file_picker's copies on a phone", () async {
      final android = _AndroidFiles();
      FilePickerPlatform.instance = android;
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .clearPickerCopies();
      expect(android.cleared, 1);
      final ios = _Files();
      FilePickerPlatform.instance = ios;
      await PluginDeviceScratch(platform: TargetPlatform.iOS)
          .clearPickerCopies();
      expect(ios.cleared, 1);
    });

    test(
      "drains Android's record of a pick the app was closed during",
      () async {
        final photo = XFile('${cache.path}/scaled_$_uuidA.jpg');
        final camera = _Camera(
          () async => LostDataResponse(
            file: photo,
            files: [photo],
            type: RetrieveType.image,
          ),
        );
        final picked = AndroidPlatformFile.fromMap(const {
          'path': '/data/cache/file_picker/1/lease.pdf',
          'name': 'lease.pdf',
          'size': 1,
        });
        final android = _AndroidFiles(
          lost: LostFilePickerResult(files: [picked]),
        );
        FilePickerPlatform.instance = android;
        expect(
          await PluginDeviceScratch(
            platform: TargetPlatform.android,
            camera: camera,
          ).drainLostPicks(),
          [photo.path, '/data/cache/file_picker/1/lease.pdf'],
        );
        expect((camera.asked, android.drained), (1, 1));
      },
    );

    test('a plugin that fails or has nothing leaves the other', () async {
      final failing = _Camera(
        () => throw PlatformException(code: 'no_activity'),
      );
      FilePickerPlatform.instance = _AndroidFiles(
        lost: LostFilePickerResult(
          files: [
            AndroidPlatformFile.fromMap(const {
              'path': '/data/cache/file_picker/2/a.pdf',
            }),
          ],
        ),
      );
      expect(
        await PluginDeviceScratch(
          platform: TargetPlatform.android,
          camera: failing,
        ).drainLostPicks(),
        ['/data/cache/file_picker/2/a.pdf'],
      );
      final empty = _Camera(() async => LostDataResponse.empty());
      FilePickerPlatform.instance = _AndroidFiles(fails: true);
      expect(
        await PluginDeviceScratch(
          platform: TargetPlatform.android,
          camera: empty,
        ).drainLostPicks(),
        isEmpty,
      );
      FilePickerPlatform.instance = _AndroidFiles();
      expect(
        await PluginDeviceScratch(
          platform: TargetPlatform.android,
          camera: empty,
        ).drainLostPicks(),
        isEmpty,
      );
      // Not Android's file_picker: only the camera is asked.
      FilePickerPlatform.instance = _Files();
      expect(
        await PluginDeviceScratch(
          platform: TargetPlatform.android,
          camera: empty,
        ).drainLostPicks(),
        isEmpty,
      );
      expect(empty.asked, 3);
    });

    test('only Android loses picks', () async {
      final camera = _Camera(() async => LostDataResponse.empty());
      final android = _AndroidFiles();
      FilePickerPlatform.instance = android;
      expect(
        await PluginDeviceScratch(
          platform: TargetPlatform.iOS,
          camera: camera,
        ).drainLostPicks(),
        isEmpty,
      );
      expect((camera.asked, android.drained), (0, 0));
    });
  });

  group('the platform', () {
    test('on the web or a computer, nothing is touched', () async {
      final photo = file('${cache.path}/scaled_$_uuidA.jpg');
      final share = file('${cache.path}/$_uuidA/receipt.pdf');
      final picker = _Files();
      FilePickerPlatform.instance = picker;
      final none = PluginDeviceScratch(
        camera: _Camera(() => throw StateError('not asked')),
      );
      await none.discard([photo.path]);
      await none.clearPickerCopies();
      expect(await none.drainLostPicks(), isEmpty);
      await none.sweep(
        sharedBefore: DateTime.now().add(const Duration(days: 1)),
        copiesBefore: DateTime.now().add(const Duration(days: 1)),
      );
      expect(exists(photo.path), isTrue);
      expect(exists(share.path), isTrue);
      expect(picker.cleared, 0);
    });

    test('here() follows the platform the app runs on', () async {
      Future<bool> discards(TargetPlatform platform) async {
        debugDefaultTargetPlatformOverride = platform;
        final photo = file('${cache.path}/scaled_$_uuidA.jpg');
        await PluginDeviceScratch.here().discard([photo.path]);
        return !exists(photo.path);
      }

      expect(await discards(TargetPlatform.android), isTrue);
      expect(await discards(TargetPlatform.iOS), isTrue);
      expect(await discards(TargetPlatform.linux), isFalse);
      // The system's temporary folder counts only on iOS.
      final temp = file('${outside.path}/image_picker_x.jpg');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await PluginDeviceScratch.here().discard([temp.path]);
      expect(exists(temp.path), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await PluginDeviceScratch.here().discard([temp.path]);
      expect(exists(temp.path), isFalse);
    });

    test('the system temporary folder is where tests make theirs', () {
      expect(root.path, startsWith(systemTempPath()));
    });
  });
}
