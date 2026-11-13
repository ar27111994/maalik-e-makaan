import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

/// The portfolios of the user whose id is the argument: the saved list at
/// once, then the server's.
final StreamNotifierProviderFamily<
  PortfoliosController,
  Snapshot<List<PortfolioMembership>>,
  String
>
portfoliosProvider = StreamNotifierProvider.autoDispose
    .family<PortfoliosController, Snapshot<List<PortfolioMembership>>, String>(
      PortfoliosController.new,
    );

/// Reads the user's portfolios and creates new ones.
final class PortfoliosController
    extends StreamNotifier<Snapshot<List<PortfolioMembership>>> {
  new(this.userId);

  final String userId;

  /// The cache key of the portfolio list.
  static const query = 'portfolios';

  @override
  Stream<Snapshot<List<PortfolioMembership>>> build() {
    final repository = ref.watch(portfolioRepositoryProvider);
    return ref
        .watch(swrCacheProvider)
        .watch(
          userId: userId,
          query: query,
          fetch: () => repository.listMine(userId),
          decode: _decode,
          encode: _encode,
        );
  }

  static List<PortfolioMembership> _decode(Object? json) {
    if (json is! List) throw const FormatException('not a list');
    return [for (final row in json) PortfolioMembership.fromRow(row)];
  }

  static Object? _encode(List<PortfolioMembership> list) => [
    for (final membership in list) membership.toRow(),
  ];

  /// Creates a portfolio (see [PortfolioRepository.create]; keep [id] for
  /// retries of the same attempt), lists it with the others and makes it the
  /// current one on this device. Throws [AppFailure].
  ///
  /// [ownerAbroad] is the creator's answer to "Does the owner of these
  /// properties live abroad?" (none chosen in advance; never taken from
  /// their residence).
  Future<PortfolioMembership> create({
    required String name,
    required String id,
    OwnerAbroad ownerAbroad = OwnerAbroad.notAnswered,
  }) async {
    final repository = ref.read(portfolioRepositoryProvider);
    final created = await repository.create(
      name: name,
      id: id,
      ownerAbroad: ownerAbroad,
    );
    List<PortfolioMembership> list;
    try {
      list = await repository.listMine(userId);
    } on AppFailure {
      // It exists: show it with the ones already known, and let the next
      // refresh bring the server's list.
      list = sortByName([
        ...?state.value?.value.where((other) => other.id != created.id),
        created,
      ]);
    }
    await _show(list);
    await ref
        .read(selectedPortfolioProvider(userId).notifier)
        .select(created.id);
    return created;
  }

  /// Deletes the portfolio [portfolioId] (see [PortfolioRepository.delete];
  /// [confirmation] is its name as typed) and lists the user's others; the
  /// current portfolio becomes their first, as when they leave one. Throws
  /// [AppFailure], and then nothing changed.
  Future<void> delete(
    String portfolioId, {
    required String confirmation,
  }) async {
    final repository = ref.read(portfolioRepositoryProvider);
    await repository.delete(portfolioId, confirmation: confirmation);
    List<PortfolioMembership> list;
    try {
      list = await repository.listMine(userId);
    } on AppFailure {
      // It is gone: list the others known, and let the next refresh bring
      // the server's list.
      list = [...?state.value?.value.where((other) => other.id != portfolioId)];
    }
    if (ref.mounted) await _show(list);
  }

  /// Answers "Does the owner of these properties live abroad?" for
  /// [portfolioId], when the app asks on opening a portfolio nobody has
  /// answered for (see [ownerAbroadQuestionProvider]), and shows the answer
  /// as stored in the list: when someone else answered first, theirs.
  /// Throws [AppFailure].
  Future<OwnerAbroad> answerOwnerAbroad(
    String portfolioId, {
    required bool abroad,
  }) async {
    final answer = await ref
        .read(portfolioRepositoryProvider)
        .answerOwnerAbroad(portfolioId, abroad: abroad);
    final list = state.value?.value;
    if (list != null && ref.mounted) {
      await _show([
        for (final membership in list)
          if (membership.id == portfolioId)
            membership.withOwnerAbroad(answer)
          else
            membership,
      ]);
    }
    return answer;
  }

  /// Reads the list again, after the user joined, left or renamed a
  /// portfolio, and returns it. Throws [AppFailure] when it cannot be read;
  /// the list on screen then stays as it was.
  Future<List<PortfolioMembership>> reload() async {
    final list = await ref.read(portfolioRepositoryProvider).listMine(userId);
    if (ref.mounted) await _show(list);
    return list;
  }

  Future<void> _show(List<PortfolioMembership> list) async {
    final savedAt = await ref
        .read(swrCacheProvider)
        .write(userId, query, _encode(list));
    if (ref.mounted) {
      state = AsyncData(
        Snapshot(list, savedAt: savedAt, source: SnapshotSource.network),
      );
    }
  }
}

/// The id of the portfolio the user (the argument) last chose on this
/// device; null until they choose one.
final NotifierProviderFamily<SelectedPortfolioController, String?, String>
selectedPortfolioProvider =
    NotifierProvider.family<SelectedPortfolioController, String?, String>(
      SelectedPortfolioController.new,
    );

/// Remembers the chosen portfolio on the device, per user, until a session
/// ends (`DeviceDataWipe`).
final class SelectedPortfolioController extends Notifier<String?> {
  new(this.userId);

  final String userId;

  String get _prefix => '$userId/';

  @override
  String? build() {
    // Read again after a wipe, which forgets it.
    ref.watch(deviceDataWipesProvider);
    final saved = ref
        .watch(settingsStoreProvider)
        .getString(AppSettings.currentPortfolioKey);
    if (saved == null || !saved.startsWith(_prefix)) return null;
    return saved.substring(_prefix.length);
  }

  /// Makes [portfolioId] the current portfolio on this device.
  Future<void> select(String portfolioId) async {
    state = portfolioId;
    await ref
        .read(settingsStoreProvider)
        .setString(AppSettings.currentPortfolioKey, '$_prefix$portfolioId');
  }
}

/// The portfolio every screen works in: the one last chosen on this device
/// if the user still belongs to it, otherwise their first; null when they
/// have none. Loading while nobody is signed in.
///
/// Feature providers watch it, so switching portfolios refreshes them all.
final currentPortfolioProvider = Provider<AsyncValue<PortfolioMembership?>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const AsyncLoading();
  final selected = ref.watch(selectedPortfolioProvider(userId));
  final portfolios = ref.watch(portfoliosProvider(userId));
  // A saved or earlier list stays usable while a refresh runs or after it
  // failed (offline): the screens say so, the work goes on. (`whenData`
  // would drop it.)
  final snapshot = portfolios.value;
  if (snapshot != null) return AsyncData(pickCurrent(snapshot.value, selected));
  if (portfolios case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  return const AsyncLoading();
});

/// The portfolio [selected] names in [memberships], else the first, else
/// null.
PortfolioMembership? pickCurrent(
  List<PortfolioMembership> memberships,
  String? selected,
) {
  for (final membership in memberships) {
    if (membership.id == selected) return membership;
  }
  return memberships.isEmpty ? null : memberships.first;
}

/// The id of the current portfolio when the app should ask "Does the owner
/// of these properties live abroad?": nobody has answered, the user is an
/// owner or a manager, and the list was just read from the server (a saved
/// copy may be out of date: someone may have answered since). Otherwise
/// null. The question starts with no answer chosen; nothing is taken from
/// the user's residence.
final ownerAbroadQuestionProvider = Provider<String?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final snapshot = ref.watch(portfoliosProvider(userId)).value;
  if (snapshot == null || snapshot.fromCache) return null;
  final current = pickCurrent(
    snapshot.value,
    ref.watch(selectedPortfolioProvider(userId)),
  );
  return current != null && current.asksOwnerAbroad ? current.id : null;
});

/// Whether the signed-in user has a portfolio to work in, for the router.
enum PortfolioGate {
  /// Not known yet (loading, failed without a saved copy, or signed out).
  unknown,

  /// They belong to none: they create their first.
  none,

  /// They have one.
  some,
}

final portfolioGateProvider = Provider<PortfolioGate>((ref) {
  final current = ref.watch(currentPortfolioProvider);
  if (!current.hasValue) return PortfolioGate.unknown;
  return current.value == null ? PortfolioGate.none : PortfolioGate.some;
});
