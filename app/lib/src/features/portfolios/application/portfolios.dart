import 'dart:async';
import 'dart:math' as math;

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
///
/// It reads, and its commands ask for anything, only while the cache serves
/// its user's session ([SwrCache.serves]): a command throws
/// [SessionExpired] before each request when that session has ended (also
/// during an earlier request of the command), and an answer that comes
/// after it ended is neither shown, applied nor saved. It is built again
/// whenever the session changes ([sessionProvider]).
///
/// Each list the server answers sets, in the cache, the portfolios the
/// user is in ([SwrCache.applyPortfolios]): the saved records of a
/// portfolio that is no longer in it (deleted, or the user left it or was
/// removed) go then, found from the keys alone, and so does every entry
/// whose portfolio is not known; nothing of it is saved again until the
/// user is back in it. The list is shown at once, and saved without waiting
/// for the store.
final class PortfoliosController
    extends StreamNotifier<Snapshot<List<PortfolioMembership>>> {
  new(this.userId);

  final String userId;

  /// The cache key of the portfolio list.
  static const query = 'portfolios';

  /// The portfolio list is the user's own, and names its portfolios.
  static final OwnScope<List<PortfolioMembership>> scope =
      OwnScope.portfolioList((list) => [for (final m in list) m.id]);

  /// The session's epoch when the list was built: each session's lists
  /// are asked for in its own epoch, and applied and saved only while the
  /// cache still serves it.
  int _epoch = 0;

  /// The cache's epoch the list on show was asked for in: a list made from
  /// it is saved for that epoch (or an older one), so that one shown
  /// in a session that has ended is not saved again.
  int _shown = 0;

  @override
  Stream<Snapshot<List<PortfolioMembership>>> build() {
    final session = ref.watch(sessionProvider);
    final repository = ref.watch(portfolioRepositoryProvider);
    final cache = ref.watch(swrCacheProvider);
    final epoch = session?.epoch ?? 0;
    _epoch = epoch;
    // Another user's session, or nobody's: the list goes from on show.
    if (!ref.isFirstBuild && session?.userId != userId) {
      state = sessionChanged();
    }
    // While the session is not this user's, nothing is read.
    if (!cache.serves(userId, epoch)) {
      return Stream.error(const SessionExpired());
    }
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
    final saved = await cache.read(userId, query, scope, _decode, epoch: epoch);
    if (saved != null) {
      _shown = epoch;
      yield saved;
    }
    final asked = cache.ask();
    final list = await repository.listMine(userId);
    final fresh = _save(cache, list, epoch, asked: asked);
    // Out of date (a list asked later is on show), or of a session that has
    // ended.
    if (fresh == null) return;
    _shown = epoch;
    yield fresh;
  }

  /// Saves [list] for [epoch] and returns it as shown, without waiting for
  /// the store (one that never answers holds up nothing).
  ///
  /// It is neither saved nor shown (null) unless the cache serves the
  /// session of [epoch]. A server's answer comes with [asked], the number
  /// of its request ([SwrCache.ask]), and sets the portfolios the cache
  /// keeps ([SwrCache.applyPortfolios]). It is neither saved nor shown
  /// either when the answer to a request asked later was applied first: it
  /// is out of date, and could name a portfolio that has left again.
  ///
  /// A list made from the one on show carries no number and sets nothing:
  /// it is cut to the portfolios the cache keeps, when it knows them, so it
  /// never names one a server's answer dropped.
  Snapshot<List<PortfolioMembership>>? _save(
    SwrCache cache,
    List<PortfolioMembership> list,
    int epoch, {
    int? asked,
  }) {
    final savedAt = cache.now();
    if (!cache.serves(userId, epoch)) return null;
    if (asked != null &&
        !cache.applyPortfolios(
          userId,
          [for (final m in list) m.id],
          asked: asked,
          epoch: epoch,
        )) {
      return null;
    }
    final members = cache.portfoliosOf(userId);
    final shown = members == null
        ? list
        : [
            for (final m in list)
              if (members.contains(m.id)) m,
          ];
    unawaited(
      cache
          .write(
            userId,
            query,
            scope,
            shown,
            _encode,
            epoch: epoch,
            savedAt: savedAt,
          )
          .then((_) {}, onError: (_) {}),
    );
    return Snapshot(shown, savedAt: savedAt, source: SnapshotSource.network);
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
    final cache = ref.read(swrCacheProvider);
    final epoch = cache.require(userId, _epoch);
    final created = await repository.create(
      name: name,
      id: id,
      ownerAbroad: ownerAbroad,
    );
    // The epoch taken at the start, not [_epoch] again: after a rebuild,
    // that is the next session's.
    cache
      ..require(userId, epoch)
      // The server confirmed it: its records are kept until the next list.
      ..addPortfolio(userId, created.id, epoch: epoch);
    final asked = cache.ask();
    try {
      final list = await repository.listMine(userId);
      await _show(list, epoch, asked: asked);
    } on AppFailure {
      // It exists: show it with the ones already known, and let the next
      // refresh bring the server's list.
      await _show(
        sortByName([
          ...?state.value?.value.where((other) => other.id != created.id),
          created,
        ]),
        math.min(epoch, _shown),
      );
    }
    // Chosen in the session that created it, not in the next one.
    if (cache.serves(userId, epoch)) {
      await ref
          .read(selectedPortfolioProvider(userId).notifier)
          .select(created.id);
    }
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
    final cache = ref.read(swrCacheProvider);
    final epoch = cache.require(userId, _epoch);
    await repository.delete(portfolioId, confirmation: confirmation);
    cache
      ..require(userId, epoch)
      // It is gone: its records go now.
      ..removePortfolio(userId, portfolioId, epoch: epoch);
    final asked = cache.ask();
    try {
      final list = await repository.listMine(userId);
      if (ref.mounted) await _show(list, epoch, asked: asked);
    } on AppFailure {
      // List the others known, and let the next refresh bring the server's
      // list.
      if (ref.mounted) {
        await _show([
          ...?state.value?.value.where((other) => other.id != portfolioId),
        ], math.min(epoch, _shown));
      }
    }
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
    final epoch = ref.read(swrCacheProvider).require(userId, _epoch);
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
    final cache = ref.read(swrCacheProvider);
    final epoch = cache.require(userId, _epoch);
    final asked = cache.ask();
    final list = await ref.read(portfolioRepositoryProvider).listMine(userId);
    if (ref.mounted) await _show(list, epoch, asked: asked);
    return list;
  }

  /// Shows [list], and saves it for [epoch], the cache's when (all of) it
  /// was asked for ([_save]): the build's for the server's answer, and no
  /// later than [_shown] for a list made from the one on show. A server's
  /// answer comes with [asked]. Not shown when out of date, nor once the
  /// cache no longer serves [epoch]'s session: [_save] asks, and nothing is
  /// awaited between its answer and the state being set.
  Future<void> _show(
    List<PortfolioMembership> list,
    int epoch, {
    int? asked,
  }) async {
    final snapshot = _save(
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

  /// Makes [portfolioId] the current portfolio on this device, while the
  /// cache serves this user ([SwrCache.serves]): while it serves nobody, or
  /// another account, nothing is chosen, and nothing is written on the
  /// device that its wipe removed. It does not know the session a command
  /// asked in, and the same user's next session is served too: a command
  /// that chooses one after its request asks first whether the cache still
  /// serves the session of that request.
  Future<void> select(String portfolioId) async {
    final cache = ref.read(swrCacheProvider);
    if (!cache.serves(userId, cache.epoch)) return;
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
