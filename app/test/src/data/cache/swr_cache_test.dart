import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

import '../../../support/fakes.dart';

void main() {
  final saved = DateTime.utc(2026, 11, 5, 10, 30);
  late MemoryStore store;
  late SwrCache cache;

  setUp(() {
    store = MemoryStore();
    cache = SwrCache(store, clock: () => saved);
  });

  int decodeInt(Object? json) => json! as int;

  test('reads what it wrote, with the time it was saved', () async {
    await cache.write('u1', 'dashboard', {'due': 45000});
    final snapshot = await cache.read(
      'u1',
      'dashboard',
      (json) => json! as Map,
    );
    expect(snapshot!.value, {'due': 45000});
    expect(snapshot.savedAt, saved);
    expect(snapshot.fromCache, isTrue);
  });

  test('entries are per user', () async {
    await cache.write('u1', 'q', 1);
    expect(await cache.read('u2', 'q', decodeInt), isNull);
    expect(store.values.keys.single, 'mm.swr.v1.u1.q');
  });

  test('an undecodable entry is deleted and treated as missing', () async {
    for (final raw in [
      'not json',
      '[1]',
      '{"value": 1}',
      '{"saved_at": "x", "value": 1}',
    ]) {
      store.values['mm.swr.v1.u1.q'] = raw;
      expect(await cache.read('u1', 'q', decodeInt), isNull, reason: raw);
      expect(store.values, isEmpty, reason: raw);
    }
    await cache.write('u1', 'q', 'text');
    expect(await cache.read('u1', 'q', decodeInt), isNull);
    expect(store.values, isEmpty);
  });

  test('clear removes every cache entry and nothing else', () async {
    await cache.write('u1', 'a', 1);
    await cache.write('u2', 'b', 2);
    store.values['mm.settings.locale'] = 'ur';
    await cache.clear();
    expect(store.values, {'mm.settings.locale': 'ur'});
  });

  test('a write for an epoch the cache was cleared since is dropped', () async {
    final epoch = cache.epoch;
    await cache.clear();
    expect(cache.epoch, epoch + 1);
    expect(await cache.write('u1', 'q', 1, epoch: epoch), saved);
    expect(store.values, isEmpty);
    await cache.write('u1', 'q', 2, epoch: cache.epoch);
    // Without an epoch, a write always lands.
    await cache.write('u1', 'r', 3);
    expect(store.values.keys, ['mm.swr.v1.u1.q', 'mm.swr.v1.u1.r']);
  });

  test('a fetch still on its way when the cache is cleared stores nothing, '
      'though the screen still gets its value', () async {
    final fetch = Completer<int>();
    final snapshots = <Snapshot<int>>[];
    final done = cache
        .watch<int>(
          userId: 'u1',
          query: 'tenants',
          fetch: () => fetch.future,
          decode: decodeInt,
          encode: (value) => value,
        )
        .forEach(snapshots.add);
    await pumpEventQueue();
    await cache.clear();
    fetch.complete(5);
    await done;
    expect(store.values, isEmpty);
    expect(snapshots.single.value, 5);
  });

  test(
    'a watch made before a clear but read after it stores nothing',
    () async {
      final stream = cache.watch<int>(
        userId: 'u1',
        query: 'tenants',
        fetch: () async => 6,
        decode: decodeInt,
        encode: (value) => value,
      );
      await cache.clear();
      expect((await stream.toList()).single.value, 6);
      expect(store.values, isEmpty);
    },
  );

  test("forgetUser deletes the user's entries but one", () async {
    await cache.write('u1', 'portfolios', 1);
    await cache.write('u1', 'tenants.p1', 2);
    await cache.write('u12', 'tenants.p1', 3);
    await cache.write('u2', 'x', 4);
    store.values['mm.settings.locale'] = 'ur';
    final epoch = cache.epoch;
    await cache.forgetUser('u1', keep: 'portfolios');
    expect(store.values.keys.toSet(), {
      'mm.swr.v1.u1.portfolios',
      'mm.swr.v1.u12.tenants.p1',
      'mm.swr.v1.u2.x',
      'mm.settings.locale',
    });
    // Not a wipe: what the user's screens fetch next is saved.
    expect(cache.epoch, epoch);
  });

  test(
    'watch yields the cached value, then the fresh one, and stores it',
    () async {
      await cache.write('u1', 'count', 3);
      final later = DateTime.utc(2026, 11, 5, 11);
      final fresh = SwrCache(store, clock: () => later);
      final snapshots = await fresh
          .watch<int>(
            userId: 'u1',
            query: 'count',
            fetch: () async => 4,
            decode: decodeInt,
            encode: (value) => value,
          )
          .toList();
      expect(snapshots.map((s) => (s.value, s.source, s.savedAt)), [
        (3, SnapshotSource.cache, saved),
        (4, SnapshotSource.network, later),
      ]);
      final stored = jsonDecode(store.values['mm.swr.v1.u1.count']!) as Map;
      expect(stored['value'], 4);
    },
  );

  test('watch without a cached value yields only the fresh one', () async {
    final snapshots = await cache
        .watch<int>(
          userId: 'u1',
          query: 'count',
          fetch: () async => 7,
          decode: decodeInt,
          encode: (value) => value,
        )
        .toList();
    expect(snapshots.single.value, 7);
    expect(snapshots.single.fromCache, isFalse);
  });

  test(
    'a failing fetch ends the stream with its error after the cached value',
    () async {
      await cache.write('u1', 'count', 3);
      final values = <int>[];
      Object? error;
      await cache
          .watch<int>(
            userId: 'u1',
            query: 'count',
            fetch: () async => throw StateError('offline'),
            decode: decodeInt,
            encode: (value) => value,
          )
          .handleError((Object e) => error = e)
          .forEach((s) => values.add(s.value));
      expect(values, [3]);
      expect(error, isA<StateError>());
      expect(await cache.read('u1', 'count', decodeInt), isNotNull);
    },
  );
}
