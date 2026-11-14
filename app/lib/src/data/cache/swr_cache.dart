import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

/// How long a save of the portfolio list waits for each call to the store
/// before it goes on without it, keeping the safe choice: a list it could
/// not read counts as unknown, records it could not forget keep the saved
/// list as it was, and a write that has not answered may still land
/// ([SwrCache.writing]). One call that never answers then holds up no
/// later save.
const storeCallLimit = Duration(seconds: 3);

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
/// Entries are JSON with the time they were saved. An entry that cannot be
/// decoded (an older app version wrote it, or it was tampered with) is
/// deleted and treated as missing.
///
/// A clear starts a new [epoch], and so does forgetting a user's entries
/// ([forgetUser]). A write names the epoch its value was asked for in, and
/// is dropped when what it would save was removed since: its fetch began in
/// a session that has ended, or before a portfolio left the user's list,
/// and what it brings back must not land on the device after the removal.
final class SwrCache {
  /// `callLimit` is [storeCallLimit] but in tests.
  new(
    this._store, {
    DateTime Function()? clock,
    this.callLimit = storeCallLimit,
  }) : _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  /// How long an update run by [serially] waits for each call to the store
  /// ([storeCallLimit]).
  final Duration callLimit;

  /// How many times entries have been removed: the cache cleared, or a
  /// user's entries forgotten. A reader takes it before it fetches and
  /// hands it to [write].
  int get epoch => _epoch;
  int _epoch = 0;

  /// The epoch the last [clear] started.
  int _cleared = 0;

  /// The epoch each [forgetUser] since the last clear started, by user and
  /// by the query it kept.
  final _forgotten = <String, Map<String, int>>{};

  /// The user whose entries alone were kept by [forgetOthers], and the
  /// epoch it started, since the last clear.
  (String, int)? _keptOnly;

  /// The last update of each entry asked for ([serially]), by key, while
  /// one is on its way: it completes when that update has ended.
  final _updates = <String, Completer<void>>{};

  /// How many writes were asked of the store: each write's number.
  int _writes = 0;

  /// The entries of the writes the store has not finished, as written, by
  /// key and by number ([writing]).
  final _writing = <String, Map<int, String>>{};

  /// The number of the newest write of each key the store has finished.
  final _landed = <String, int>{};

  /// The epoch to hand to [write] with a value asked for now by a reader
  /// made in the epoch [madeIn]: the current one, so that a reader made
  /// before a user's entries were forgotten goes on saving what it asks for
  /// after. Once the cache was cleared since [madeIn] it is [madeIn]
  /// itself: the reader was made for a session that has ended, and nothing
  /// it asks for is stored.
  int requestEpoch({required int madeIn}) =>
      madeIn < _cleared ? madeIn : _epoch;

  /// Whether the entry of [query] for [userId] was removed since [epoch]:
  /// the cache was cleared, or the user's entries were forgotten and
  /// [query] was not the one kept.
  bool _removedSince(int epoch, String userId, String query) {
    if (epoch < _cleared) return true;
    if (_keptOnly case (final kept, final at) when kept != userId) {
      if (epoch < at) return true;
    }
    final forgotten = _forgotten[userId];
    if (forgotten == null) return false;
    return forgotten.entries.any(
      (forgot) => forgot.key != query && epoch < forgot.value,
    );
  }

  /// Whether the cache was cleared since [epoch] (a [SwrCache.epoch] read
  /// earlier): the session it was read in has ended, and what was asked
  /// for in it is not kept on the device.
  bool clearedSince(int epoch) => epoch < _cleared;

  /// Now, as the cache stamps what it saves.
  DateTime now() => _clock().toUtc();

  /// Bumped when the stored format changes; older entries are ignored.
  static const _prefix = 'mm.swr.v1.';

  static String _key(String userId, String query) => '$_prefix$userId.$query';

  /// The cached value of [query] for [userId], or null.
  Future<Snapshot<T>?> read<T>(
    String userId,
    String query,
    T Function(Object? json) decode,
  ) async {
    final key = _key(userId, query);
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw);
      if (entry is! Map<String, Object?>) {
        throw const FormatException('not an object');
      }
      final savedAt = DateTime.parse(entry['saved_at']! as String);
      return Snapshot(
        decode(entry['value']),
        savedAt: savedAt,
        source: SnapshotSource.cache,
      );
    } on Object {
      await _store.delete(key);
      return null;
    }
  }

  /// Stores [json] as the latest value of [query] for [userId], and returns
  /// when it was saved. [epoch] is the [SwrCache.epoch] read before the
  /// value was asked for: nothing is stored when the entry was removed
  /// since (the cache was cleared, or the user's entries were forgotten and
  /// [query] was not the one kept), also when that happens while the store
  /// is still writing.
  ///
  /// The entry is deleted as the write lands when it was removed meanwhile,
  /// or when a later write of it landed first (the store may finish two
  /// writes of one key in either order, and would now hold the older
  /// value). A later, wanted value the store finished first goes with it:
  /// the entry is then missing, and is fetched again. The saved portfolio
  /// list counts a missing list as unknown, and forgets the user's other
  /// entries (`PortfoliosController`).
  Future<DateTime> write(
    String userId,
    String query,
    Object? json, {
    required int epoch,
  }) async {
    final savedAt = now();
    if (_removedSince(epoch, userId, query)) return savedAt;
    final key = _key(userId, query);
    final entry = jsonEncode({
      'saved_at': savedAt.toIso8601String(),
      'value': json,
    });
    final number = ++_writes;
    final writing = _writing[key] ??= {};
    writing[number] = entry;
    try {
      await _store.write(key, entry);
    } finally {
      writing.remove(number);
      if (writing.isEmpty && identical(_writing[key], writing)) {
        _writing.remove(key);
      }
    }
    // Removed while the store was writing: the removal may have listed the
    // keys before this one was there.
    if (_removedSince(epoch, userId, query) || (_landed[key] ?? 0) > number) {
      await _store.delete(key);
    } else {
      _landed[key] = number;
    }
    return savedAt;
  }

  /// The values of the writes of [query] for [userId] that the store has
  /// not finished, since the last [clear]: each may still land, also after
  /// a later one.
  List<Object?> writing(String userId, String query) => [
    for (final entry in [...?_writing[_key(userId, query)]?.values])
      (jsonDecode(entry) as Map<String, Object?>)['value'],
  ];

  /// Runs [update] of the entry of [query] for [userId] once every update
  /// of it asked for before has ended: a read of the entry, a choice made
  /// from it and a write must not meet another's, since the store may
  /// finish two writes of one key in either order, and the older could
  /// land last. An update that fails holds up no later one. An update
  /// must end: it waits for each call to the store at most [callLimit],
  /// so that one that never answers holds up no later update, and counts
  /// a write it stopped waiting for as one that may still land
  /// ([writing]).
  ///
  /// After a [clear], the next update does not wait for those asked for
  /// before it: they were for a session that has ended, and what they
  /// write is dropped ([write]), so a store that hangs for one does not
  /// hold up the next session.
  Future<T> serially<T>(
    String userId,
    String query,
    Future<T> Function() update,
  ) async {
    final key = _key(userId, query);
    final before = _updates[key]?.future;
    final turn = Completer<void>();
    // Taken before anything is awaited, so that the updates keep the order
    // they were asked in.
    _updates[key] = turn;
    try {
      await before;
      return await update();
    } finally {
      turn.complete();
      // None asked for since: nothing waits for this one.
      if (identical(_updates[key], turn)) _updates.remove(key);
    }
  }

  /// Deletes every cached entry (all users), when the device is wiped, and
  /// starts a new [epoch] before anything else, so that a write still on
  /// its way is dropped. Throws when an entry could not be deleted, once
  /// the others are ([_deleteWhere]).
  Future<void> clear() async {
    _cleared = ++_epoch;
    _forgotten.clear();
    _updates.clear();
    _writing.clear();
    await _deleteWhere((key) => key.startsWith(_prefix));
  }

  /// Deletes [userId]'s entries but the one of [keep]: when a portfolio
  /// left their list (deleted, or they left or were removed), the copies of
  /// its records go. Entries are not kept by portfolio, so every other
  /// list goes with them, and comes back from the server when it is shown.
  ///
  /// It starts a new [epoch] before anything else: a write of the user's
  /// that was asked for before (a list still loading for the portfolio that
  /// left) is dropped, but one of [keep]. Other users' writes are not.
  /// Throws when an entry could not be deleted, once the others are
  /// ([_deleteWhere]).
  Future<void> forgetUser(String userId, {required String keep}) async {
    (_forgotten[userId] ??= {})[keep] = ++_epoch;
    final prefix = '$_prefix$userId.';
    final kept = _key(userId, keep);
    await _deleteWhere((key) => key.startsWith(prefix) && key != kept);
  }

  /// Whether the store holds an entry of [userId]'s but the one of [keep].
  Future<bool> holdsOthers(String userId, {required String keep}) async {
    final prefix = '$_prefix$userId.';
    final kept = _key(userId, keep);
    return (await _store.keys()).any(
      (key) => key.startsWith(prefix) && key != kept,
    );
  }

  /// Deletes every entry but [userId]'s, when the app starts signed in as
  /// [userId]: what another account's ended session left because its wipe
  /// could not finish (an entry the store refused or did not answer for,
  /// or the app closed meanwhile). It starts a new [epoch] before anything
  /// else, and a write of another user's asked for before is dropped.
  /// Throws when an entry could not be deleted, once the others are
  /// ([_deleteWhere]).
  Future<void> forgetOthers(String userId) async {
    _keptOnly = (userId, ++_epoch);
    final mine = '$_prefix$userId.';
    await _deleteWhere(
      (key) => key.startsWith(_prefix) && !key.startsWith(mine),
    );
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
  /// [fetch] returns, which is also stored unless its entry was removed
  /// since this was called (see [write]). A failing [fetch] ends the stream
  /// with its error after the cached value, so the screen keeps showing the
  /// cached data next to the error.
  Stream<Snapshot<T>> watch<T>({
    required String userId,
    required String query,
    required Future<T> Function() fetch,
    required T Function(Object? json) decode,
    required Object? Function(T value) encode,
  }) => _watch(
    epoch: _epoch,
    userId: userId,
    query: query,
    fetch: fetch,
    decode: decode,
    encode: encode,
  );

  Stream<Snapshot<T>> _watch<T>({
    required int epoch,
    required String userId,
    required String query,
    required Future<T> Function() fetch,
    required T Function(Object? json) decode,
    required Object? Function(T value) encode,
  }) async* {
    final cached = await read(userId, query, decode);
    if (cached != null) yield cached;
    final fresh = await fetch();
    final savedAt = await write(userId, query, encode(fresh), epoch: epoch);
    yield Snapshot(fresh, savedAt: savedAt, source: SnapshotSource.network);
  }
}
