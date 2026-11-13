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
/// A clear starts a new [epoch]. A write made for an earlier epoch is
/// dropped: its fetch began in a session that has ended since, and what it
/// brings back must not land on the device after the wipe.
final class SwrCache {
  new(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  /// How many times the cache has been cleared. A reader takes it before
  /// it fetches and hands it to [write].
  int get epoch => _epoch;
  int _epoch = 0;

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
  /// when it was saved. With [epoch] (the [SwrCache.epoch] read before the
  /// value was fetched), nothing is stored when the cache was cleared since.
  Future<DateTime> write(
    String userId,
    String query,
    Object? json, {
    int? epoch,
  }) async {
    final savedAt = _clock().toUtc();
    if (epoch != null && epoch != _epoch) return savedAt;
    await _store.write(
      _key(userId, query),
      jsonEncode({'saved_at': savedAt.toIso8601String(), 'value': json}),
    );
    return savedAt;
  }

  /// Deletes every cached entry (all users), when the device is wiped, and
  /// starts a new [epoch] before anything else, so that a write still on
  /// its way is dropped.
  Future<void> clear() async {
    _epoch++;
    for (final key in await _store.keys()) {
      if (key.startsWith(_prefix)) await _store.delete(key);
    }
  }

  /// Deletes [userId]'s entries but the one of [keep]: when a portfolio
  /// left their list (deleted, or they left or were removed), the copies of
  /// its records go. Entries are not kept by portfolio, so every other
  /// list goes with them, and comes back from the server when it is shown.
  Future<void> forgetUser(String userId, {required String keep}) async {
    final prefix = '$_prefix$userId.';
    final kept = _key(userId, keep);
    for (final key in await _store.keys()) {
      if (key.startsWith(prefix) && key != kept) await _store.delete(key);
    }
  }

  /// The cached value first (when there is one), then the fresh value once
  /// [fetch] returns, which is also stored unless the cache was cleared
  /// since this was called (see [epoch]). A failing [fetch] ends the stream
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
