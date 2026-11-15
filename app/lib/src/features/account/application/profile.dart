import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
final class ProfileController extends StreamNotifier<Snapshot<Profile>> {
  new(this.userId);

  final String userId;

  /// The cache key of the profile query.
  static const query = 'profile';

  /// The profile is the user's own: no list of portfolios removes it.
  static final OwnScope<Profile> scope = OwnScope.profile();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  /// The cache's epoch when the profile was built: a profile saved after
  /// the device was wiped since (the session ended) is not kept on it.
  int _epoch = 0;

  /// The cache's epoch the profile on show was asked for in: a profile
  /// made from it is saved for that epoch, so that one shown before the
  /// device was wiped is not saved again.
  int _shown = 0;

  @override
  Stream<Snapshot<Profile>> build() {
    final repository = ref.watch(profileRepositoryProvider);
    final cache = ref.watch(swrCacheProvider);
    final epoch = cache.epoch;
    _epoch = epoch;
    return cache
        .watch(
          userId: userId,
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
    final epoch = _epoch;
    final saved = await _repository.updateDetails(
      userId,
      fullName: fullName,
      phone: phone,
    );
    await _show(saved, epoch);
  }

  /// Saves the app language to the profile, and shows the profile on show
  /// with it. That profile is saved only when the device was not wiped
  /// since it was asked for: what was shown in a session that has ended is
  /// not saved again with the new language.
  Future<void> saveLanguage(AppLanguage language) async {
    final epoch = _epoch;
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
  /// it was asked for.
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
    if (!ref.mounted) return;
    _shown = epoch;
    state = AsyncData(
      Snapshot(profile, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}
