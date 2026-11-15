import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

import '../../../support/fakes.dart';

/// A store whose writes wait for the test while [held] is set, as a
/// platform call still on its way.
final class _SlowStore implements KeyValueStore {
  final inner = MemoryStore();
  Completer<void>? held;

  /// How many writes the cache asked for.
  int writes = 0;

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await held?.future;
    await inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<Set<String>> keys() => inner.keys();
}

/// A store whose deletion of [stuck] throws as it is asked for, not in the
/// future it returns.
final class _ThrowingStore implements KeyValueStore {
  new(this.stuck);

  final inner = MemoryStore();
  final String stuck;

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) =>
      key == stuck ? throw StateError('cannot delete') : inner.delete(key);

  @override
  Future<Set<String>> keys() => inner.keys();
}

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
    await cache.seed('u1', 'dashboard', {'due': 45000});
    final snapshot = await cache.read(
      'u1',
      'dashboard',
      (json) => json! as Map,
    );
    expect(snapshot!.value, {'due': 45000});
    expect(snapshot.savedAt, saved);
    expect(snapshot.fromCache, isTrue);
  });

  test("its time is the clock's, in UTC", () {
    expect(cache.now(), saved);
    final local = SwrCache(store, clock: saved.toLocal);
    expect(local.now().isUtc, isTrue);
    expect(local.now(), saved);
  });

  test('entries are per user', () async {
    await cache.seed('u1', 'q', 1);
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
    await cache.seed('u1', 'q', 'text');
    expect(await cache.read('u1', 'q', decodeInt), isNull);
    expect(store.values, isEmpty);
  });

  test('clear removes every cache entry and nothing else', () async {
    await cache.seed('u1', 'a', 1);
    await cache.seed('u2', 'b', 2);
    store.values['mm.settings.locale'] = 'ur';
    await cache.clear();
    expect(store.values, {'mm.settings.locale': 'ur'});
  });

  group('an entry that cannot be deleted', () {
    setUp(() async {
      // The first one listed is the one that stays.
      await cache.seed('u1', 'a', 1);
      await cache.seed('u1', 'b', 2);
      await cache.seed('u1', 'portfolios', 3);
      await cache.seed('u2', 'c', 4);
    });

    test('leaves a clear to delete the others, and then fails it', () async {
      store.undeletable.add('mm.swr.v1.u1.a');
      await expectLater(cache.clear(), throwsStateError);
      expect(store.values.keys, ['mm.swr.v1.u1.a']);
    });

    test("leaves forgetUser to delete the user's others, and then fails "
        'it', () async {
      store.undeletable.add('mm.swr.v1.u1.a');
      await expectLater(
        cache.forgetUser('u1', keep: {'portfolios'}),
        throwsStateError,
      );
      expect(store.values.keys, [
        'mm.swr.v1.u1.a',
        'mm.swr.v1.u1.portfolios',
        'mm.swr.v1.u2.c',
      ]);
    });

    test('because its deletion never answers holds up no other', () async {
      store.silent.add('mm.swr.v1.u1.a');
      var ended = false;
      unawaited(cache.clear().whenComplete(() => ended = true));
      await pumpEventQueue();
      expect(store.values.keys, ['mm.swr.v1.u1.a']);
      expect(ended, isFalse);
    });

    test('because the store throws as it is asked leaves the others to '
        'go', () async {
      final throwing = _ThrowingStore('mm.swr.v1.u1.a');
      final over = SwrCache(throwing);
      await over.seed('u1', 'a', 1);
      await over.seed('u1', 'b', 2);
      await expectLater(over.clear(), throwsStateError);
      expect(throwing.inner.values.keys, ['mm.swr.v1.u1.a']);
    });
  });

  test('a write for an epoch the cache was cleared since is dropped', () async {
    final epoch = cache.epoch;
    await cache.clear();
    expect(cache.epoch, epoch + 1);
    expect(await cache.write('u1', 'q', 1, epoch: epoch), saved);
    expect(store.values, isEmpty);
    await cache.write('u1', 'q', 2, epoch: cache.epoch);
    expect(store.values.keys, ['mm.swr.v1.u1.q']);
  });

  test('a reader made before a clear names its own epoch from then on, and '
      "one made before a forget the cache's", () async {
    final made = cache.epoch;
    expect(cache.requestEpoch(madeIn: made), made);
    await cache.forgetUser('u1', keep: {'portfolios'});
    expect(cache.epoch, made + 1);
    expect(cache.requestEpoch(madeIn: made), cache.epoch);
    await cache.clear();
    // Made for a session that has ended: what it asks for is not stored.
    expect(cache.requestEpoch(madeIn: made), made);
    expect(cache.requestEpoch(madeIn: cache.epoch), cache.epoch);
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

  group('forgetUser', () {
    test("deletes the user's entries but one", () async {
      await cache.seed('u1', 'portfolios', 1);
      await cache.seed('u1', 'tenants.p1', 2);
      await cache.seed('u12', 'tenants.p1', 3);
      await cache.seed('u2', 'x', 4);
      store.values['mm.settings.locale'] = 'ur';
      await cache.forgetUser('u1', keep: {'portfolios'});
      expect(store.values.keys.toSet(), {
        'mm.swr.v1.u1.portfolios',
        'mm.swr.v1.u12.tenants.p1',
        'mm.swr.v1.u2.x',
        'mm.settings.locale',
      });
    });

    test("drops what the user's screens asked for before it, and nothing "
        'else', () async {
      final before = cache.epoch;
      await cache.forgetUser('u1', keep: {'portfolios'});
      await cache.write('u1', 'tenants.p2', 1, epoch: before);
      expect(store.values, isEmpty);
      // The list that was kept, and another user's, are not its to drop.
      await cache.write('u1', 'portfolios', 2, epoch: before);
      await cache.write('u2', 'tenants.p2', 3, epoch: before);
      // Not a wipe: what the user's screens ask for next is saved.
      await cache.write('u1', 'tenants.p1', 4, epoch: cache.epoch);
      expect(store.values.keys.toSet(), {
        'mm.swr.v1.u1.portfolios',
        'mm.swr.v1.u2.tenants.p2',
        'mm.swr.v1.u1.tenants.p1',
      });
    });

    test('a fetch begun before it stores nothing for the forgotten '
        'entries, though the screen still gets its value', () async {
      final fetch = Completer<int>();
      final snapshots = <Snapshot<int>>[];
      final done = cache
          .watch<int>(
            userId: 'u1',
            query: 'tenants.p2',
            fetch: () => fetch.future,
            decode: decodeInt,
            encode: (value) => value,
          )
          .forEach(snapshots.add);
      await pumpEventQueue();
      // The portfolio p2 left u1's list while the request was on its way.
      await cache.forgetUser('u1', keep: {'portfolios'});
      fetch.complete(5);
      await done;
      expect(store.values, isEmpty);
      expect(snapshots.single.value, 5);
    });

    test('twice, keeping another query each time, drops what either '
        'forgot', () async {
      final first = cache.epoch;
      await cache.forgetUser('u1', keep: {'a'});
      final second = cache.epoch;
      await cache.forgetUser('u1', keep: {'b'});
      // Asked for before both: each was forgotten by the one that kept
      // the other.
      await cache.write('u1', 'a', 1, epoch: first);
      await cache.write('u1', 'b', 1, epoch: first);
      // Asked for between them: only the second forgot `a`.
      await cache.write('u1', 'a', 2, epoch: second);
      expect(store.values, isEmpty);
      await cache.write('u1', 'b', 2, epoch: second);
      expect(store.values.keys, ['mm.swr.v1.u1.b']);
    });

    test('keeps every query of the set, and drops what it did not '
        'keep', () async {
      final before = cache.epoch;
      await cache.seed('u1', 'portfolios', 1);
      await cache.seed('u1', 'profile', 2);
      await cache.seed('u1', 'tenants.p1', 3);
      await cache.forgetUser('u1', keep: {'portfolios', 'profile'});
      expect(store.values.keys.toSet(), {
        'mm.swr.v1.u1.portfolios',
        'mm.swr.v1.u1.profile',
      });
      await cache.write('u1', 'profile', 4, epoch: before);
      await cache.write('u1', 'tenants.p1', 5, epoch: before);
      expect((await cache.read('u1', 'profile', decodeInt))!.value, 4);
      expect(store.values.keys, isNot(contains('mm.swr.v1.u1.tenants.p1')));
    });

    test('a later one that keeps more does not undo an earlier one', () async {
      final first = cache.epoch;
      await cache.forgetUser('u1', keep: {'portfolios'});
      final second = cache.epoch;
      await cache.forgetUser('u1', keep: {'portfolios', 'profile'});
      await cache.write('u1', 'profile', 1, epoch: first);
      expect(store.values, isEmpty);
      await cache.write('u1', 'profile', 2, epoch: second);
      expect((await cache.read('u1', 'profile', decodeInt))!.value, 2);
    });

    test('a later one that keeps less drops all an earlier one did', () async {
      final first = cache.epoch;
      await cache.forgetUser('u1', keep: {'portfolios', 'profile'});
      await cache.forgetUser('u1', keep: {'portfolios'});
      await cache.write('u1', 'tenants.p1', 1, epoch: first);
      await cache.write('u1', 'profile', 2, epoch: first);
      expect(store.values, isEmpty);
      await cache.write('u1', 'portfolios', 3, epoch: first);
      expect(store.values.keys, ['mm.swr.v1.u1.portfolios']);
    });

    test('a clear after it drops the kept query too', () async {
      final before = cache.epoch;
      await cache.forgetUser('u1', keep: {'portfolios'});
      await cache.clear();
      await cache.write('u1', 'portfolios', 1, epoch: before);
      expect(store.values, isEmpty);
      await cache.write('u1', 'tenants.p1', 2, epoch: cache.epoch);
      expect(store.values.keys, ['mm.swr.v1.u1.tenants.p1']);
    });
  });

  group('serially', () {
    test('runs the updates of one entry one after another, in the order '
        'asked; other entries do not wait', () async {
      final cache = SwrCache(MemoryStore());
      final first = Completer<void>();
      final log = <String>[];
      final a = cache.serially('u', 'q', () async {
        log.add('a starts');
        await first.future;
        log.add('a ends');
        return 1;
      });
      final b = cache.serially('u', 'q', () async {
        log.add('b');
        return 2;
      });
      final other = cache.serially('u', 'other', () async {
        log.add('other');
        return 3;
      });
      final otherUser = cache.serially('v', 'q', () async {
        log.add('other user');
        return 4;
      });
      await pumpEventQueue();
      expect(log, ['a starts', 'other', 'other user']);
      first.complete();
      expect(await Future.wait([a, b, other, otherUser]), [1, 2, 3, 4]);
      expect(log, ['a starts', 'other', 'other user', 'a ends', 'b']);
    });

    test('an update that fails holds up none after it', () async {
      final cache = SwrCache(MemoryStore());
      final failing = cache.serially<int>(
        'u',
        'q',
        () async => throw StateError('store'),
      );
      final next = cache.serially('u', 'q', () async => 2);
      await expectLater(failing, throwsStateError);
      expect(await next, 2);
    });

    test('after a clear, the next update does not wait for one asked for '
        'before it', () async {
      final cache = SwrCache(MemoryStore());
      final stuck = cache.serially('u', 'q', () => Completer<int>().future);
      await cache.clear();
      expect(await cache.serially('u', 'q', () async => 2), 2);
      unawaited(stuck);
    });
  });

  group('a write the store has not finished', () {
    late _SlowStore slow;
    late SwrCache slowCache;

    setUp(() {
      slow = _SlowStore()..held = Completer();
      slowCache = SwrCache(slow, clock: () => saved);
    });

    test('when the cache is cleared is deleted as it lands', () async {
      final writing = slowCache.write('u1', 'q', 1, epoch: slowCache.epoch);
      // The clear lists the keys before this one is there.
      await slowCache.clear();
      slow.held!.complete();
      expect(await writing, saved);
      expect(slow.inner.values, isEmpty);
    });

    test("when the user's entries are forgotten is deleted as it lands, "
        'but the kept one', () async {
      final epoch = slowCache.epoch;
      final writes = [
        slowCache.write('u1', 'tenants.p2', 1, epoch: epoch),
        slowCache.write('u1', 'portfolios', 2, epoch: epoch),
        slowCache.write('u2', 'tenants.p2', 3, epoch: epoch),
      ];
      await slowCache.forgetUser('u1', keep: {'portfolios'});
      slow.held!.complete();
      await Future.wait(writes);
      expect(slow.inner.values.keys.toSet(), {
        'mm.swr.v1.u1.portfolios',
        'mm.swr.v1.u2.tenants.p2',
      });
    });

    test('otherwise stays', () async {
      final writing = slowCache.write('u1', 'q', 1, epoch: slowCache.epoch);
      slow.held!.complete();
      await writing;
      expect(slow.inner.values.keys, ['mm.swr.v1.u1.q']);
    });

    test('never stays where a later write saved the entry meanwhile, which '
        'may go with it: the store takes the two in either order', () async {
      final late = slowCache.write('u1', 'q', 1, epoch: slowCache.epoch);
      await slowCache.forgetUser('u1', keep: {'portfolios'});
      final wanted = slowCache.write('u1', 'q', 2, epoch: slowCache.epoch);
      slow.held!.complete();
      await Future.wait([late, wanted]);
      final left = await slowCache.read('u1', 'q', decodeInt);
      expect(left?.value, isNot(1));
    });
  });

  group('the writes of an entry the store has not finished', () {
    test('are told until they land, as written', () async {
      store.holding.add('mm.swr.v1.u1.q');
      final first = cache.write('u1', 'q', [1], epoch: cache.epoch);
      final second = cache.write('u1', 'q', [2], epoch: cache.epoch);
      expect(cache.writing('u1', 'q'), [
        [1],
        [2],
      ]);
      expect(cache.writing('u1', 'other'), isEmpty);
      expect(cache.writing('u2', 'q'), isEmpty);
      store.finishHeldWritesNewestFirst();
      await Future.wait([first, second]);
      expect(cache.writing('u1', 'q'), isEmpty);
    });

    test('nor one that failed', () async {
      store.writeFailure = Exception('full');
      await expectLater(
        cache.write('u1', 'q', 1, epoch: cache.epoch),
        throwsException,
      );
      expect(cache.writing('u1', 'q'), isEmpty);
    });

    test('nor, after a clear, those of the ended session', () async {
      store.holding.add('mm.swr.v1.u1.q');
      final writing = cache.write('u1', 'q', 1, epoch: cache.epoch);
      await cache.clear();
      expect(cache.writing('u1', 'q'), isEmpty);
      store.finishHeldWritesNewestFirst();
      await writing;
      expect(store.values, isEmpty);
    });

    test('delete the entry when the older lands last: the store would hold '
        'it over the newer', () async {
      store.holding.add('mm.swr.v1.u1.q');
      final older = cache.write('u1', 'q', 1, epoch: cache.epoch);
      final newer = cache.write('u1', 'q', 2, epoch: cache.epoch);
      store.finishHeldWritesNewestFirst();
      await Future.wait([older, newer]);
      expect(store.values, isEmpty);
    });

    test('keep the newer when they land in order', () async {
      store.holding.add('mm.swr.v1.u1.q');
      final older = cache.write('u1', 'q', 1, epoch: cache.epoch);
      final newer = cache.write('u1', 'q', 2, epoch: cache.epoch);
      // The older lands first.
      store.holding.clear();
      final held = store.heldWrites;
      expect(held, 2);
      store.finishHeldWritesOldestFirst();
      await Future.wait([older, newer]);
      expect((await cache.read('u1', 'q', decodeInt))!.value, 2);
    });
  });

  test('clearedSince tells a session that has ended', () async {
    final before = cache.epoch;
    await cache.forgetUser('u1', keep: {'portfolios'});
    expect(cache.clearedSince(before), isFalse);
    await cache.clear();
    expect(cache.clearedSince(before), isTrue);
    expect(cache.clearedSince(cache.epoch), isFalse);
  });

  test('waits for the store at most storeCallLimit, but in tests', () {
    expect(cache.callLimit, storeCallLimit);
    expect(storeCallLimit, const Duration(seconds: 3));
  });

  group('forgetOthers', () {
    test("deletes every user's entries but one's, and nothing else", () async {
      await cache.seed('u1', 'tenants', [1]);
      await cache.seed('u2', 'tenants', [2]);
      await cache.seed('u3', 'profile', 3);
      await store.write('other', '1');
      await cache.forgetOthers('u1');
      expect(store.values.keys.toSet(), {'mm.swr.v1.u1.tenants', 'other'});
    });

    test("drops another user's write asked for before it, not the kept "
        "user's, nor one asked for after it", () async {
      final epoch = cache.epoch;
      await cache.forgetOthers('u1');
      await cache.write('u2', 'tenants', 2, epoch: epoch);
      await cache.write('u1', 'tenants', 1, epoch: epoch);
      await cache.write('u3', 'tenants', 3, epoch: cache.epoch);
      expect(store.values.keys.toSet(), {
        'mm.swr.v1.u1.tenants',
        'mm.swr.v1.u3.tenants',
      });
    });

    test('is forgotten by a clear', () async {
      await cache.forgetOthers('u1');
      await cache.clear();
      final epoch = cache.epoch;
      await cache.write('u2', 'tenants', 2, epoch: epoch);
      expect(store.values.keys, ['mm.swr.v1.u2.tenants']);
    });

    test('fails once the others are gone when one cannot be deleted', () async {
      await cache.seed('u2', 'tenants', [2]);
      await cache.seed('u3', 'tenants', [3]);
      store.undeletable.add('mm.swr.v1.u2.tenants');
      await expectLater(cache.forgetOthers('u1'), throwsStateError);
      expect(store.values.keys, ['mm.swr.v1.u2.tenants']);
    });
  });

  test('a write whose entry was removed since its epoch is never handed to '
      'the store', () async {
    // A store that would never finish it.
    final slow = _SlowStore()..held = Completer();
    final slowCache = SwrCache(slow, clock: () => saved);
    final before = slowCache.epoch;
    await slowCache.clear();
    expect(await slowCache.write('u1', 'q', 1, epoch: before), saved);
    final between = slowCache.epoch;
    await slowCache.forgetUser('u1', keep: {'portfolios'});
    expect(await slowCache.write('u1', 'tenants.p1', 1, epoch: between), saved);
    expect(slow.writes, 0);
  });

  test(
    'watch yields the cached value, then the fresh one, and stores it',
    () async {
      await cache.seed('u1', 'count', 3);
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
      await cache.seed('u1', 'count', 3);
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

  group('a write the store fails', () {
    test('deletes the entry and leaves it unsettled until a write asked '
        'after the failure lands', () async {
      await cache.seed('u1', 'count', 1);
      expect(cache.unsettled('u1', 'count'), isFalse);
      store.writeFailure = Exception('full');
      await expectLater(cache.seed('u1', 'count', 2), throwsException);
      store.writeFailure = null;
      await pumpEventQueue();
      expect(await cache.read('u1', 'count', decodeInt), isNull);
      expect(cache.unsettled('u1', 'count'), isTrue);
      expect(cache.unsettled('u1', 'other'), isFalse);
      expect(cache.unsettled('u2', 'count'), isFalse);
      await cache.seed('u1', 'count', 3);
      expect(cache.unsettled('u1', 'count'), isFalse);
      expect((await cache.read('u1', 'count', decodeInt))!.value, 3);
    });

    test('a write asked before the failure that lands after it does not '
        'settle the entry', () async {
      store.holding.add('mm.swr.v1.u1.count');
      final early = cache.seed('u1', 'count', 1);
      await pumpEventQueue();
      store.writeFailure = Exception('full');
      await expectLater(cache.seed('u1', 'count', 2), throwsException);
      store
        ..writeFailure = null
        ..holding.clear()
        ..finishHeldWritesOldestFirst();
      await early;
      expect((await cache.read('u1', 'count', decodeInt))!.value, 1);
      expect(cache.unsettled('u1', 'count'), isTrue);
    });

    test('whose deletion fails or never answers still throws its own '
        'error', () async {
      store.writeFailure = Exception('full');
      store.undeletable.add('mm.swr.v1.u1.a');
      store.silent.add('mm.swr.v1.u1.b');
      await expectLater(cache.seed('u1', 'a', 1), throwsException);
      await expectLater(cache.seed('u1', 'b', 1), throwsException);
      expect(cache.unsettled('u1', 'a'), isTrue);
      expect(cache.unsettled('u1', 'b'), isTrue);
    });
  });

  group('strayed', () {
    const key = 'mm.swr.v1.u1.tenants.p1';

    /// A write of u1's tenants.p1 asked before a forget that does not keep
    /// it, landing after, whose deletion the store [refuses] or hangs on.
    Future<void> strand({bool refuses = true}) async {
      store.holding.add(key);
      final late = cache.seed('u1', 'tenants.p1', 1);
      await pumpEventQueue();
      await cache.forgetUser('u1', keep: {'portfolios'});
      (refuses ? store.undeletable : store.silent).add(key);
      store
        ..holding.clear()
        ..finishHeldWritesOldestFirst();
      if (refuses) await expectLater(late, throwsStateError);
      await pumpEventQueue();
      expect(store.values.keys, [key]);
    }

    test('tells a write that landed after a removal and stayed, whether '
        'its deletion was refused or never answers', () async {
      expect(cache.strayed('u1'), isFalse);
      await strand();
      expect(cache.strayed('u1'), isTrue);
      expect(cache.strayed('u2'), isFalse);
      expect(cache.strayed('u1', except: {'tenants.p1'}), isFalse);
      cache = SwrCache(store = MemoryStore(), clock: () => saved);
      await strand(refuses: false);
      expect(cache.strayed('u1'), isTrue);
    });

    test(
      'tells an older write that landed after a later one and stayed',
      () async {
        store.holding.add('mm.swr.v1.u1.portfolios');
        final older = cache.seed('u1', 'portfolios', 1);
        final newer = cache.seed('u1', 'portfolios', 2);
        await pumpEventQueue();
        store
          ..undeletable.add('mm.swr.v1.u1.portfolios')
          ..holding.clear()
          ..finishHeldWritesNewestFirst();
        await newer;
        await expectLater(older, throwsStateError);
        expect((await cache.read('u1', 'portfolios', decodeInt))!.value, 1);
        expect(cache.strayed('u1'), isTrue);
        expect(cache.strayed('u1', except: {'portfolios'}), isFalse);
        // A later write replaces it.
        await cache.seed('u1', 'portfolios', 3);
        expect(cache.strayed('u1'), isFalse);
      },
    );

    test('is not set when the deletion that follows ends', () async {
      store.holding.add(key);
      final late = cache.seed('u1', 'tenants.p1', 1);
      await pumpEventQueue();
      await cache.forgetUser('u1', keep: {'portfolios'});
      store
        ..holding.clear()
        ..finishHeldWritesOldestFirst();
      await late;
      expect(store.values, isEmpty);
      expect(cache.strayed('u1'), isFalse);
    });

    test(
      'ends when a forget deletes it, but not when that deletion fails',
      () async {
        await strand();
        await expectLater(
          cache.forgetUser('u1', keep: {'portfolios'}),
          throwsStateError,
        );
        expect(cache.strayed('u1'), isTrue);
        // A forget that keeps it leaves it a stray.
        store.undeletable.clear();
        await cache.forgetUser('u1', keep: {'tenants.p1'});
        expect(cache.strayed('u1'), isTrue);
        await cache.forgetUser('u1', keep: {'portfolios'});
        expect(store.values, isEmpty);
        expect(cache.strayed('u1'), isFalse);
      },
    );

    test(
      'ends when a clear deletes it, or the store no longer lists it',
      () async {
        await strand();
        store.undeletable.clear();
        await cache.clear();
        expect(cache.strayed('u1'), isFalse);
        await strand();
        store.values.clear();
        await cache.forgetOthers('u2');
        expect(cache.strayed('u1'), isFalse);
      },
    );
  });

  test('claim takes the answer to the newest request of an entry, whatever '
      'the order the answers come in', () {
    final first = cache.ask();
    final second = cache.ask();
    expect(second, greaterThan(first));
    expect(cache.claim('u1', 'portfolios', second), isTrue);
    expect(cache.claim('u1', 'portfolios', first), isFalse);
    expect(cache.claim('u1', 'portfolios', second), isTrue);
    expect(cache.claim('u2', 'portfolios', first), isTrue);
    expect(cache.claim('u1', 'other', first), isTrue);
  });
}
