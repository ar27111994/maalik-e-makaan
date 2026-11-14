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
/// A subclass names its [query] (the portfolio and the parameters), says
/// how to [fetch] it and how to keep it ([decode], [encode]). Its commands
/// call the repository and then [reload], so the screen shows what the
/// server stored.
abstract class SwrNotifier<T> extends StreamNotifier<Snapshot<T>> {
  /// The cache key: what is read, in which portfolio, with its parameters.
  String get query;

  /// Reads the value from the server. Called in [build], where it may
  /// `ref.watch` the repository it uses, and by [reload].
  Future<T> fetch();

  /// The value from its cached JSON; throws when the JSON is malformed.
  T decode(Object? json);

  /// The value as JSON [decode] reads back.
  Object? encode(T value);

  String? _userId;

  /// The cache's epoch when the query was built: the earliest a value it
  /// shows can have been asked for. A value shown after the device was
  /// wiped since (the session ended) is not saved.
  int _epoch = 0;

  @override
  Stream<Snapshot<T>> build() {
    final userId = ref.watch(currentUserIdProvider);
    final cache = ref.watch(swrCacheProvider);
    _userId = userId;
    _epoch = cache.epoch;
    if (userId == null) return Stream.error(const SessionExpired());
    return cache.watch(
      userId: userId,
      query: query,
      // The cache is read first: by then nobody may show the query any
      // more, and the fetch must not touch a disposed ref.
      fetch: () => ref.mounted ? fetch() : Completer<T>().future,
      decode: decode,
      encode: encode,
    );
  }

  /// Fetches the value again and shows it, after a command changed it.
  ///
  /// The command has already succeeded, so a failed fetch does not fail it:
  /// the query starts over instead, and the screen says why it is stale.
  Future<void> reload() async {
    // Nobody shows the query any more: there is nothing to refresh.
    if (!ref.mounted) return;
    // Read before the fetch: a query built before a portfolio left the
    // user's list goes on saving what it fetches after.
    final epoch = ref.read(swrCacheProvider).requestEpoch(madeIn: _epoch);
    try {
      await show(await fetch(), epoch: epoch);
    } on AppFailure {
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Shows [value] as the server's latest, and saves it unless its saved
  /// copy was removed since it was asked for: the device was wiped, or a
  /// portfolio left the user's list (`SwrCache.write`).
  ///
  /// [epoch] is the cache's epoch read before [value] was asked for
  /// (`SwrCache.requestEpoch`). Without it the value counts as asked for
  /// when the query was built, the earliest it can have been: after a
  /// portfolio left the user's list it is shown but not saved, until the
  /// query is read again ([reload]) or built anew.
  Future<void> show(T value, {int? epoch}) async {
    final userId = _userId;
    if (userId == null) return;
    final savedAt = await ref
        .read(swrCacheProvider)
        .write(userId, query, encode(value), epoch: epoch ?? _epoch);
    if (!ref.mounted) return;
    state = AsyncData(
      Snapshot(value, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}
