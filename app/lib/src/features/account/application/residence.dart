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
final class ResidenceController
    extends StreamNotifier<Snapshot<AccountResidence>> {
  new(this.userId);

  final String userId;

  /// The cache key of the residence query.
  static const query = 'residence';

  @override
  Stream<Snapshot<AccountResidence>> build() {
    final repository = ref.watch(residenceRepositoryProvider);
    return ref
        .watch(swrCacheProvider)
        .watch(
          userId: userId,
          query: query,
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
    final saved = await ref
        .read(residenceRepositoryProvider)
        .update(userId, country: country, timeZone: timeZone);
    // Kept for next time even when nobody shows it any more.
    final savedAt = await cache.write(userId, query, saved.toRow());
    if (!ref.mounted) return;
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
