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

  @override
  Stream<Snapshot<T>> build() {
    final userId = ref.watch(currentUserIdProvider);
    _userId = userId;
    if (userId == null) return Stream.error(const SessionExpired());
    return ref
        .watch(swrCacheProvider)
        .watch(
          userId: userId,
          query: query,
          // The cache is read first: by then nobody may show the query
          // any more, and the fetch must not touch a disposed ref.
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
    try {
      await show(await fetch());
    } on AppFailure {
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Shows [value] as the server's latest, and saves it.
  Future<void> show(T value) async {
    final userId = _userId;
    if (userId == null) return;
    final savedAt = await ref
        .read(swrCacheProvider)
        .write(userId, query, encode(value));
    if (!ref.mounted) return;
    state = AsyncData(
      Snapshot(value, savedAt: savedAt, source: SnapshotSource.network),
    );
  }
}
