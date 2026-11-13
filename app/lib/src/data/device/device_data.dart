import 'dart:async';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/scratch_files_stub.dart'
    if (dart.library.io) 'package:maalik_e_makaan/src/data/device/scratch_files_io.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';

/// Why the device's copy of an account is wiped, from the least to the
/// most that goes.
enum WipeReason {
  /// The app started with nobody signed in: what an earlier run left behind
  /// (a version before the wipe, or a run closed in the middle of one). The
  /// camera's record of a photo and the photo itself stay, so that signing
  /// in again can still bring the photo back to its record.
  startedSignedOut,

  /// A session ended: the user signed out, or it expired or was revoked
  /// elsewhere.
  signedOut,

  /// The account was deleted: the invitation the device held goes too.
  accountDeleted;

  /// Whether a session ended (not a start-up tidy).
  bool get endsSession => this != startedSignedOut;

  /// Whether a wipe for this reason removes everything one for [other]
  /// does.
  bool covers(WipeReason other) => index >= other.index;
}

/// How long a file written to share is kept after it last changed: the app
/// it was shared with (WhatsApp, e-mail) may read it after the share sheet
/// has closed. A sweep leaves younger files for the next start.
const sharedFileGrace = Duration(minutes: 10);

/// How long the files of a wipe may take before [DeviceDataWipe.settled]
/// stops waiting for them.
const wipeFilesLimit = Duration(seconds: 30);

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

  /// Deletes file_picker's copies: Android's `cache/file_picker/`, and on
  /// iOS everything in the app's `tmp/` (where the camera also leaves its
  /// photos).
  Future<void> clearPickerCopies();

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
/// everyone's) nothing is touched.
final class PluginDeviceScratch implements DeviceScratch {
  new({this._platform, ImagePicker? camera})
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

  /// The app's cache folder (path_provider's temporary directory: Android's
  /// cache, iOS's `Library/Caches`).
  Future<String> _cacheFolder() async =>
      (await getTemporaryDirectory().timeout(pluginCallLimit)).path;

  @override
  Future<void> discard(Iterable<String> paths) async {
    if (_platform == null) return;
    try {
      final temp = systemTempPath();
      await deleteCopies([
        await _cacheFolder(),
        if (_platform == TargetPlatform.iOS && temp != null) temp,
      ], paths);
    } on Object {
      // Without the cache folder nothing is known to be the app's.
    }
  }

  @override
  Future<void> clearPickerCopies() async {
    if (_platform == null) return;
    await FilePicker.clearTemporaryFiles().timeout(pluginCallLimit);
  }

  @override
  Future<List<String>> drainLostPicks() async {
    if (_platform != TargetPlatform.android) return const [];
    final paths = <String>{};
    try {
      final lost = await _camera.retrieveLostData().timeout(pluginCallLimit);
      paths.addAll([
        ...?lost.files?.map((file) => file.path),
        ?lost.file?.path,
      ]);
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

/// The preferences step of a wipe on its way, for single-flight.
final class _Wipe {
  new(this.reason, this.preferences);

  final WipeReason reason;
  final Future<void> preferences;
}

/// Removes what the app kept on the device for an account, when its
/// session ends (whatever ended it) and when the app starts with nobody
/// signed in.
///
/// It removes:
///
/// - the saved copy of every list the app loaded (the [SwrCache]);
/// - the portfolio last chosen on the device;
/// - the camera's record of a photo being taken, and on Android the
///   camera's and the file picker's record of a pick the app was closed
///   during, with its files (not at start-up: see
///   [WipeReason.startedSignedOut]);
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
/// shared is the person's own.
///
/// Every step runs on its own: one that fails leaves the others to run. It
/// never throws, and logs nothing (a file's name can carry a tenant's).
final class DeviceDataWipe {
  new({
    required this._cache,
    required this._settings,
    required this._scratch,
    this._onWiped,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SwrCache _cache;
  final SettingsStore _settings;
  final DeviceScratch _scratch;

  /// Called once the preferences are gone, for state kept in memory.
  final void Function(WipeReason reason)? _onWiped;
  final DateTime Function() _clock;

  /// The preferences step on its way, if any.
  _Wipe? _current;

  /// The last pass over the files, which the next one waits for.
  Future<void> _files = Future.value();

  /// Wipes the device for [reason]. It returns once the preferences are
  /// gone (a few milliseconds), so that nothing of the account is read
  /// after the sign-out shows; the files follow without holding anyone up
  /// ([settled]).
  ///
  /// A call while the preferences of a wipe that removes as much are being
  /// removed shares that step. Every call has its own pass over the files,
  /// after the passes before it, which touches nothing written after the
  /// call: a photo taken by someone who signed in since is theirs.
  Future<void> wipe(WipeReason reason) {
    final current = _current;
    if (current != null && current.reason.covers(reason)) {
      return current.preferences;
    }
    final startedAt = _clock();
    final preferences = _forgetPreferences(reason);
    final run = _Wipe(reason, preferences);
    _current = run;
    unawaited(
      preferences.whenComplete(() {
        if (identical(_current, run)) _current = null;
      }),
    );
    _queueFiles(endsSession: reason.endsSession, at: startedAt);
    return preferences;
  }

  /// At start-up: when nobody is signed in, a [WipeReason.startedSignedOut]
  /// wipe; otherwise only the files an earlier run left (the shared files
  /// older than [sharedFileGrace], the file picker's copies). The camera's
  /// photos stay either way, for a lost photo to come back.
  Future<void> atStart({required bool signedIn}) {
    if (!signedIn) return wipe(WipeReason.startedSignedOut);
    _queueFiles(endsSession: false, at: _clock());
    return Future.value();
  }

  /// Completes when every pass over the files started so far has finished,
  /// or run out of time ([wipeFilesLimit]).
  Future<void> get settled => _files;

  void _queueFiles({required bool endsSession, required DateTime at}) {
    _files = _files.then(
      (_) => _forgetFiles(
        endsSession: endsSession,
        at: at,
      ).timeout(wipeFilesLimit, onTimeout: () {}),
    );
  }

  Future<void> _forgetPreferences(WipeReason reason) async {
    await _quietly(_cache.clear);
    await _quietly(() => _settings.remove(AppSettings.currentPortfolioKey));
    if (reason.endsSession) {
      await _quietly(() => _settings.remove(AppSettings.cameraTargetKey));
    }
    if (reason == WipeReason.accountDeleted) {
      await _quietly(() => _settings.remove(AppSettings.pendingInvitationKey));
    }
    await _quietly(() async => _onWiped?.call(reason));
  }

  Future<void> _forgetFiles({
    required bool endsSession,
    required DateTime at,
  }) async {
    if (endsSession) {
      final lost = await _quietly(_scratch.drainLostPicks);
      await _quietly(() => _scratch.discard(lost ?? const []));
    }
    await _quietly(_scratch.clearPickerCopies);
    await _quietly(
      () => _scratch.sweep(
        sharedBefore: at.subtract(sharedFileGrace),
        // Only what was there before the wipe began: a photo taken by
        // someone who signed in meanwhile is theirs.
        copiesBefore: endsSession ? at : null,
      ),
    );
  }
}

/// Starts, without waiting for it, the start-up wipe ([DeviceDataWipe.atStart])
/// over the app's stores and [scratch] (the phone's own by default), before
/// any provider exists: what an earlier run left of an account when nobody
/// is signed in, and the old files either way.
void tidyDeviceAtStart(
  SwrCache cache,
  SettingsStore settings, {
  required bool signedIn,
  DeviceScratch? scratch,
}) => unawaited(
  DeviceDataWipe(
    cache: cache,
    settings: settings,
    scratch: scratch ?? PluginDeviceScratch.here(),
  ).atStart(signedIn: signedIn),
);

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
