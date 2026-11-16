import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence_repository.dart';
import 'package:mm_core/mm_core.dart';

/// The declared residence of the user whose id is the argument: the saved
/// copy at once, then the server's.
final StreamNotifierProviderFamily<
  ResidenceController,
  Snapshot<AccountResidence>,
  String
>
residenceProvider = StreamNotifierProvider.autoDispose
    .family<ResidenceController, Snapshot<AccountResidence>, String>(
      ResidenceController.new,
    );

/// Reads the user's residence and saves changes to it. Commands throw
/// `AppFailure`.
///
/// Like the profile (`ProfileController`), it reads and asks for anything
/// only while the cache serves its user's session, and is built again
/// whenever the session changes.
final class ResidenceController
    extends StreamNotifier<Snapshot<AccountResidence>> {
  new(this.userId);

  final String userId;

  /// The cache key of the residence query.
  static const query = 'residence';

  /// The residence is the user's own: no list of portfolios removes it.
  static final OwnScope<AccountResidence> scope = OwnScope.residence();

  /// The session's epoch when the residence was built: what is asked for
  /// in it is saved only while the cache still serves it.
  int _epoch = 0;

  @override
  Stream<Snapshot<AccountResidence>> build() {
    final session = ref.watch(sessionProvider);
    final repository = ref.watch(residenceRepositoryProvider);
    final cache = ref.watch(swrCacheProvider);
    _epoch = session?.epoch ?? 0;
    // Another user's session, or nobody's: the residence goes from on show.
    if (!ref.isFirstBuild && session?.userId != userId) {
      state = sessionChanged();
    }
    return cache.watch(
      userId: userId,
      epoch: _epoch,
      query: query,
      scope: scope,
      fetch: () => repository.fetch(userId),
      decode: AccountResidence.fromRow,
      encode: (residence) => residence.toRow(),
    );
  }

  /// Saves the country and zone the user chose and shows them as stored.
  Future<void> save({
    required CountryCode? country,
    required TimeZoneId? timeZone,
  }) async {
    final cache = ref.read(swrCacheProvider);
    // Before the request: nothing is asked for a session that has ended,
    // and an answer that comes after it ended is neither saved nor shown.
    final epoch = cache.require(userId, _epoch);
    final saved = await ref
        .read(residenceRepositoryProvider)
        .update(userId, country: country, timeZone: timeZone);
    // Kept for next time even when nobody shows it any more.
    final savedAt = await cache.write(
      userId,
      query,
      scope,
      saved,
      (residence) => residence.toRow(),
      epoch: epoch,
    );
    if (savedAt == null || !ref.mounted) return;
    state = AsyncData(
      Snapshot(saved, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}

/// The zone of the signed-in user's own alerts, digests, quiet hours and
/// the second time of a dual time: the zone they stated when this app knows
/// it, otherwise Pakistan's (signed out, loading, not readable, or not
/// stated). Rent, ledger and due dates, deadlines and messages to tenants
/// never read it: they stay on Pakistan time.
final alertZoneProvider = Provider<TimeZoneId>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return TimeZoneId.pakistan;
  final residence = ref.watch(residenceProvider(userId)).value?.value;
  return residence?.alertZone ?? TimeZoneId.pakistan;
});
