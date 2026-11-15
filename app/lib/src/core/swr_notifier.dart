import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';

/// A query read stale-while-revalidate (see `docs/architecture/app.md`):
/// the saved copy at once, then the server's, saved for next time under the
/// signed-in user, so one account never sees another's.
///
/// A subclass names its [query] (the portfolio and the parameters) and its
/// [scope] (which portfolio its saved copy is of), says how to [fetch] it
/// and how to keep it ([decode], [encode]). Its commands
/// call the repository and then [reload], so the screen shows what the
/// server stored, or [show] what it answered.
abstract class SwrNotifier<T> extends StreamNotifier<Snapshot<T>> {
  /// The cache key: what is read, in which portfolio, with its parameters.
  String get query;

  /// Which portfolio the saved copy is of: named by a parameter
  /// ([InPortfolio]), read from the value ([FromValue]), or not known
  /// ([UnknownPortfolio], kept only until the session's first list of
  /// portfolios). Every query says which; none is the user's own.
  RecordScope<T> get scope;

  /// Reads the value from the server. Called in [build], where it may
  /// `ref.watch` the repository it uses, and by [reload].
  Future<T> fetch();

  /// The value from its cached JSON; throws when the JSON is malformed.
  T decode(Object? json);

  /// The value as JSON [decode] reads back.
  Object? encode(T value);

  String? _userId;

  /// The cache's epoch when the query was built.
  int _epoch = 0;

  /// The cache's epoch the value on show was asked for in ([shownEpoch]).
  int _shown = 0;

  @override
  Stream<Snapshot<T>> build() {
    final userId = ref.watch(currentUserIdProvider);
    final cache = ref.watch(swrCacheProvider);
    final epoch = cache.epoch;
    _userId = userId;
    _epoch = epoch;
    if (userId == null) return Stream.error(const SessionExpired());
    return cache
        .watch(
          userId: userId,
          query: query,
          scope: scope,
          // The cache is read first: by then nobody may show the query any
          // more, and the fetch must not touch a disposed ref.
          fetch: () => ref.mounted ? fetch() : Completer<T>().future,
          decode: decode,
          encode: encode,
        )
        .map((snapshot) {
          // Until it comes, the value of the build before stays on show.
          _shown = epoch;
          return snapshot;
        });
  }

  /// The cache's epoch for the answer to a request made now, to hand to
  /// [show] with it: the epoch the query was built in. A command reads it
  /// before its request: an answer that comes after the device was wiped
  /// is then not saved, and a query built for a session that has ended
  /// saves nothing. (Whether its portfolio is still the user's is asked as
  /// the answer is saved: `SwrCache.write`.)
  int requestEpoch() => _epoch;

  /// The cache's epoch the value on show was asked for in, to hand to
  /// [show] with a value made from that one (a page added to it, a row of
  /// it changed). A command reads it as it reads the value: what was on
  /// show before its saved copy was removed is not saved again with what
  /// came after.
  int get shownEpoch => _shown;

  /// Fetches the value again and shows it, after a command changed it.
  ///
  /// The command has already succeeded, so a failed fetch does not fail it:
  /// the query starts over instead, and the screen says why it is stale.
  Future<void> reload() async {
    // Nobody shows the query any more: there is nothing to refresh.
    if (!ref.mounted) return;
    final epoch = requestEpoch();
    try {
      await show(await fetch(), epoch: epoch);
    } on AppFailure {
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Shows [value] as the server's latest, and saves it unless the device
  /// was wiped since [epoch], or the cache does not keep its portfolio's
  /// entries (`SwrCache.write`).
  ///
  /// [epoch] is the cache's epoch the whole of [value] was asked for in:
  /// [requestEpoch], read before the request, when [value] is the server's
  /// answer; [shownEpoch], read with the value on show, when it is made
  /// from that one.
  Future<void> show(T value, {required int epoch}) async {
    final userId = _userId;
    if (userId == null) return;
    final savedAt = await ref
        .read(swrCacheProvider)
        .write(userId, query, scope, value, encode, epoch: epoch);
    if (!ref.mounted) return;
    _shown = epoch;
    state = AsyncData(
      Snapshot(value, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}
