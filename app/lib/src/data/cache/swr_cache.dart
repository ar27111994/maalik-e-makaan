import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:maalik_e_makaan/src/data/cache/cache_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:maalik_e_makaan/src/data/cache/cache_scope.dart';

/// The small slice of a key-value store the cache needs, so tests can use an
/// in-memory one.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Set<String>> keys();
}

/// [KeyValueStore] over the platform preferences (localStorage on the web).
final class PreferencesStore implements KeyValueStore {
  new(this._preferences);

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);

  @override
  Future<Set<String>> keys() => _preferences.getKeys();
}

/// Where a [Snapshot] came from.
enum SnapshotSource { cache, network }

/// A value with its age: screens show cached data at once and say how old
/// it is while the fresh copy loads, or when the network is unavailable.
final class Snapshot<T> {
  const new(this.value, {required this.savedAt, required this.source});

  final T value;

  /// When the value was fetched from the server.
  final DateTime savedAt;

  final SnapshotSource source;

  bool get fromCache => source == SnapshotSource.cache;
}

/// Stale-while-revalidate storage for query results, namespaced per user so
/// one account never sees another's cached data, and cleared when a
/// session ends (`DeviceDataWipe`).
///
/// Every entry's key says what it holds ([CacheScope]): the user's own
/// (the portfolio list, the profile, the residence), a portfolio's, or one
/// whose portfolio is not known. The cache keeps, in memory, the
/// portfolios the user is in, as the newest list of portfolios this session
/// applied ([applyPortfolios]), and keeps nothing else: a portfolio's entry
/// while the user is in it, an entry of unknown portfolio only until that
/// first list. Each list applied removes what it does not name, from the
/// keys alone ([prune]), and a write is checked again as it lands
/// ([write]).
///
/// Entries are JSON with the time they were saved. An entry that cannot be
/// decoded (it was tampered with, or the format changed) is deleted and
/// treated as missing.
///
/// A clear starts a new [epoch]. A write names the epoch its value was
/// asked for in, and is dropped when the cache was cleared since: its
/// fetch began in a session that has ended.
final class SwrCache {
  new(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  /// How many times the cache was cleared. A reader takes it before it
  /// fetches and hands it to [write].
  int get epoch => _epoch;
  int _epoch = 0;

  /// The epoch the last [clear] started.
  int _cleared = 0;

  /// The portfolios each user is in, as the newest list applied since the
  /// last clear said; a user missing has had none applied.
  final _members = <String, Set<String>>{};

  /// How many requests of the portfolio list were numbered ([ask]).
  int _asked = 0;

  /// The number of the newest list applied, by user. Not reset by a clear:
  /// [ask] counts up for the whole run.
  final _claimed = <String, int>{};

  /// How many writes were asked of the cache: each write's number.
  int _writes = 0;

  /// The number of the newest write of each entry (a user and a query,
  /// under whatever tag) that landed, or that the cache chose not to keep.
  final _newest = <String, int>{};

  /// Whether the cache was cleared since [epoch] (a [SwrCache.epoch] read
  /// earlier): the session it was read in has ended, and what was asked
  /// for in it is not kept on the device.
  bool clearedSince(int epoch) => epoch < _cleared;

  /// Now, as the cache stamps what it saves.
  DateTime now() => _clock().toUtc();

  /// Every version's entries start with it.
  static const _root = 'mm.swr.';

  /// Bumped when the stored format changes. Older entries are not read,
  /// and go at a start signed in, at a list of portfolios, or at a wipe.
  static const _prefix = 'mm.swr.v2.';

  /// The key of [query]'s entry for [userId] under [tag].
  @visibleForTesting
  static String keyOf(String userId, EntryTag tag, String query) =>
      '$_prefix$userId.${tag.text}.$query';

  /// The user, tag and query of [key]; null when it is not a key of this
  /// version. The user runs to the first dot, the tag to the next, and the
  /// query is the rest, whatever it holds.
  static ({String userId, EntryTag tag, String query})? _parse(String key) {
    if (!key.startsWith(_prefix)) return null;
    final rest = key.substring(_prefix.length);
    final user = rest.indexOf('.');
    if (user <= 0) return null;
    final tag = rest.indexOf('.', user + 1);
    if (tag < 0) return null;
    return (
      userId: rest.substring(0, user),
      tag: EntryTag.parse(rest.substring(user + 1, tag)),
      query: rest.substring(tag + 1),
    );
  }

  /// The entry [query] of [userId]'s, under any tag: the writes of one
  /// value are ordered by it.
  static String _entry(String userId, EntryTag tag, String query) =>
      '${tag is OwnTag ? 'own' : 'record'}.$userId.$query';

  /// Throws [ArgumentError] for a user id that cannot stand in a key, or
  /// an own scope asked for another query than its own: mistakes in the
  /// app.
  static void _check<T>(String userId, String query, CacheScope<T> scope) {
    if (!EntryTag.isPlainId(userId)) {
      throw ArgumentError.value(userId, 'userId', 'not an id');
    }
    if (scope is OwnScope<T> && scope.query != query) {
      throw ArgumentError.value(query, 'query', 'not ${scope.query}');
    }
  }

  /// Whether an entry of [userId]'s under [tag], whose value names the
  /// portfolios [names], is kept: always until a list was applied; then a
  /// portfolio's while the user is in it, the user's own while it names
  /// no portfolio they are not in, and none of unknown portfolio.
  bool _keeps(String userId, EntryTag tag, Set<String> names) {
    final members = _members[userId];
    if (members == null) return true;
    return switch (tag) {
      OwnTag() => members.containsAll(names),
      PortfolioTag(:final portfolioId) => members.contains(portfolioId),
      UnknownTag() => false,
    };
  }

  /// Asks for [key]'s deletion, and waits for none of it.
  void _forget(String key) => unawaited(
    Future.sync(() => _store.delete(key)).then((_) {}, onError: (_) {}),
  );

  /// The keys [userId]'s entry of [query] may be under, but the user's
  /// own: while a list is applied, those of the portfolios the user is in
  /// (and of unknown portfolio when [unknownToo]); before, what the store
  /// lists. Null when the store could not list its keys.
  Future<List<String>?> _keysOf(
    String userId,
    String query, {
    bool unknownToo = false,
  }) async {
    final members = _members[userId];
    if (members != null) {
      return [
        for (final id in members) keyOf(userId, PortfolioTag(id), query),
        if (unknownToo) keyOf(userId, const UnknownTag(), query),
      ];
    }
    final Set<String> keys;
    try {
      keys = await _store.keys();
    } on Object {
      return null;
    }
    return [
      for (final key in keys)
        if (_ofEntry(key, userId, query)) key,
    ];
  }

  /// Whether [key] is an entry of [userId]'s of [query], but the user's
  /// own.
  static bool _ofEntry(String key, String userId, String query) {
    final parsed = _parse(key);
    return parsed != null &&
        parsed.userId == userId &&
        parsed.query == query &&
        parsed.tag is! OwnTag;
  }

  /// The cached value of [query] for [userId], or null. While a list of
  /// portfolios is applied, an entry the cache would not keep counts as
  /// missing, and its deletion is asked for. An entry whose portfolio is
  /// known only from its value ([FromValue]) is found under whichever tag
  /// it has, the newest first.
  Future<Snapshot<T>?> read<T>(
    String userId,
    String query,
    CacheScope<T> scope,
    T Function(Object? json) decode,
  ) async {
    _check(userId, query, scope);
    final known = scope.knownTag;
    final keys = known != null
        ? [keyOf(userId, known, query)]
        : await _keysOf(userId, query);
    if (keys == null) return null;
    final found = await Future.wait([
      for (final key in keys) _readKey(key, userId, scope, decode),
    ]);
    Snapshot<T>? newest;
    for (final snapshot in found) {
      if (snapshot == null) continue;
      if (newest == null || snapshot.savedAt.isAfter(newest.savedAt)) {
        newest = snapshot;
      }
    }
    return newest;
  }

  Future<Snapshot<T>?> _readKey<T>(
    String key,
    String userId,
    CacheScope<T> scope,
    T Function(Object? json) decode,
  ) async {
    final tag = _parse(key)!.tag;
    final raw = await _store.read(key);
    if (raw == null) return null;
    final Snapshot<T> snapshot;
    try {
      final entry = jsonDecode(raw);
      if (entry is! Map<String, Object?>) {
        throw const FormatException('not an object');
      }
      final savedAt = DateTime.parse(entry['saved_at']! as String);
      snapshot = Snapshot(
        decode(entry['value']),
        savedAt: savedAt,
        source: SnapshotSource.cache,
      );
    } on Object {
      await _store.delete(key);
      return null;
    }
    // Asked once the value is read: a list may have been applied while the
    // store read, and the portfolio list's names are in its value.
    final names = scope is OwnScope<T>
        ? scope.portfoliosOf(snapshot.value)
        : const <String>{};
    if (!_keeps(userId, tag, names)) {
      _forget(key);
      return null;
    }
    return snapshot;
  }

  /// Stores [value] as the latest of [query] for [userId], under the tag
  /// [scope] gives it, and returns when it was saved ([savedAt], else now).
  /// [epoch] is the [SwrCache.epoch] read before the value was asked for:
  /// nothing is stored when the cache was cleared since, nor when the cache
  /// would not keep the entry ([applyPortfolios]).
  ///
  /// It is checked again once the store has written it, and deleted when
  /// either holds then, or when a later write of the entry landed first
  /// (the store may finish two writes in either order, and would now hold
  /// the older value). A later, wanted value the store finished first goes
  /// with it: the entry is then missing, and is fetched again. When it
  /// lands, the entry's copies under another tag are deleted (an entry
  /// whose portfolio comes from its value moves from unknown to its
  /// portfolio, or back, as the value changes); when the cache does not
  /// keep it, all are. A write the store fails throws, and its deletion is
  /// asked for then.
  Future<DateTime> write<T>(
    String userId,
    String query,
    CacheScope<T> scope,
    T value,
    Object? Function(T value) encode, {
    required int epoch,
    DateTime? savedAt,
  }) async {
    final at = savedAt ?? now();
    _check(userId, query, scope);
    if (clearedSince(epoch)) return at;
    final tag = scope.tagOf(value);
    final names = scope is OwnScope<T>
        ? scope.portfoliosOf(value)
        : const <String>{};
    final entry = _entry(userId, tag, query);
    final number = ++_writes;
    if (!_keeps(userId, tag, names)) {
      _newest[entry] = number;
      if (scope is FromValue<T>) _dropCopies(userId, query, entry, number);
      return at;
    }
    final key = keyOf(userId, tag, query);
    final json = jsonEncode({
      'saved_at': at.toIso8601String(),
      'value': encode(value),
    });
    try {
      await _store.write(key, json);
    } on Object {
      // The store may hold any value written, or none: the entry goes, also
      // for a later start of the app. Not waited for: one that never
      // answers must not hide this failure.
      _forget(key);
      rethrow;
    }
    // Checked again: the session may have ended, or a list been applied,
    // while the store was writing, and the removal may have listed the
    // keys before this one was there.
    if (clearedSince(epoch) ||
        !_keeps(userId, tag, names) ||
        (_newest[entry] ?? 0) > number) {
      await _store.delete(key);
    } else {
      _newest[entry] = number;
      if (scope is FromValue<T>) {
        _dropCopies(userId, query, entry, number, except: key);
      }
    }
    return at;
  }

  /// Deletes the copies of [userId]'s entry of [query] but [except], as
  /// long as the write [number] is still its newest, and waits for none of
  /// it.
  void _dropCopies(
    String userId,
    String query,
    String entry,
    int number, {
    String? except,
  }) => unawaited(
    Future.sync(() async {
      final keys = await _keysOf(userId, query, unknownToo: true);
      await Future.wait([
        for (final key in [...?keys])
          if (key != except && _newest[entry] == number)
            Future.sync(() => _store.delete(key)),
      ]);
    }).then((_) {}, onError: (_) {}),
  );

  /// A number for a request of the portfolio list made now: later requests
  /// have higher numbers ([applyPortfolios]).
  int ask() => ++_asked;

  /// Applies the server's list of [userId]'s portfolios, [ids], the answer
  /// to request [asked] ([ask]) made in [epoch]: from now on the cache
  /// keeps a portfolio's entries only while it is in the list, and none of
  /// unknown portfolio. Then it starts removing what the list does not name
  /// ([prune]) and waits for none of it.
  ///
  /// False, and nothing changes, when the answer is out of date: the
  /// answer to a request asked later was applied first, or the cache was
  /// cleared since [epoch] (an answer of a session that has ended).
  bool applyPortfolios(
    String userId,
    Iterable<String> ids, {
    required int asked,
    required int epoch,
  }) {
    if (clearedSince(epoch)) return false;
    if ((_claimed[userId] ?? 0) > asked) return false;
    _claimed[userId] = asked;
    _members[userId] = {...ids};
    _pruneLater(userId);
    return true;
  }

  /// Notes that [userId] is in the portfolio [id] they just created (asked
  /// for in [epoch]), when a list is applied: its entries are kept until
  /// the next list.
  void addPortfolio(String userId, String id, {required int epoch}) {
    if (clearedSince(epoch)) return;
    _members[userId]?.add(id);
  }

  /// Notes that [userId] is no longer in the portfolio [id] they just
  /// deleted (asked for in [epoch]), when a list is applied, and starts
  /// removing its entries.
  void removePortfolio(String userId, String id, {required int epoch}) {
    if (clearedSince(epoch)) return;
    final members = _members[userId];
    if (members == null || !members.remove(id)) return;
    _pruneLater(userId);
  }

  /// The portfolios [userId] is in, as the cache keeps them; null until a
  /// list was applied in this session.
  Set<String>? portfoliosOf(String userId) {
    final members = _members[userId];
    return members == null ? null : Set.unmodifiable(members);
  }

  void _pruneLater(String userId) =>
      unawaited(prune(userId).then((_) {}, onError: (_) {}));

  /// Deletes, from the keys the store lists, every entry the cache does not
  /// keep for [userId]: a portfolio's the user is not in, every one of
  /// unknown portfolio, every key of another user or of an older version.
  /// The user's own stay. Nothing saved is read, so it can run again at
  /// any time: what a deletion that failed or never answered left is found
  /// again by the next. Nothing happens before a list is applied. Throws
  /// when an entry could not be deleted, once the others are
  /// ([_deleteWhere]).
  Future<void> prune(String userId) async {
    if (_members[userId] == null) return;
    final mine = '$_prefix$userId.';
    await _deleteWhere((key) {
      if (!key.startsWith(_root)) return false;
      if (!key.startsWith(mine)) return true;
      final parsed = _parse(key);
      if (parsed == null) return true;
      // A clear meanwhile deletes it all.
      if (_members[userId] == null) return false;
      return !_keeps(userId, parsed.tag, const {});
    });
  }

  /// Deletes every cached entry (all users, every version), when the device
  /// is wiped, and starts a new [epoch] before anything else, so that a
  /// write still on its way is dropped. The portfolios the cache knew go
  /// with it. Throws when an entry could not be deleted, once the others
  /// are ([_deleteWhere]).
  Future<void> clear() async {
    _cleared = ++_epoch;
    _members.clear();
    await _deleteWhere((key) => key.startsWith(_root));
  }

  /// Deletes every entry but [userId]'s of this version, when the app
  /// starts signed in as [userId]: what another account's ended session
  /// left because its wipe could not finish (an entry the store refused or
  /// did not answer for, or the app closed meanwhile), and every entry of
  /// an older version, which names no portfolio. It runs before any query
  /// is read. Throws when an entry could not be deleted, once the others
  /// are ([_deleteWhere]).
  Future<void> forgetOthers(String userId) async {
    final mine = '$_prefix$userId.';
    await _deleteWhere((key) => key.startsWith(_root) && !key.startsWith(mine));
  }

  /// Deletes the stored keys [doomed] picks, each on its own and all asked
  /// for at once: one that cannot be deleted, or whose deletion never
  /// answers, holds up no other. It ends when they all have, with the
  /// first failure if there was one.
  Future<void> _deleteWhere(bool Function(String key) doomed) async {
    final keys = await _store.keys();
    await Future.wait([
      for (final key in keys)
        if (doomed(key)) Future.sync(() => _store.delete(key)),
    ]);
  }

  /// The cached value first (when there is one), then the fresh value once
  /// [fetch] returns, which is also stored unless the cache was cleared
  /// since this was called, or does not keep it (see [write]). A failing
  /// [fetch] ends the stream with its error after the cached value, so the
  /// screen keeps showing the cached data next to the error.
  Stream<Snapshot<T>> watch<T>({
    required String userId,
    required String query,
    required CacheScope<T> scope,
    required Future<T> Function() fetch,
    required T Function(Object? json) decode,
    required Object? Function(T value) encode,
  }) => _watch(
    epoch: _epoch,
    userId: userId,
    query: query,
    scope: scope,
    fetch: fetch,
    decode: decode,
    encode: encode,
  );

  Stream<Snapshot<T>> _watch<T>({
    required int epoch,
    required String userId,
    required String query,
    required CacheScope<T> scope,
    required Future<T> Function() fetch,
    required T Function(Object? json) decode,
    required Object? Function(T value) encode,
  }) async* {
    final cached = await read(userId, query, scope, decode);
    if (cached != null) yield cached;
    final fresh = await fetch();
    final savedAt = await write(
      userId,
      query,
      scope,
      fresh,
      encode,
      epoch: epoch,
    );
    yield Snapshot(fresh, savedAt: savedAt, source: SnapshotSource.network);
  }
}
