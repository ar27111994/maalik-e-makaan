import 'dart:async';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/scratch_files_stub.dart'
    if (dart.library.io) 'package:maalik_e_makaan/src/data/device/scratch_files_io.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Why the device's copy of an account is wiped, from the least to the
/// most that goes.
enum WipeReason {
  /// The app started with nobody signed in: what an earlier run left behind
  /// (a version before the wipe, or a run closed in the middle of one).
  /// While a lost photo may still come back ([DeviceDataWipe.atStart]), the
  /// camera's record of it and the photo itself stay, so that signing in
  /// again can still bring the photo back to its record.
  startedSignedOut,

  /// A session ended: the user signed out, it expired or was revoked
  /// elsewhere, or another account's session replaced it.
  signedOut,

  /// The account was deleted, or may have been (its answer was lost): the
  /// invitation the device held goes too.
  accountDeleted;

  /// Whether a session ended (not a start-up tidy).
  bool get endsSession => this != startedSignedOut;

  /// Whether a wipe for this reason removes everything one for [other]
  /// does.
  bool covers(WipeReason other) => index >= other.index;
}

/// How long a file written to share is kept after it last changed: the app
/// it was shared with (WhatsApp, e-mail) may read it after the share sheet
/// has closed. A sweep leaves younger files for the next start, or for the
/// next time the app comes back to the foreground.
const sharedFileGrace = Duration(minutes: 10);

/// How long the files of a wipe may take before [DeviceDataWipe.settled]
/// stops waiting for them.
const wipeFilesLimit = Duration(seconds: 30);

/// How long [DeviceDataWipe.wipe] waits for the preferences to go before it
/// returns anyway, so that a store that never answers does not hold up the
/// sign-out. The step goes on behind it.
const wipePreferencesLimit = Duration(seconds: 3);

/// How long one plugin may take to answer during a wipe.
const pluginCallLimit = Duration(seconds: 5);

/// The files the app's plugins write on the phone, and the plugins' own
/// records of a pick. Where the app writes no files (the web), each method
/// does nothing; elsewhere a plugin that fails makes it throw, except
/// [discard].
abstract interface class DeviceScratch {
  /// Deletes each of [paths] that is a copy in the app's own folders (the
  /// cache folder, and iOS's `tmp/`), and nothing else. Never throws.
  Future<void> discard(Iterable<String> paths);

  /// Deletes the pickers' copies that last changed before [before]: on
  /// Android file_picker's (`cache/file_picker/<time>/`), on iOS every entry
  /// of the app's `tmp/` (the camera's photos, file_picker's copies). A
  /// copy made since, by someone who signed in meanwhile, is theirs.
  Future<void> clearPickerCopies({required DateTime before});

  /// On Android, hands over the camera's and the file picker's record of a
  /// pick the app was closed during (so neither stays in the plugins'
  /// preferences) and returns the paths of its files; elsewhere, none.
  Future<List<String>> drainLostPicks();

  /// Deletes, in the app's cache folder, the files written to share that
  /// last changed before [sharedBefore], and when [copiesBefore] is given,
  /// the camera's photos last changed before it.
  Future<void> sweep({required DateTime sharedBefore, DateTime? copiesBefore});
}

/// [DeviceScratch] over path_provider, image_picker and file_picker. Only
/// Android and iOS (`platform`) have folders of the app's own to tidy; on
/// the web and on a computer (where the system's temporary folder is
/// everyone's) nothing is touched. `tempFolder` is iOS's `tmp/` (the
/// system's temporary folder there); tests give their own.
final class PluginDeviceScratch implements DeviceScratch {
  new({this._platform, ImagePicker? camera, this._tempFolder = systemTempPath})
    : _camera = camera ?? ImagePicker();

  /// The scratch of the platform the app runs on.
  factory here() => PluginDeviceScratch(
    platform: kIsWeb
        ? null
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => TargetPlatform.android,
            TargetPlatform.iOS => TargetPlatform.iOS,
            _ => null,
          },
  );

  final TargetPlatform? _platform;
  final ImagePicker _camera;
  final String? Function() _tempFolder;

  /// The app's cache folder (path_provider's temporary directory: Android's
  /// cache, iOS's `Library/Caches`).
  Future<String> _cacheFolder() async =>
      (await getTemporaryDirectory().timeout(pluginCallLimit)).path;

  @override
  Future<void> discard(Iterable<String> paths) async {
    if (_platform == null) return;
    try {
      final temp = _tempFolder();
      await deleteCopies([
        await _cacheFolder(),
        if (_platform == TargetPlatform.iOS && temp != null) temp,
      ], paths);
    } on Object {
      // Without the cache folder nothing is known to be the app's.
    }
  }

  @override
  Future<void> clearPickerCopies({required DateTime before}) async {
    // The app's own sweep, not file_picker's clearTemporaryFiles: that one
    // takes everything, a copy just picked by the next user included, and
    // on iOS stops at the first entry it cannot delete.
    if (_platform == TargetPlatform.android) {
      await sweepOlder('${await _cacheFolder()}/file_picker', before);
    } else if (_platform == TargetPlatform.iOS) {
      final temp = _tempFolder();
      if (temp != null) await sweepOlder(temp, before);
    }
  }

  @override
  Future<List<String>> drainLostPicks() async {
    if (_platform != TargetPlatform.android) return const [];
    final paths = <String>{};
    try {
      final lost = await _camera.retrieveLostData().timeout(pluginCallLimit);
      for (final path in {
        ...?lost.files?.map((file) => file.path),
        ?lost.file?.path,
      }) {
        paths.addAll([path, ?cameraOriginalOf(path)]);
      }
    } on Object {
      // Nothing kept, or no activity to ask: nothing to drain.
    }
    try {
      if (FilePickerPlatform.instance case final FilePickerAndroid files) {
        final lost = await files.retrieveLostData().timeout(pluginCallLimit);
        paths.addAll([...?lost?.files.map((file) => file.path).nonNulls]);
      }
    } on Object {
      // As above.
    }
    return paths.toList();
  }

  @override
  Future<void> sweep({
    required DateTime sharedBefore,
    DateTime? copiesBefore,
  }) async {
    if (_platform == null) return;
    await sweepFolder(
      await _cacheFolder(),
      sharedBefore: sharedBefore,
      copiesBefore: copiesBefore,
    );
  }
}

/// The camera's full-size photo that [path] was made from, when [path] is
/// the resized copy image_picker makes on Android (`scaled_<name>`, next to
/// it); otherwise null. When Android closed the app behind the camera,
/// image_picker resizes the photo it kept only as it hands it over, and
/// leaves the original (with what the camera wrote into it) behind.
String? cameraOriginalOf(String path) {
  final slash = path.lastIndexOf('/');
  final name = path.substring(slash + 1);
  const prefix = 'scaled_';
  if (!name.startsWith(prefix) || name.length == prefix.length) return null;
  return '${path.substring(0, slash + 1)}${name.substring(prefix.length)}';
}

/// The preferences step of a wipe on its way, for single-flight.
final class _Wipe {
  new(this.reason, this.preferences, {required this.camera});

  final WipeReason reason;
  final Future<void> preferences;

  /// Whether it removes the camera's record.
  final bool camera;

  /// Whether it removes everything a wipe for [other] would.
  bool covers(WipeReason other, {required bool camera}) =>
      reason.covers(other) && (this.camera || !camera);
}

/// Removes what the app kept on the device for an account, when its
/// session ends (whatever ended it) and when the app starts with nobody
/// signed in.
///
/// It removes:
///
/// - the saved copy of every list the app loaded (the [SwrCache]), and any
///   copy a fetch still on its way would bring back later
///   ([SwrCache.epoch]);
/// - the portfolio last chosen on the device;
/// - the camera's record of a photo being taken, and on Android the
///   camera's and the file picker's record of a pick the app was closed
///   during, with its files (at start-up only when no lost photo may come
///   back: see [atStart]);
/// - the invitation the device holds, only when the account is deleted. It
///   survives signing out, so that "sign out, then sign in with the address
///   the invitation was sent to" works; it is a token of no use to anyone
///   but the invited address's verified account, and names nobody;
/// - on Android and iOS, the copies of photos and files the plugins left in
///   the app's cache and temporary folders, and the files written to share
///   ([sharedFileGrace]).
///
/// It keeps the display settings (language, theme, contrast, digit
/// grouping), which belong to the device, not the account. Supabase removes
/// its own session, and gotrue its sign-in-link verifier, which a link
/// opened later may still need. Nothing outside the app's own folders is
/// touched, and on the web there are none: a file the browser downloaded or
/// shared is the person's own, and so is text copied to the clipboard.
///
/// Every step runs on its own: one that fails leaves the others to run. It
/// never throws, and logs nothing (a file's name can carry a tenant's). A
/// second wipe for one sign-out does no harm: each step finds nothing left.
final class DeviceDataWipe {
  /// `preferencesLimit` is [wipePreferencesLimit] but in tests.
  new({
    required this._cache,
    required this._settings,
    required this._scratch,
    this._onWiped,
    DateTime Function()? clock,
    this._preferencesLimit = wipePreferencesLimit,
  }) : _clock = clock ?? DateTime.now;

  final SwrCache _cache;
  final SettingsStore _settings;
  final DeviceScratch _scratch;

  /// Called once the preferences are gone, for state kept in memory.
  final void Function(WipeReason reason)? _onWiped;
  final DateTime Function() _clock;
  final Duration _preferencesLimit;

  /// The preferences step on its way, if any.
  _Wipe? _current;

  /// The last pass over the files, which the next one waits for.
  Future<void> _files = Future.value();

  /// Wipes the device for [reason]. It returns once the preferences are
  /// gone (a few milliseconds), so that nothing of the account is read
  /// after the sign-out shows, or after [wipePreferencesLimit] when the
  /// store does not answer; the files follow without holding anyone up
  /// ([settled]).
  ///
  /// A call while the preferences of a wipe that removes as much are being
  /// removed shares that step. Every call has its own pass over the files,
  /// after the passes before it, which touches nothing written after the
  /// call: a photo taken by someone who signed in since is theirs.
  Future<void> wipe(WipeReason reason) =>
      _wipe(reason, camera: reason.endsSession);

  Future<void> _wipe(WipeReason reason, {required bool camera}) {
    final current = _current;
    if (current != null && current.covers(reason, camera: camera)) {
      return _bounded(current.preferences);
    }
    final startedAt = _clock();
    final preferences = _forgetPreferences(reason, camera: camera);
    final run = _Wipe(reason, preferences, camera: camera);
    _current = run;
    unawaited(
      preferences.whenComplete(() {
        if (identical(_current, run)) _current = null;
      }),
    );
    _queueFiles(camera: camera, pickers: true, at: startedAt);
    return _bounded(preferences);
  }

  /// At start-up, once the stored session has been read: when nobody is
  /// [signedIn], a [WipeReason.startedSignedOut] wipe; otherwise only the
  /// files an earlier run left (the pickers' copies, the shared files older
  /// than [sharedFileGrace]).
  ///
  /// Either way, the camera's record, the photos the camera took on Android
  /// and the plugins' records of a pick the app was closed during stay only
  /// while a lost photo may still come back to its record
  /// ([photoMayReturn]: a readable record younger than a day). Otherwise
  /// the photo would be let go anyway, and they go: photos an older version
  /// of the app left, and a record nobody signed in again for, included.
  Future<void> atStart({required bool signedIn, required bool photoMayReturn}) {
    final camera = !photoMayReturn;
    if (!signedIn) return _wipe(WipeReason.startedSignedOut, camera: camera);
    final at = _clock();
    final preferences = camera
        ? _quietly(() => _settings.remove(AppSettings.cameraTargetKey))
        : Future<void>.value();
    _queueFiles(camera: camera, pickers: true, at: at);
    return _bounded(preferences);
  }

  /// [preferences], or nothing once the limit has passed.
  Future<void> _bounded(Future<void> preferences) =>
      preferences.timeout(_preferencesLimit, onTimeout: () {});

  /// When the app comes back to the foreground: the files written to share
  /// that have not changed for [sharedFileGrace]. Nothing else: a picker
  /// may be handing over a copy as the app comes back.
  void atResume() => _queueFiles(camera: false, pickers: false, at: _clock());

  /// Completes when every pass over the files started so far has finished,
  /// or run out of time ([wipeFilesLimit]).
  Future<void> get settled => _files;

  void _queueFiles({
    required bool camera,
    required bool pickers,
    required DateTime at,
  }) {
    _files = _files.then(
      (_) => _forgetFiles(
        camera: camera,
        pickers: pickers,
        at: at,
      ).timeout(wipeFilesLimit, onTimeout: () {}),
    );
  }

  Future<void> _forgetPreferences(
    WipeReason reason, {
    required bool camera,
  }) async {
    await _quietly(_cache.clear);
    await _quietly(() => _settings.remove(AppSettings.currentPortfolioKey));
    if (camera) {
      await _quietly(() => _settings.remove(AppSettings.cameraTargetKey));
    }
    if (reason == WipeReason.accountDeleted) {
      await _quietly(() => _settings.remove(AppSettings.pendingInvitationKey));
    }
    await _quietly(() async => _onWiped?.call(reason));
  }

  Future<void> _forgetFiles({
    required bool camera,
    required bool pickers,
    required DateTime at,
  }) async {
    if (camera) {
      final lost = await _quietly(_scratch.drainLostPicks);
      await _quietly(() => _scratch.discard(lost ?? const []));
    }
    if (pickers) {
      await _quietly(() => _scratch.clearPickerCopies(before: at));
    }
    await _quietly(
      () => _scratch.sweep(
        sharedBefore: at.subtract(sharedFileGrace),
        // Only what was there before the wipe began: a photo taken by
        // someone who signed in meanwhile is theirs.
        copiesBefore: camera ? at : null,
      ),
    );
  }
}

/// Whether a camera photo an earlier run lost may still come back to its
/// record, from the record kept in [SettingsStore] at a time. The documents
/// feature decides (`lostPhotoMayReturn`).
typedef LostPhotoCheck = bool Function(SettingsStore settings, DateTime now);

/// Starts, without waiting for it, the start-up wipe
/// ([DeviceDataWipe.atStart]) over the app's stores and [scratch] (the
/// phone's own by default), before any provider exists, once Supabase
/// ([auth]) has read the stored session: what an earlier run left of an
/// account when nobody is signed in, and the old files either way. A
/// session refused later is wiped as it signs out.
void tidyDeviceAtStart(
  SwrCache cache,
  SettingsStore settings, {
  required sb.GoTrueClient auth,
  required LostPhotoCheck photoMayReturn,
  DeviceScratch? scratch,
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  unawaited(
    DeviceDataWipe(
      cache: cache,
      settings: settings,
      scratch: scratch ?? PluginDeviceScratch.here(),
      clock: now,
    ).atStart(
      signedIn: auth.currentSession != null,
      photoMayReturn: photoMayReturn(settings, now()),
    ),
  );
}

/// Runs [step], and on any failure goes on without it.
Future<T?> _quietly<T>(Future<T> Function() step) async {
  try {
    return await step();
  } on Object {
    return null;
  }
}

/// The phone's folders and pickers; tests replace it.
final Provider<DeviceScratch> deviceScratchProvider = Provider<DeviceScratch>(
  (ref) => PluginDeviceScratch.here(),
);

/// How many wipes this run of the app has made. A provider that keeps a
/// device preference in memory (the current portfolio, a pending
/// invitation) watches it, so that it reads the preference again after a
/// wipe.
final NotifierProvider<DeviceDataWipes, int> deviceDataWipesProvider =
    NotifierProvider<DeviceDataWipes, int>(DeviceDataWipes.new);

/// Counts the wipes ([deviceDataWipesProvider]).
final class DeviceDataWipes extends Notifier<int> {
  @override
  int build() => 0;

  /// Records a wipe.
  void count() => state++;
}

/// Sweeps, each time the app comes back to the foreground, the files
/// written to share that have not changed for [sharedFileGrace]
/// ([DeviceDataWipe.atResume]). The app's root widget watches it.
final Provider<void> deviceTidyOnResumeProvider = Provider<void>((ref) {
  final lifecycle = AppLifecycleListener(
    onResume: () => ref.read(deviceDataWipeProvider).atResume(),
  );
  ref.onDispose(lifecycle.dispose);
});

/// The app's [DeviceDataWipe]. After each wipe the providers that keep a
/// device preference in memory read it again, and when a session ended the
/// decoded images (document thumbnails) are dropped from memory too.
final Provider<DeviceDataWipe> deviceDataWipeProvider =
    Provider<DeviceDataWipe>(
      (ref) => DeviceDataWipe(
        cache: ref.watch(swrCacheProvider),
        settings: ref.watch(settingsStoreProvider),
        scratch: ref.watch(deviceScratchProvider),
        onWiped: (reason) {
          ref.read(deviceDataWipesProvider.notifier).count();
          if (reason.endsSession) {
            PaintingBinding.instance.imageCache
              ..clear()
              ..clearLiveImages();
          }
        },
      ),
    );
