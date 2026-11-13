import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/device/scratch_files_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/fakes.dart' show MemorySettingsStore, MemoryStore;

/// path_provider, answering [temporary] for the temporary directory.
final class _Paths extends PathProviderPlatform {
  new(this.temporary);

  final String? temporary;

  @override
  Future<String?> getTemporaryPath() async => temporary;
}

/// file_picker on Android, with a pick it kept after Android closed the
/// app. Its own clearing is never asked: the app sweeps the copies itself.
final class _AndroidFiles extends FilePickerAndroid {
  new({this.lost, this.fails = false});

  final LostFilePickerResult? lost;
  final bool fails;
  int drained = 0;

  @override
  Future<LostFilePickerResult?> retrieveLostData() async {
    drained++;
    if (fails) throw PlatformException(code: 'no_activity');
    return lost;
  }
}

/// file_picker elsewhere.
final class _Files extends FilePickerPlatform;

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

  /// iOS's `tmp/`, for the tests.
  late Directory tmp;
  late PathProviderPlatform paths;
  late FilePickerPlatform files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mm_scratch_');
    cache = Directory('${root.path}/cache')..createSync();
    outside = Directory('${root.path}/outside')..createSync();
    tmp = Directory('${root.path}/tmp')..createSync();
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

  /// Sets when [path] (a folder too) last changed: dart:io sets it only for
  /// files.
  void touch(String path, DateTime modified) {
    final stamp =
        '${modified.year.toString().padLeft(4, '0')}'
        '${modified.month.toString().padLeft(2, '0')}'
        '${modified.day.toString().padLeft(2, '0')}'
        '${modified.hour.toString().padLeft(2, '0')}'
        '${modified.minute.toString().padLeft(2, '0')}'
        '.${modified.second.toString().padLeft(2, '0')}';
    final result = Process.runSync('touch', ['-m', '-t', stamp, path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
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

    test('a folder next to the cache, whose name begins the same, is not '
        'the cache', () async {
      final sibling = file('${root.path}/cache2/scaled_$_uuidA.jpg');
      final older = file('${root.path}/cache-old/x.jpg');
      await PluginDeviceScratch(platform: TargetPlatform.android)
          .discard([sibling.path, older.path]);
      expect(exists(sibling.path), isTrue);
      expect(exists(older.path), isTrue);
    });

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
      final photo = file('${tmp.path}/image_picker_$_uuidA.jpg');
      await PluginDeviceScratch(
        platform: TargetPlatform.android,
        tempFolder: () => tmp.path,
      ).discard([photo.path]);
      expect(exists(photo.path), isTrue);
      await PluginDeviceScratch(
        platform: TargetPlatform.iOS,
        tempFolder: () => tmp.path,
      ).discard([photo.path]);
      expect(exists(photo.path), isFalse);
      // By default, the system's temporary folder (the tests' own here).
      final mine = file('${outside.path}/image_picker_$_uuidA.jpg');
      await PluginDeviceScratch(platform: TargetPlatform.iOS)
          .discard([mine.path]);
      expect(exists(mine.path), isFalse);
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

  group("the pickers' copies", () {
    final now = DateTime.now();
    final before = now.add(const Duration(hours: 1));
    final later = now.add(const Duration(hours: 2));

    test(
      "on Android, file_picker's older than the wipe, nothing else",
      () async {
        final old = file('${cache.path}/file_picker/1731488400000/lease.pdf');
        // Picked by the next user while the wipe ran: its folder is new,
        // although the copy kept its original's time.
        final picked = file(
          '${cache.path}/file_picker/1731488500000/cnic.jpg',
          modified: now.subtract(const Duration(days: 30)),
        );
        touch(picked.parent.path, later);
        final photo = file('${cache.path}/scaled_$_uuidA.jpg');
        final share = file('${cache.path}/$_uuidB/receipt.pdf');
        await PluginDeviceScratch(platform: TargetPlatform.android)
            .clearPickerCopies(before: before);
        expect(exists(old.path), isFalse);
        expect(exists(old.parent.path), isFalse);
        expect(exists(picked.path), isTrue);
        expect(exists(photo.path), isTrue);
        expect(exists(share.path), isTrue);
        // Without a file_picker folder there is nothing to do.
        Directory('${cache.path}/file_picker').deleteSync(recursive: true);
        await expectLater(
          PluginDeviceScratch(platform: TargetPlatform.android)
              .clearPickerCopies(before: before),
          completes,
        );
      },
    );

    test('on iOS, everything in tmp/ older than the wipe', () async {
      final photo = file('${tmp.path}/image_picker_$_uuidA.jpg');
      final picked = file('${tmp.path}/$_uuidF/lease.pdf');
      final inbox = file('${tmp.path}/app-Inbox/agreement.pdf');
      final fresh = file(
        '${tmp.path}/image_picker_$_uuidB.jpg',
        modified: later,
      );
      final precious = file('${outside.path}/cnic.jpg');
      final link = Link('${tmp.path}/link')..createSync(outside.path);
      final share = file('${cache.path}/$_uuidC/receipt.pdf');
      await PluginDeviceScratch(
        platform: TargetPlatform.iOS,
        tempFolder: () => tmp.path,
      ).clearPickerCopies(before: before);
      for (final gone in [photo, picked, inbox]) {
        expect(exists(gone.path), isFalse, reason: gone.path);
      }
      for (final kept in [fresh, precious, share]) {
        expect(exists(kept.path), isTrue, reason: kept.path);
      }
      expect(exists(link.path), isTrue);
      // Without a tmp/ folder there is nothing to do.
      await PluginDeviceScratch(
        platform: TargetPlatform.iOS,
        tempFolder: () => null,
      ).clearPickerCopies(before: before);
      expect(exists(fresh.path), isTrue);
    });

    test('an entry that cannot be deleted does not stop the rest', () async {
      final stuck = file('${tmp.path}/a/lease.pdf');
      final other = file('${tmp.path}/b/cnic.jpg');
      await sweepOlder(
        tmp.path,
        before,
        delete: (entry) async {
          if (entry.path.endsWith('/a')) {
            throw FileSystemException('busy', entry.path);
          }
          await entry.delete(recursive: true);
        },
      );
      expect(exists(stuck.path), isTrue);
      expect(exists(other.path), isFalse);
      await expectLater(sweepOlder('${root.path}/missing', before), completes);
    });
  });

  group('the plugins', () {
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
          [
            photo.path,
            // The camera's full-size original, which image_picker resized
            // only as it handed the photo over, and left.
            '${cache.path}/$_uuidA.jpg',
            '/data/cache/file_picker/1/lease.pdf',
          ],
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
      final picked = file('${tmp.path}/image_picker_$_uuidC.jpg');
      final none = PluginDeviceScratch(
        camera: _Camera(() => throw StateError('not asked')),
        tempFolder: () => tmp.path,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await none.discard([photo.path, picked.path]);
      await none.clearPickerCopies(before: tomorrow);
      expect(await none.drainLostPicks(), isEmpty);
      await none.sweep(sharedBefore: tomorrow, copiesBefore: tomorrow);
      expect(exists(photo.path), isTrue);
      expect(exists(share.path), isTrue);
      expect(exists(picked.path), isTrue);
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

  group('a wipe on the phone', () {
    // A fixed now, a whole second, so that file times compare exactly.
    final now = DateTime(2026, 11, 13, 9);

    test('keeps a file shared less than ten minutes ago, for the app it was '
        'shared with, and takes the older ones', () async {
      // Pinned here, not read from the constant: the share sheet returns
      // before WhatsApp or e-mail has read the file.
      expect(
        sharedFileGrace,
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
      final recent = now.subtract(const Duration(minutes: 5));
      final old = now.subtract(const Duration(minutes: 11));
      final share = file('${cache.path}/$_uuidA/receipt.pdf', modified: recent);
      touch(share.parent.path, recent);
      final copy = file(
        '${cache.path}/share_plus/statement.pdf',
        modified: recent,
      );
      final oldShare = file('${cache.path}/$_uuidB/receipt.pdf', modified: old);
      touch(oldShare.parent.path, old);
      final oldCopy = file('${cache.path}/share_plus/x.pdf', modified: old);

      final wipe = DeviceDataWipe(
        cache: SwrCache(MemoryStore()),
        settings: MemorySettingsStore(),
        scratch: PluginDeviceScratch(
          platform: TargetPlatform.android,
          camera: _Camera(() async => LostDataResponse.empty()),
        ),
        clock: () => now,
      );
      await wipe.wipe(WipeReason.signedOut);
      await wipe.settled;
      expect(exists(share.path), isTrue);
      expect(exists(copy.path), isTrue);
      expect(exists(oldShare.path), isFalse);
      expect(exists(oldCopy.path), isFalse);
    });
  });
}
