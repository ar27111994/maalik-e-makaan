import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:mm_core/mm_core.dart';

/// The profile of the user whose id is the argument: the saved copy at
/// once, then the server's.
final StreamNotifierProviderFamily<ProfileController, Snapshot<Profile>, String>
profileProvider = StreamNotifierProvider.autoDispose
    .family<ProfileController, Snapshot<Profile>, String>(
      ProfileController.new,
    );

/// Reads the profile and saves changes to it. Commands throw `AppFailure`.
///
/// It reads, and its commands ask for anything, only while the cache
/// serves its user's session (`SwrCache.serves`): built for another
/// account, or kept alive after its session ended, it reads nothing, and a
/// command throws `SessionExpired` before its request. It is built again
/// whenever the session changes, so the same account's next session reads
/// and saves again.
final class ProfileController extends StreamNotifier<Snapshot<Profile>> {
  new(this.userId);

  final String userId;

  /// The cache key of the profile query.
  static const query = 'profile';

  /// The profile is the user's own: no list of portfolios removes it.
  static final OwnScope<Profile> scope = OwnScope.profile();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  /// The session's epoch when the profile was built: what is asked for in
  /// it is saved only while the cache still serves it.
  int _epoch = 0;

  /// The cache's epoch the profile on show was asked for in: a profile
  /// made from it is saved for that epoch, so that one shown before the
  /// device was wiped is not saved again.
  int _shown = 0;

  @override
  Stream<Snapshot<Profile>> build() {
    final session = ref.watch(sessionProvider);
    final repository = ref.watch(profileRepositoryProvider);
    final cache = ref.watch(swrCacheProvider);
    final epoch = session?.epoch ?? 0;
    _epoch = epoch;
    // Another user's session, or nobody's: the profile goes from on show.
    if (!ref.isFirstBuild && session?.userId != userId) {
      state = sessionChanged();
    }
    return cache
        .watch(
          userId: userId,
          epoch: epoch,
          query: query,
          scope: scope,
          fetch: () => repository.fetch(userId),
          decode: Profile.fromRow,
          encode: (profile) => profile.toRow(),
        )
        .map((snapshot) {
          // Until it comes, the profile of the build before stays on show.
          _shown = epoch;
          return snapshot;
        });
  }

  /// Saves the name and phone and shows the profile as the server stored it.
  Future<void> saveDetails({
    required String fullName,
    required PhoneNumber? phone,
  }) async {
    final epoch = ref.read(swrCacheProvider).require(userId, _epoch);
    final saved = await _repository.updateDetails(
      userId,
      fullName: fullName,
      phone: phone,
    );
    await _show(saved, epoch);
  }

  /// Saves the app language to the profile, and shows the profile on show
  /// with it. That profile is saved only while the cache serves the session
  /// it was asked for in: what was shown in a session that has ended is not
  /// saved again with the new language.
  Future<void> saveLanguage(AppLanguage language) async {
    final epoch = ref.read(swrCacheProvider).require(userId, _epoch);
    await _repository.updateLanguage(userId, language);
    final current = state.value?.value;
    if (current != null) {
      await _show(
        current.copyWith(language: language),
        math.min(epoch, _shown),
      );
    }
  }

  /// Shows [profile], and saves it for [epoch], the cache's when (all of)
  /// it was asked for: neither once the cache no longer serves it.
  Future<void> _show(Profile profile, int epoch) async {
    final savedAt = await ref
        .read(swrCacheProvider)
        .write(
          userId,
          query,
          scope,
          profile,
          (profile) => profile.toRow(),
          epoch: epoch,
        );
    if (savedAt == null || !ref.mounted) return;
    _shown = epoch;
    state = AsyncData(
      Snapshot(profile, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}
