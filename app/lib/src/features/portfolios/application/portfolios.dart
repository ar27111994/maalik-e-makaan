import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
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
///
/// When a portfolio the device knew is no longer in the list (it was
/// deleted, or the user left it or was removed), the saved copies of its
/// records go: every other list the user's cache holds goes with them
/// ([SwrCache.forgetUser]), and comes back from the server when shown, but
/// the user's own profile and residence, which hold nothing of a portfolio
/// ([kept]). They go before the new list is saved: while they are not all
/// gone (the app was closed in between, or the store failed), the saved
/// list still names the portfolio, and the next load forgets them again.
/// With no saved list (a wipe that could not delete everything, a write
/// that landed out of order and was deleted, a write that failed, or the
/// session's first list save), what the device holds of the user is not
/// known to be of a portfolio still in the list, and the save forgets it
/// all the same: whatever the store holds, and, as the forget starts a new
/// epoch, every write asked for before it, also one whose answer is still
/// on its way. So does a saved list a failed write left unsettled, and any
/// while the store may still hold an entry that was to go.
final class PortfoliosController
    extends StreamNotifier<Snapshot<List<PortfolioMembership>>> {
  new(this.userId);

  final String userId;

  /// The cache key of the portfolio list.
  static const query = 'portfolios';

  /// The queries a portfolio leaving, or a missing saved list, never
  /// forgets: the list itself, and the user's own profile and residence,
  /// which hold nothing of any portfolio. Every other query of the app
  /// reads records of a portfolio, whatever its key names.
  static const Set<String> kept = {
    query,
    ProfileController.query,
    ResidenceController.query,
  };

  /// The queries in [kept] but the list: the user's own, which a forget
  /// never deletes, so a stray of theirs ([SwrCache.strayed]) says nothing
  /// of a portfolio.
  static const Set<String> _own = {
    ProfileController.query,
    ResidenceController.query,
  };

  /// The cache's epoch when the list was built.
  int _epoch = 0;

  /// The cache's epoch the list on show was asked for in: a list made from
  /// it is saved for that epoch (or an older one), so that one shown
  /// before the device was wiped is not saved again.
  int _shown = 0;

  @override
  Stream<Snapshot<List<PortfolioMembership>>> build() {
    final repository = ref.watch(portfolioRepositoryProvider);
    final cache = ref.watch(swrCacheProvider);
    final epoch = cache.epoch;
    _epoch = epoch;
    return _watch(cache, repository, epoch);
  }

  /// The saved list first (when there is one), then the server's, saved
  /// for [epoch], the cache's when the list was built. A failing read ends
  /// the stream with its error after the saved list.
  Stream<Snapshot<List<PortfolioMembership>>> _watch(
    SwrCache cache,
    PortfolioRepository repository,
    int epoch,
  ) async* {
    final saved = await cache.read(userId, query, _decode);
    if (saved != null) {
      _shown = epoch;
      yield saved;
    }
    final asked = cache.ask();
    final list = await repository.listMine(userId);
    final fresh = await _save(cache, list, epoch, asked: asked);
    // Out of date: a list asked later is on show.
    if (fresh == null) return;
    _shown = epoch;
    yield fresh;
  }

  /// The epoch of a request made now, read before it: a list that comes
  /// back after the device was wiped meanwhile is not kept, whatever
  /// happened to this controller in between ([SwrCache.requestEpoch]).
  int _requestEpoch() =>
      ref.read(swrCacheProvider).requestEpoch(madeIn: _epoch);

  /// Saves [list] for [epoch] as the server's latest, once the user's
  /// saved records are forgotten when a portfolio of the saved list is not
  /// in it. While they could not all be forgotten the list is not saved:
  /// the saved one goes on naming that portfolio, for the next save or load
  /// to forget them.
  ///
  /// The saves of the list run one after another ([SwrCache.serially]):
  /// two that met could otherwise both read the same saved list, and the
  /// store finish the older write last, so that the saved list stopped
  /// naming a portfolio whose records stay, and its leaving later would
  /// not forget them.
  ///
  /// Each call to the store is waited for at most [SwrCache.callLimit], so
  /// that one that never answers holds up no later save. The choice made
  /// then is the safe one: a saved list that could not be read counts as
  /// unknown, a list not saved because the records could not be forgotten
  /// leaves the saved one naming the portfolio, and a list whose write has
  /// not answered may still land, so the next save counts it as saved too
  /// ([SwrCache.writing]). After a write of the list failed, the saved list
  /// counts as unknown until a later one lands ([SwrCache.unsettled]): the
  /// store may hold an older list, without a portfolio whose records were
  /// saved since. So it does while the store may hold an entry that was to
  /// go ([SwrCache.strayed]): a record that landed after its portfolio left,
  /// or an older list that landed after a later one, whose deletion failed
  /// or has not answered.
  ///
  /// A server's answer comes with [asked], the number of its request
  /// ([SwrCache.ask]). It is neither saved nor shown (null) when the answer
  /// to a request asked later was saved first ([SwrCache.claim]): it is out
  /// of date, and could name a portfolio that has left again.
  Future<Snapshot<List<PortfolioMembership>>?> _save(
    SwrCache cache,
    List<PortfolioMembership> list,
    int epoch, {
    int? asked,
  }) => cache.serially(userId, query, () async {
    if (asked != null && !cache.claim(userId, query, asked)) return null;
    final limit = cache.callLimit;
    // Taken before the read: one that lands meanwhile is in either.
    final landing = [
      for (final json in cache.writing(userId, query)) ..._decode(json),
    ];
    List<PortfolioMembership>? before;
    try {
      final saved = await cache.read(userId, query, _decode).timeout(limit);
      // Taken after the read: a write that failed before it ended may have
      // left an older list, and one that landed after a removal or a later
      // write, a record or a list the store kept.
      if (saved != null &&
          !cache.unsettled(userId, query) &&
          !cache.strayed(userId, except: _own)) {
        before = [...saved.value, ...landing];
      }
    } on Object {
      // Not read: unknown, as when there is none.
    }
    var savedAt = cache.now();
    if (await _forgetLeft(cache, before, list)) {
      try {
        savedAt = await cache
            .write(userId, query, _encode(list), epoch: epoch)
            .timeout(limit);
      } on TimeoutException {
        // It may still land; the next save counts it as saved.
      }
    }
    return Snapshot(list, savedAt: savedAt, source: SnapshotSource.network);
  });

  /// Forgets the user's saved records when a portfolio of [before] is not
  /// in [after], or when [before] is unknown (null). False when they could
  /// not all be forgotten in time ([SwrCache.callLimit]).
  Future<bool> _forgetLeft(
    SwrCache cache,
    List<PortfolioMembership>? before,
    List<PortfolioMembership> after,
  ) async {
    final staying = {for (final membership in after) membership.id};
    if (before != null && before.every((m) => staying.contains(m.id))) {
      return true;
    }
    try {
      await cache.forgetUser(userId, keep: kept).timeout(cache.callLimit);
      return true;
    } on Object {
      return false;
    }
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
    final epoch = _requestEpoch();
    final created = await repository.create(
      name: name,
      id: id,
      ownerAbroad: ownerAbroad,
    );
    final cache = ref.read(swrCacheProvider);
    List<PortfolioMembership> list;
    var listEpoch = epoch;
    int? asked = cache.ask();
    try {
      list = await repository.listMine(userId);
    } on AppFailure {
      asked = null;
      // It exists: show it with the ones already known, and let the next
      // refresh bring the server's list.
      list = sortByName([
        ...?state.value?.value.where((other) => other.id != created.id),
        created,
      ]);
      listEpoch = math.min(epoch, _shown);
    }
    await _show(list, listEpoch, asked: asked);
    await ref
        .read(selectedPortfolioProvider(userId).notifier)
        .select(created.id, askedIn: epoch);
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
    final epoch = _requestEpoch();
    await repository.delete(portfolioId, confirmation: confirmation);
    final cache = ref.read(swrCacheProvider);
    List<PortfolioMembership> list;
    var listEpoch = epoch;
    int? asked = cache.ask();
    try {
      list = await repository.listMine(userId);
    } on AppFailure {
      asked = null;
      // It is gone: list the others known, and let the next refresh bring
      // the server's list.
      list = [...?state.value?.value.where((other) => other.id != portfolioId)];
      listEpoch = math.min(epoch, _shown);
    }
    if (ref.mounted) await _show(list, listEpoch, asked: asked);
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
    final epoch = _requestEpoch();
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
      ], math.min(epoch, _shown));
    }
    return answer;
  }

  /// Reads the list again, after the user joined, left or renamed a
  /// portfolio, and returns it. Throws [AppFailure] when it cannot be read;
  /// the list on screen then stays as it was.
  Future<List<PortfolioMembership>> reload() async {
    final epoch = _requestEpoch();
    final asked = ref.read(swrCacheProvider).ask();
    final list = await ref.read(portfolioRepositoryProvider).listMine(userId);
    if (ref.mounted) await _show(list, epoch, asked: asked);
    return list;
  }

  /// Shows [list], and saves it for [epoch], the cache's when (all of) it
  /// was asked for ([_save]): [_requestEpoch] for the server's answer, and
  /// no later than [_shown] for a list made from the one on show. A
  /// server's answer comes with [asked], and is not shown when out of date.
  Future<void> _show(
    List<PortfolioMembership> list,
    int epoch, {
    int? asked,
  }) async {
    final snapshot = await _save(
      ref.read(swrCacheProvider),
      list,
      epoch,
      asked: asked,
    );
    if (snapshot == null || !ref.mounted) return;
    _shown = epoch;
    state = AsyncData(snapshot);
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

  /// Makes [portfolioId] the current portfolio on this device. A command
  /// that chooses it after a request passes [askedIn], the
  /// [SwrCache.epoch] read before the request: when the session ended
  /// meanwhile, nothing is chosen, and nothing is written on the device
  /// that its wipe removed.
  Future<void> select(String portfolioId, {int? askedIn}) async {
    if (askedIn != null && ref.read(swrCacheProvider).clearedSince(askedIn)) {
      return;
    }
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
