import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
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

/// A store whose reads wait for the test while [held] is set, once they
/// have read the value: what the cache does with it after the wait is what
/// a test sees.
final class _SlowReads implements KeyValueStore {
  final inner = MemoryStore();
  Completer<void>? held;

  /// The keys whose reads wait; every key's while it is empty.
  final only = <String>{};

  @override
  Future<String?> read(String key) async {
    final value = await inner.read(key);
    if (only.isEmpty || only.contains(key)) await held?.future;
    return value;
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<Set<String>> keys() => inner.keys();
}

/// A list of rows, each of a portfolio or of none, as a feature's list.
typedef _Rows = List<String?>;

/// A query whose portfolio comes from its rows.
const _fromRows = FromValue<_Rows>(samePortfolio);

const _a = 'pA';
const _b = 'pB';
const _user = 'u1';

Object? _same(Object? value) => value;
int _decodeInt(Object? json) => json! as int;
_Rows _decodeRows(Object? json) => [
  for (final id in json! as List) id as String?,
];

void main() {
  final saved = DateTime.utc(2026, 11, 5, 10, 30);
  late MemoryStore store;
  late SwrCache cache;

  setUp(() {
    store = MemoryStore();
    cache = SwrCache(store, clock: () => saved)..serve(_user);
  });

  String key(EntryTag tag, String query, {String user = _user}) =>
      SwrCache.keyOf(user, tag, query);

  /// Writes [value] of [query] in [portfolio], for the current epoch, of
  /// the user the cache serves; of another user, puts it in the store as
  /// an earlier session of theirs left it.
  Future<DateTime?> put(
    String query,
    int value, {
    String portfolio = _a,
    String user = _user,
  }) => cache.serves(user, cache.epoch)
      ? cache.write(
          user,
          query,
          InPortfolio<int>(portfolio),
          value,
          _same,
          epoch: cache.epoch,
        )
      : cache.seed(user, query, value, portfolio: portfolio);

  Future<int?> get(String query, {String portfolio = _a}) async =>
      (await cache.read(
        _user,
        query,
        InPortfolio<int>(portfolio),
        _decodeInt,
        epoch: cache.epoch,
      ))?.value;

  group('reading and writing', () {
    test('reads what it wrote, with the time it was saved', () async {
      final at = await put('dashboard', 45000);
      expect(at, saved);
      final entry = await cache.read(
        _user,
        'dashboard',
        InPortfolio<int>(_a),
        _decodeInt,
        epoch: cache.epoch,
      );
      expect(entry!.value, 45000);
      expect(entry.savedAt, saved);
      expect(entry.fromCache, isTrue);
      expect(entry.source, SnapshotSource.cache);
    });

    test("its time is the clock's, in UTC, or the one handed over", () async {
      final local = SwrCache(store, clock: () => DateTime(2026, 11, 5, 15))
        ..serve(_user);
      expect(local.now().isUtc, isTrue);
      final at = DateTime.utc(2026);
      expect(
        await local.write(
          _user,
          'x',
          InPortfolio<int>(_a),
          1,
          _same,
          epoch: local.epoch,
          savedAt: at,
        ),
        at,
      );
      expect(
        (jsonDecode(store.values.values.single) as Map)['saved_at'],
        startsWith('2026-01-01'),
      );
    });

    test('entries are per user', () async {
      await put('dashboard', 1, user: 'u2');
      expect(await get('dashboard'), isNull);
    });

    test('an undecodable entry is deleted and treated as missing', () async {
      for (final raw in ['not json', '[1]', '{"value":1}']) {
        store.values[key(const PortfolioTag(_a), 'dashboard')] = raw;
        expect(await get('dashboard'), isNull, reason: raw);
        expect(store.values, isEmpty, reason: raw);
      }
    });

    test(
      'a value its decoder refuses is deleted and treated as missing',
      () async {
        await put('dashboard', 1);
        final read = await cache.read<int>(
          _user,
          'dashboard',
          InPortfolio<int>(_a),
          (_) => throw const FormatException('changed'),
          epoch: cache.epoch,
        );
        expect(read, isNull);
        expect(store.values, isEmpty);
      },
    );
  });

  group('the key', () {
    test('names the user, what the entry holds and the query', () async {
      await put('tenants.$_a.active.', 1);
      await cache.write(
        _user,
        'profile',
        OwnScope.profile<int>(),
        2,
        _same,
        epoch: cache.epoch,
      );
      await cache.write(
        _user,
        'tenant.t1',
        _fromRows,
        [null],
        _same,
        epoch: cache.epoch,
      );
      expect(store.values.keys.toSet(), {
        'mm.swr.v2.u1.p:pA.tenants.pA.active.',
        'mm.swr.v2.u1.own.profile',
        'mm.swr.v2.u1.unknown.tenant.t1',
      });
    });

    test('keeps a query with dots, spaces and Urdu whole', () async {
      const query = 'tenants.pA.active.علی رضا. 0300.#';
      await put(query, 7);
      expect(store.values.keys.single, 'mm.swr.v2.u1.p:pA.$query');
      expect(await get(query), 7);
      // And it is pruned by its tag alone.
      await cache.answer(_user, [_b]);
      expect(store.values, isEmpty);
    });

    test(
      'refuses a user or a portfolio id that cannot stand in a key',
      () async {
        for (final bad in ['', 'a.b']) {
          expect(
            () => cache.write(
              bad,
              'x',
              InPortfolio<int>(_a),
              1,
              _same,
              epoch: cache.epoch,
            ),
            throwsArgumentError,
          );
          expect(() => InPortfolio<int>(bad), throwsArgumentError);
          expect(
            () => cache.read(
              bad,
              'x',
              InPortfolio<int>(_a),
              _decodeInt,
              epoch: cache.epoch,
            ),
            throwsArgumentError,
          );
        }
      },
    );

    test('an own scope serves its own query only', () async {
      expect(
        () => cache.write(
          _user,
          'tenants',
          OwnScope.profile<int>(),
          1,
          _same,
          epoch: cache.epoch,
        ),
        throwsArgumentError,
      );
      expect(OwnScope.profile<int>().query, 'profile');
      expect(OwnScope.residence<int>().query, 'residence');
      expect(OwnScope.portfolioList<int>((_) => const []).query, 'portfolios');
    });

    test('a portfolio read from a value that cannot stand in a key is '
        'unknown', () {
      expect(_fromRows.tagOf(['a.b']), const UnknownTag());
      expect(_fromRows.tagOf(['']), const UnknownTag());
      expect(_fromRows.tagOf([_a, _a]), const PortfolioTag(_a));
      expect(_fromRows.knownTag, isNull);
      // Made at run time, as a scope a getter builds.
      // ignore: prefer_const_constructors
      expect(UnknownPortfolio<int>().tagOf(1), const UnknownTag());
      expect(const UnknownPortfolio<int>().knownTag, const UnknownTag());
      expect(InPortfolio<int>(_a).tagOf(1), const PortfolioTag(_a));
      expect(OwnScope.profile<int>().tagOf(1), const OwnTag());
    });

    test('tags read back from their text, and anything else is unknown', () {
      for (final tag in const [OwnTag(), PortfolioTag(_a), UnknownTag()]) {
        expect(EntryTag.parse(tag.text), tag);
        expect(EntryTag.parse(tag.text).hashCode, tag.hashCode);
      }
      for (final text in ['', 'p:', 'p:a.b', 'mine', 'OWN']) {
        expect(EntryTag.parse(text), const UnknownTag(), reason: text);
      }
      expect(const PortfolioTag(_a), isNot(const PortfolioTag(_b)));
    });

    test('samePortfolio names the one portfolio all name, else none', () {
      expect(samePortfolio(const []), isNull);
      expect(samePortfolio(const [_a]), _a);
      expect(samePortfolio(const [_a, _a]), _a);
      expect(samePortfolio(const [_a, _b]), isNull);
      expect(samePortfolio(const [_a, null]), isNull);
      expect(samePortfolio(const [null, _a]), isNull);
    });
  });

  group('the wipe', () {
    test('clear removes every cache entry, of every version and user, and '
        'nothing else', () async {
      await put('dashboard', 1);
      await put('dashboard', 1, user: 'u2');
      store.values['mm.swr.v1.u1.tenants'] = '{}';
      store.values['other'] = 'x';
      final before = cache.epoch;
      await cache.clear();
      expect(store.values.keys, ['other']);
      expect(cache.epoch, before + 1);
      // Nobody owns the epoch it started.
      expect(cache.serves(_user, before), isFalse);
      expect(cache.serves(_user, cache.epoch), isFalse);
    });

    test('forgets the portfolios the user is in', () async {
      await cache.answer(_user, [_a]);
      expect(cache.portfoliosOf(_user), {_a});
      await cache.clear();
      expect(cache.portfoliosOf(_user), isNull);
    });

    test('a clear whose listing answers late deletes what was saved since '
        'too: nothing of the ended session may stay', () async {
      await put('a', 1);
      // The store is slow to list its keys: the clear waits for it.
      final listing = store.keysHeld = Completer();
      final clearing = cache.clear();
      await pumpEventQueue();
      expect(store.values, hasLength(1));
      // The wipe gives up waiting; another account signs in and saves.
      store.keysHeld = null;
      await put('a', 1, user: 'u2');
      // The listing answers: it cannot tell what was there when it was
      // asked, so everything it names goes, and the new entry is fetched
      // again.
      listing.complete();
      await clearing;
      expect(store.values, isEmpty);
    });

    test(
      'a write for an epoch the cache was cleared since is dropped',
      () async {
        final epoch = cache.epoch;
        await cache.clear();
        await cache.write(
          _user,
          'x',
          InPortfolio<int>(_a),
          1,
          _same,
          epoch: epoch,
        );
        expect(store.values, isEmpty);
      },
    );

    test('a write for an epoch the cache was cleared since is never written, '
        'even of an own entry, by a store that keeps it and never answers', () {
      final profile = OwnScope.profile<int>();
      final epoch = cache.epoch;
      store.landingSilently.add(key(profile.tagOf(1), 'profile'));
      return Future(() async {
        await cache.clear();
        unawaited(
          cache.write(_user, 'profile', profile, 1, _same, epoch: epoch),
        );
        await pumpEventQueue();
        expect(store.values, isEmpty);
      });
    });

    test('a write still on its way when the cache is cleared is deleted as '
        'it lands', () async {
      final slow = _SlowStore()..held = Completer();
      final cache = SwrCache(slow)..serve(_user);
      final writing = cache.write(
        _user,
        'x',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      await cache.clear();
      slow.held!.complete();
      await writing;
      expect(slow.inner.values, isEmpty);
    });

    group('an entry that cannot be deleted', () {
      test('leaves a clear to delete the others, and then fails it', () async {
        await put('a', 1);
        await put('b', 2);
        store.undeletable.add(key(const PortfolioTag(_a), 'a'));
        await expectLater(cache.clear(), throwsStateError);
        expect(store.values.keys, [key(const PortfolioTag(_a), 'a')]);
      });

      test('because its deletion never answers holds up no other', () async {
        await put('a', 1);
        await put('b', 2);
        store.silent.add(key(const PortfolioTag(_a), 'a'));
        unawaited(cache.clear());
        await pumpEventQueue();
        expect(store.values.keys, [key(const PortfolioTag(_a), 'a')]);
      });

      test(
        'because the store throws as it is asked leaves the others to go',
        () async {
          final stuck = key(const PortfolioTag(_a), 'a');
          final throwing = _ThrowingStore(stuck);
          final cache = SwrCache(throwing)..serve(_user);
          for (final query in ['a', 'b']) {
            await cache.write(
              _user,
              query,
              InPortfolio<int>(_a),
              1,
              _same,
              epoch: cache.epoch,
            );
          }
          await expectLater(cache.clear(), throwsStateError);
          expect(throwing.inner.values.keys, [stuck]);
        },
      );
    });
  });

  group('forgetOthers', () {
    test("deletes every entry but the user's of this version, and nothing "
        'else', () async {
      await put('a', 1);
      await put('a', 1, user: 'u2');
      store.values['mm.swr.v1.u1.tenants'] = '{}';
      store.values['mm.swr.v1.u2.tenants'] = '{}';
      store.values['other'] = 'x';
      final epoch = cache.epoch;
      await cache.forgetOthers(_user);
      expect(store.values.keys.toSet(), {
        key(const PortfolioTag(_a), 'a'),
        'other',
      });
      // It starts no epoch: nothing of the user's was removed.
      expect(cache.epoch, epoch);
    });

    test('fails once the others are gone when one cannot be deleted', () async {
      await put('a', 1, user: 'u2');
      await put('b', 1, user: 'u2');
      store.undeletable.add(key(const PortfolioTag(_a), 'a', user: 'u2'));
      await expectLater(cache.forgetOthers(_user), throwsStateError);
      expect(store.values, hasLength(1));
    });

    test('one begun before a clear deletes nothing the next account saved '
        'since', () async {
      await put('a', 1);
      // The listing is slow: the start's removal waits for it.
      final listing = store.keysHeld = Completer();
      final forgetting = cache.forgetOthers(_user);
      await pumpEventQueue();
      // The session ends; another account signs in and saves two entries.
      store.keysHeld = null;
      await cache.clear();
      cache.serve('u2');
      await cache.write(
        'u2',
        'profile',
        OwnScope.profile<int>(),
        1,
        _same,
        epoch: cache.epoch,
      );
      await put('a', 1, user: 'u2');
      // The old removal's listing answers now, and names the new entries.
      listing.complete();
      await forgetting;
      await pumpEventQueue();
      expect(store.values.keys.toSet(), {
        key(const OwnTag(), 'profile', user: 'u2'),
        key(const PortfolioTag(_a), 'a', user: 'u2'),
      });
    });
  });

  group('the keep rule', () {
    test(
      'before a list is applied, every entry is kept, unknown too',
      () async {
        await put('a', 1);
        await put('b', 2, portfolio: _b);
        await cache.write(
          _user,
          'u',
          _fromRows,
          const <String?>[],
          _same,
          epoch: cache.epoch,
        );
        expect(store.values, hasLength(3));
        expect(cache.portfoliosOf(_user), isNull);
      },
    );

    test("once one is applied, a portfolio's entries are kept only while "
        'the user is in it, and none of unknown portfolio', () async {
      await cache.answer(_user, [_a]);
      await put('a', 1);
      await put('b', 2, portfolio: _b);
      await cache.write(
        _user,
        'u',
        _fromRows,
        const <String?>[],
        _same,
        epoch: cache.epoch,
      );
      expect(store.values.keys, [key(const PortfolioTag(_a), 'a')]);
    });

    test("the user's own are kept, but a list that names a portfolio the "
        'user is not in', () async {
      final list = OwnScope.portfolioList<List<String>>((ids) => ids);
      await cache.answer(_user, [_a]);
      await cache.write(
        _user,
        'portfolios',
        list,
        [_a, _b],
        _same,
        epoch: cache.epoch,
      );
      expect(store.values, isEmpty);
      await cache.write(
        _user,
        'portfolios',
        list,
        [_a],
        _same,
        epoch: cache.epoch,
      );
      await cache.write(
        _user,
        'profile',
        OwnScope.profile<int>(),
        1,
        _same,
        epoch: cache.epoch,
      );
      expect(store.values, hasLength(2));
      expect(list.portfoliosOf([_a, _b]), {_a, _b});
      expect(OwnScope.profile<int>().portfoliosOf(1), isEmpty);
    });

    test('a write is checked again as it lands: one of a portfolio that '
        'left meanwhile is deleted then', () async {
      final slow = _SlowStore()..held = Completer();
      final cache = SwrCache(slow)..serve(_user);
      final writing = cache.write(
        _user,
        'x',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      await cache.answer(_user, [_b]);
      slow.held!.complete();
      await writing;
      expect(slow.inner.values, isEmpty);
    });

    test('a write that lands while its portfolio stays is kept', () async {
      final slow = _SlowStore()..held = Completer();
      final cache = SwrCache(slow)..serve(_user);
      final writing = cache.write(
        _user,
        'x',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      await cache.answer(_user, [_a]);
      slow.held!.complete();
      await writing;
      expect(slow.inner.values, hasLength(1));
    });

    test('a write that never answers although the store keeps it is removed '
        'by the next list save', () async {
      final stuck = key(const PortfolioTag(_a), 'x');
      store.landingSilently.add(stuck);
      unawaited(put('x', 1));
      await pumpEventQueue();
      expect(store.values.keys, [stuck]);
      await cache.answer(_user, [_b]);
      expect(store.values, isEmpty);
    });
  });

  group('applyPortfolios', () {
    test('applies only the newest-asked answer', () async {
      final first = cache.ask();
      final second = cache.ask();
      expect(second, greaterThan(first));
      expect(
        cache.applyPortfolios(_user, [_a], asked: second, epoch: cache.epoch),
        isTrue,
      );
      expect(
        cache.applyPortfolios(
          _user,
          [_a, _b],
          asked: first,
          epoch: cache.epoch,
        ),
        isFalse,
      );
      expect(cache.portfoliosOf(_user), {_a});
      // The same answer again is no older.
      expect(
        cache.applyPortfolios(_user, [_b], asked: second, epoch: cache.epoch),
        isTrue,
      );
      // Per epoch: the next owner's first answer applies, however old.
      cache.serve('u2');
      expect(
        cache.applyPortfolios('u2', [_a], asked: first, epoch: cache.epoch),
        isTrue,
      );
    });

    test('refuses an answer of a session that has ended', () async {
      final asked = cache.ask();
      final epoch = cache.epoch;
      await cache.clear();
      expect(
        cache.applyPortfolios(_user, [_a], asked: asked, epoch: epoch),
        isFalse,
      );
      expect(cache.portfoliosOf(_user), isNull);
    });

    test('keeps the numbers across a wipe: a request asked before it does '
        'not outrank one asked after', () async {
      final before = cache.ask();
      await cache.clear();
      cache.serve(_user);
      final after = cache.ask();
      expect(
        cache.applyPortfolios(_user, [_a], asked: after, epoch: cache.epoch),
        isTrue,
      );
      expect(
        cache.applyPortfolios(_user, [_b], asked: before, epoch: cache.epoch),
        isFalse,
      );
    });

    test('portfoliosOf cannot be changed from outside', () async {
      await cache.answer(_user, [_a]);
      expect(() => cache.portfoliosOf(_user)!.add(_b), throwsUnsupportedError);
    });
  });

  group('addPortfolio and removePortfolio', () {
    test('change nothing before a list is applied', () async {
      await put('a', 1);
      cache
        ..addPortfolio(_user, _b, epoch: cache.epoch)
        ..removePortfolio(_user, _a, epoch: cache.epoch);
      await pumpEventQueue();
      expect(cache.portfoliosOf(_user), isNull);
      expect(store.values, hasLength(1));
    });

    test('add a created portfolio, and remove a deleted one with its '
        'entries', () async {
      await put('a', 1);
      await put('b', 1, portfolio: _b);
      await cache.answer(_user, [_a]);
      expect(store.values, hasLength(1));
      cache.addPortfolio(_user, _b, epoch: cache.epoch);
      await put('b', 2, portfolio: _b);
      expect(store.values, hasLength(2));
      cache.removePortfolio(_user, _a, epoch: cache.epoch);
      await pumpEventQueue();
      expect(cache.portfoliosOf(_user), {_b});
      expect(store.values.keys, [key(const PortfolioTag(_b), 'b')]);
      // One it does not hold changes nothing.
      cache.removePortfolio(_user, 'pC', epoch: cache.epoch);
      expect(cache.portfoliosOf(_user), {_b});
    });

    test('change nothing for a session that has ended', () async {
      final epoch = cache.epoch;
      await cache.clear();
      cache.serve(_user);
      await cache.answer(_user, [_a]);
      cache
        ..addPortfolio(_user, _b, epoch: epoch)
        ..removePortfolio(_user, _a, epoch: epoch);
      expect(cache.portfoliosOf(_user), {_a});
    });
  });

  group('prune', () {
    test(
      'removes, from the keys alone, every entry the list does not keep, '
      "another user's and the old format's, and keeps the user's own",
      () async {
        await put('a', 1);
        await put('b', 1, portfolio: _b);
        await cache.write(
          _user,
          'u',
          _fromRows,
          const <String?>[],
          _same,
          epoch: cache.epoch,
        );
        await cache.write(
          _user,
          'profile',
          OwnScope.profile<int>(),
          1,
          _same,
          epoch: cache.epoch,
        );
        await put('a', 1, user: 'u2');
        store.values
          ..['mm.swr.v1.u1.tenants'] = '{}'
          ..['mm.swr.v2.u1.nodot'] = '{}'
          ..['mm.swr.v2.u1.p:pA'] = '{}'
          ..['other'] = 'x';
        // No value is read.
        store.hangingReads = true;
        await cache.answer(_user, [_a]);
        expect(store.values.keys.toSet(), {
          key(const PortfolioTag(_a), 'a'),
          key(const OwnTag(), 'profile'),
          'other',
        });
      },
    );

    test('does nothing before a list is applied', () async {
      await put('a', 1);
      await cache.prune(_user);
      expect(store.values, hasLength(1));
    });

    test('can run again: what a refused, a hung or a failed listing left '
        'goes at the next', () async {
      await put('a', 1);
      await put('b', 1);
      final stuck = key(const PortfolioTag(_a), 'a');
      store.undeletable.add(stuck);
      await cache.answer(_user, [_b]).catchError((_) {});
      expect(store.values.keys, [stuck]);
      store
        ..undeletable.clear()
        ..keysFailure = Exception('no listing');
      await expectLater(cache.prune(_user), throwsException);
      expect(store.values.keys, [stuck]);
      store.keysFailure = null;
      await cache.prune(_user);
      expect(store.values, isEmpty);
    });

    test(
      'a removal the list starts holds up nothing when the store hangs',
      () async {
        await put('a', 1);
        store.hangingKeys = true;
        expect(
          cache.applyPortfolios(
            _user,
            [_b],
            asked: cache.ask(),
            epoch: cache.epoch,
          ),
          isTrue,
        );
        await pumpEventQueue();
        expect(cache.portfoliosOf(_user), {_b});
        // The entry is not shown while it waits to go.
        expect(await get('a'), isNull);
      },
    );

    test('a clear while it lists leaves the deleting to the clear', () async {
      final slowKeys = Completer<void>();
      final hold = _HeldKeys(slowKeys.future);
      final cache = SwrCache(hold)..serve(_user);
      await cache.write(
        _user,
        'a',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      cache.applyPortfolios(
        _user,
        [_a],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      final pruning = cache.prune(_user);
      await pumpEventQueue();
      // The clear wipes S and lists too; both answer now.
      final clearing = cache.clear();
      slowKeys.complete();
      await pruning;
      await clearing;
      expect(hold.inner.values, isEmpty);
    });

    test('one begun before a clear deletes nothing the next account saved '
        'since', () async {
      await put('a', 1);
      cache.applyPortfolios(
        _user,
        [_a],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      // The listing is slow: the removal waits for it.
      final listing = store.keysHeld = Completer();
      final pruning = cache.prune(_user);
      await pumpEventQueue();
      // The session ends; another account signs in and saves two entries.
      store.keysHeld = null;
      await cache.clear();
      cache.serve('u2');
      await cache.write(
        'u2',
        'profile',
        OwnScope.profile<int>(),
        1,
        _same,
        epoch: cache.epoch,
      );
      await put('a', 1, user: 'u2');
      // The old removal's listing answers now, and names the new entries.
      listing.complete();
      await pruning;
      await pumpEventQueue();
      expect(store.values.keys.toSet(), {
        key(const OwnTag(), 'profile', user: 'u2'),
        key(const PortfolioTag(_a), 'a', user: 'u2'),
      });
    });
  });

  group('a read while a list is applied', () {
    test('never shows an entry the list does not keep, and asks for its '
        'deletion', () async {
      await put('a', 1);
      await put('b', 2, portfolio: _b);
      final stuck = key(const PortfolioTag(_b), 'b');
      store.undeletable.add(stuck);
      await cache.answer(_user, [_a]).catchError((_) {});
      expect(store.values.keys, contains(stuck));
      // Its own screen, still built for it, finds nothing.
      expect(await get('b', portfolio: _b), isNull);
      store.undeletable.clear();
      expect(await get('b', portfolio: _b), isNull);
      await pumpEventQueue();
      expect(store.values.keys, [key(const PortfolioTag(_a), 'a')]);
      expect(await get('a'), 1);
    });

    test('nor one of unknown portfolio', () async {
      await cache.write(
        _user,
        'u',
        const UnknownPortfolio<int>(),
        1,
        _same,
        epoch: cache.epoch,
      );
      expect(
        (await cache.read(
          _user,
          'u',
          const UnknownPortfolio<int>(),
          _decodeInt,
          epoch: cache.epoch,
        ))?.value,
        1,
      );
      store.silent.add(key(const UnknownTag(), 'u'));
      unawaited(cache.answer(_user, [_a]));
      await pumpEventQueue();
      expect(
        await cache.read(
          _user,
          'u',
          const UnknownPortfolio<int>(),
          _decodeInt,
          epoch: cache.epoch,
        ),
        isNull,
      );
    });

    test(
      'nor a saved list of portfolios that names one the user left',
      () async {
        final list = OwnScope.portfolioList<List<String>>((ids) => ids);
        List<String> decode(Object? json) => [...(json! as List).cast()];
        await cache.write(
          _user,
          'portfolios',
          list,
          [_a, _b],
          _same,
          epoch: cache.epoch,
        );
        expect(
          (await cache.read(
            _user,
            'portfolios',
            list,
            decode,
            epoch: cache.epoch,
          ))!.value,
          [_a, _b],
        );
        await cache.answer(_user, [_a]);
        expect(
          await cache.read(
            _user,
            'portfolios',
            list,
            decode,
            epoch: cache.epoch,
          ),
          isNull,
        );
        await pumpEventQueue();
        expect(store.values, isEmpty);
      },
    );

    test('nor one whose portfolio left while the store read it', () async {
      final slow = _SlowReads();
      final cache = SwrCache(slow)..serve(_user);
      await cache.write(
        _user,
        'a',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      slow.held = Completer();
      final reading = cache.read(
        _user,
        'a',
        InPortfolio<int>(_a),
        _decodeInt,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      cache.applyPortfolios(
        _user,
        [_b],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      // The removal the list started has deleted it, after the store read
      // it: the check comes after the read.
      expect(slow.inner.values, isEmpty);
      slow.held!.complete();
      expect(await reading, isNull);
    });

    test('nor, of a query whose portfolio comes from its value, a copy read '
        'before a list that drops it, while another copy was still being '
        'read', () async {
      final slow = _SlowReads();
      final cache = SwrCache(slow)..serve(_user);
      final unknown = SwrCache.keyOf(_user, const UnknownTag(), 'units.h1');
      slow.inner.values[SwrCache.keyOf(
        _user,
        const PortfolioTag(_a),
        'units.h1',
      )] = jsonEncode({
        'saved_at': '2026-11-02T00:00:00Z',
        'value': [_a],
      });
      slow.inner.values[unknown] = jsonEncode({
        'saved_at': '2026-11-01T00:00:00Z',
        'value': <String>[],
      });
      slow
        ..only.add(unknown)
        ..held = Completer();
      final reading = cache.read(
        _user,
        'units.h1',
        _fromRows,
        _decodeRows,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      // The copy in pA has been read; the list then drops pA.
      cache.applyPortfolios(
        _user,
        [_b],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      slow.held!.complete();
      expect(await reading, isNull);
    });
  });

  group('a query whose portfolio comes from its value', () {
    Future<_Rows?> rows(String query) async => (await cache.read(
      _user,
      query,
      _fromRows,
      _decodeRows,
      epoch: cache.epoch,
    ))?.value;

    Future<void> putRows(String query, _Rows value, {int? epoch}) =>
        cache.write(
          _user,
          query,
          _fromRows,
          value,
          _same,
          epoch: epoch ?? cache.epoch,
        );

    test('is found by its query under whatever tag it has', () async {
      await putRows('units.h1', [_a]);
      expect(store.values.keys, [key(const PortfolioTag(_a), 'units.h1')]);
      expect(await rows('units.h1'), [_a]);
      expect(await rows('units.h2'), isNull);
    });

    test(
      'before a list, the newest copy shows when there are several',
      () async {
        store.values[key(const UnknownTag(), 'units.h1')] = jsonEncode({
          'saved_at': '2026-11-01T00:00:00Z',
          'value': <String>[],
        });
        store.values[key(const PortfolioTag(_a), 'units.h1')] = jsonEncode({
          'saved_at': '2026-11-02T00:00:00Z',
          'value': [_a],
        });
        store.values[key(const PortfolioTag(_b), 'units.h1')] = jsonEncode({
          'saved_at': '2026-10-01T00:00:00Z',
          'value': [_b],
        });
        expect(await rows('units.h1'), [_a]);
      },
    );

    test('before a list, a store that cannot list its keys shows no saved '
        'copy', () async {
      await putRows('units.h1', [_a]);
      store.keysFailure = Exception('no listing');
      expect(await rows('units.h1'), isNull);
    });

    test(
      'once a list is applied, it is read directly, without a listing',
      () async {
        await putRows('units.h1', [_a]);
        await cache.answer(_user, [_a, _b]);
        store.keysFailure = Exception('no listing');
        expect(await rows('units.h1'), [_a]);
      },
    );

    test(
      'a list that becomes empty shows no saved rows on the next visit',
      () async {
        await cache.answer(_user, [_a]);
        await putRows('units.h1', [_a]);
        // The last unit is archived: the list comes back empty, of no known
        // portfolio, and is not kept; the copy with the unit goes with it.
        await putRows('units.h1', const <String?>[]);
        await pumpEventQueue();
        expect(store.values, isEmpty);
        expect(await rows('units.h1'), isNull);
      },
    );

    test('an older copy still on its way when it becomes empty is deleted '
        'as it lands', () async {
      final slow = _SlowStore()..held = Completer();
      final cache = SwrCache(slow)..serve(_user);
      cache.applyPortfolios(
        _user,
        [_a],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      final older = cache.write(
        _user,
        'units.h1',
        _fromRows,
        [_a],
        _same,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      await cache.write(
        _user,
        'units.h1',
        _fromRows,
        const <String?>[],
        _same,
        epoch: cache.epoch,
      );
      slow.held!.complete();
      await older;
      await pumpEventQueue();
      expect(slow.inner.values, isEmpty);
    });

    test('a copy that lands under its portfolio deletes the one of unknown '
        'portfolio, and the other way round before a list', () async {
      await putRows('leases.u1.-', const <String?>[]);
      expect(store.values.keys, [key(const UnknownTag(), 'leases.u1.-')]);
      await putRows('leases.u1.-', [_a]);
      await pumpEventQueue();
      expect(store.values.keys, [key(const PortfolioTag(_a), 'leases.u1.-')]);
      await putRows('leases.u1.-', const <String?>[]);
      await pumpEventQueue();
      expect(store.values.keys, [key(const UnknownTag(), 'leases.u1.-')]);
    });

    test('a newer write wins over an older one whose copy-removal comes '
        'late', () async {
      final listing = store.keysHeld = Completer();
      await putRows('leases.u1.-', [_a]);
      await putRows('leases.u1.-', const <String?>[]);
      await pumpEventQueue();
      // Both stay until a listing answers: neither removal ran.
      expect(store.values, hasLength(2));
      // Both listings then name both copies: the older write's removal,
      // no longer the newest, deletes nothing; the newer's deletes the
      // older copy.
      store.keysHeld = null;
      listing.complete();
      await pumpEventQueue();
      expect(store.values.keys, [key(const UnknownTag(), 'leases.u1.-')]);
      expect(await rows('leases.u1.-'), isEmpty);
    });
  });

  group('writes of one entry', () {
    test('delete the entry when the older lands last: the store would hold '
        'the older value', () async {
      final stuck = key(const PortfolioTag(_a), 'x');
      store.holding.add(stuck);
      final older = put('x', 1);
      final newer = put('x', 2);
      await pumpEventQueue();
      store.finishHeldWritesNewestFirst();
      await Future.wait([older, newer]);
      expect(store.values, isEmpty);
    });

    test('keep the newer when they land in order', () async {
      final stuck = key(const PortfolioTag(_a), 'x');
      store.holding.add(stuck);
      final older = put('x', 1);
      final newer = put('x', 2);
      await pumpEventQueue();
      store.finishHeldWritesOldestFirst();
      await Future.wait([older, newer]);
      expect(await get('x'), 2);
    });

    test('loss: an older write of the portfolio list that stops being kept '
        'deletes the newer, kept one, although they land in order', () async {
      final scope = OwnScope.portfolioList<List<String>>((list) => list);
      final listKey = key(const OwnTag(), 'portfolios');
      Future<DateTime?> putList(List<String> ids) => cache.write(
        _user,
        'portfolios',
        scope,
        ids,
        _same,
        epoch: cache.epoch,
      );
      void apply(List<String> ids) => cache.applyPortfolios(
        _user,
        ids,
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      apply([_a, _b]);
      store.holding.add(listKey);
      final older = putList([_a, _b]);
      await pumpEventQueue();
      // A list asked later drops pA, and is saved too, while the older
      // write is still in the store's hands.
      apply([_b]);
      final newer = putList([_b]);
      await pumpEventQueue();
      store.finishHeldWritesOldestFirst();
      await Future.wait([older, newer]);
      // The older write, no longer kept, deletes the key, which by then
      // holds the newer list: no list is saved until the next load.
      // (docs/architecture/app.md, What is lost.)
      expect(store.values.containsKey(listKey), isFalse);
    });
  });

  group('a write the store fails', () {
    test('throws, and asks for the entry to go', () async {
      await put('x', 1);
      store.writeFailure = Exception('full');
      await expectLater(put('x', 2), throwsException);
      await pumpEventQueue();
      expect(store.values, isEmpty);
    });

    test(
      'throws its own error when the deletion fails or never answers',
      () async {
        final stuck = key(const PortfolioTag(_a), 'x');
        for (final fault in [store.undeletable, store.silent]) {
          fault.add(stuck);
          store.writeFailure = Exception('full');
          await expectLater(put('x', 2), throwsA(isA<Exception>()));
          fault.clear();
          store.writeFailure = null;
        }
      },
    );

    test('that answers late is deleted when it fails', () async {
      final stuck = key(const PortfolioTag(_a), 'x');
      store.holding.add(stuck);
      final writing = put('x', 1);
      await pumpEventQueue();
      store.failHeldWrites(StateError('late'));
      await expectLater(writing, throwsStateError);
    });
  });

  group('watch', () {
    test(
      'yields the cached value, then the fresh one, which it saves',
      () async {
        await put('x', 1);
        final snapshots = await cache
            .watch(
              userId: _user,
              epoch: cache.epoch,
              query: 'x',
              scope: InPortfolio<int>(_a),
              fetch: () async => 2,
              decode: _decodeInt,
              encode: _same,
            )
            .toList();
        expect([for (final s in snapshots) s.value], [1, 2]);
        expect(snapshots.last.source, SnapshotSource.network);
        expect(await get('x'), 2);
      },
    );

    test('without a cached value yields only the fresh one', () async {
      final snapshots = await cache
          .watch(
            userId: _user,
            epoch: cache.epoch,
            query: 'x',
            scope: InPortfolio<int>(_a),
            fetch: () async => 2,
            decode: _decodeInt,
            encode: _same,
          )
          .toList();
      expect([for (final s in snapshots) s.value], [2]);
    });

    test(
      'a failing fetch ends with its error after the cached value',
      () async {
        await put('x', 1);
        final values = <int>[];
        Object? failure;
        await cache
            .watch(
              userId: _user,
              epoch: cache.epoch,
              query: 'x',
              scope: InPortfolio<int>(_a),
              fetch: () async => throw Exception('offline'),
              decode: _decodeInt,
              encode: _same,
            )
            .handleError((Object error) => failure = error)
            .forEach((s) => values.add(s.value));
        expect(values, [1]);
        expect(failure, isException);
      },
    );

    test('a fetch still on its way when the cache is cleared stores and shows '
        'nothing', () async {
      final answer = Completer<int>();
      final watching = cache
          .watch(
            userId: _user,
            epoch: cache.epoch,
            query: 'x',
            scope: InPortfolio<int>(_a),
            fetch: () => answer.future,
            decode: _decodeInt,
            encode: _same,
          )
          .toList();
      await pumpEventQueue();
      await cache.clear();
      answer.complete(3);
      expect(await watching, isEmpty);
      expect(store.values, isEmpty);
    });
  });

  group('the owner of the epoch', () {
    test('serve does nothing for the owner, and for anyone else starts an '
        'epoch they own, with no list of portfolios', () async {
      await cache.answer(_user, [_a]);
      final epoch = cache.epoch;
      cache.serve(_user);
      expect(cache.epoch, epoch);
      expect(cache.portfoliosOf(_user), {_a});
      cache.serve('u2');
      expect(cache.epoch, epoch + 1);
      expect(cache.serves('u2', epoch + 1), isTrue);
      expect(cache.serves(_user, epoch + 1), isFalse);
      expect(cache.portfoliosOf(_user), isNull);
      expect(cache.portfoliosOf('u2'), isNull);
      // Nobody: an epoch nobody owns, once.
      cache.serve(null);
      expect(cache.epoch, epoch + 2);
      cache.serve(null);
      expect(cache.epoch, epoch + 2);
      // The same user again: a new epoch of theirs.
      cache.serve(_user);
      expect(cache.epoch, epoch + 3);
      expect(cache.serves(_user, epoch), isFalse);
      expect(cache.serves(_user, epoch + 3), isTrue);
    });

    test(
      'a clear starts an epoch nobody owns, which serving nobody keeps',
      () async {
        final epoch = cache.epoch;
        await cache.clear();
        expect(cache.epoch, epoch + 1);
        expect(cache.serves(_user, cache.epoch), isFalse);
        cache.serve(null);
        expect(cache.epoch, epoch + 1);
      },
    );

    test('serves only its owner, in the current epoch; require throws '
        'otherwise', () {
      final epoch = cache.epoch;
      expect(cache.serves(_user, epoch), isTrue);
      expect(cache.require(_user, epoch), epoch);
      for (final (user, at) in [
        (null, epoch),
        ('u2', epoch),
        (_user, epoch - 1),
        (_user, epoch + 1),
      ]) {
        expect(cache.serves(user, at), isFalse, reason: '$user $at');
        expect(
          () => cache.require(user, at),
          throwsA(isA<SessionExpired>()),
          reason: '$user $at',
        );
      }
    });

    for (final (name, user, earlier) in [
      ('another account', 'u2', false),
      ('an earlier epoch of its owner', _user, true),
    ]) {
      test('refuses every operation of $name', () async {
        await put('a', 1);
        await cache.answer(_user, [_a]);
        final epoch = cache.epoch;
        if (earlier) {
          // The owner's session ends and begins again.
          cache
            ..serve(null)
            ..serve(_user);
        }
        final before = {...store.values};
        expect(
          await cache.write(
            user,
            'b',
            InPortfolio<int>(_a),
            2,
            _same,
            epoch: epoch,
          ),
          isNull,
        );
        expect(
          await cache.read(
            user,
            'a',
            InPortfolio<int>(_a),
            _decodeInt,
            epoch: epoch,
          ),
          isNull,
        );
        expect(
          cache.applyPortfolios(user, [_b], asked: cache.ask(), epoch: epoch),
          isFalse,
        );
        cache
          ..addPortfolio(user, _b, epoch: epoch)
          ..removePortfolio(user, _a, epoch: epoch);
        await cache.prune(user);
        await cache.forgetOthers(user);
        var fetched = false;
        await expectLater(
          cache
              .watch(
                userId: user,
                epoch: epoch,
                query: 'a',
                scope: InPortfolio<int>(_a),
                fetch: () async {
                  fetched = true;
                  return 3;
                },
                decode: _decodeInt,
                encode: _same,
              )
              .toList(),
          throwsA(isA<SessionExpired>()),
        );
        await pumpEventQueue();
        expect(fetched, isFalse);
        expect(store.values, before);
        expect(cache.portfoliosOf(user), isNull);
        // The owner's list stays as it was.
        if (!earlier) expect(cache.portfoliosOf(_user), {_a});
      });
    }

    test('nobody signed in: no read and no fetch', () async {
      var fetched = false;
      await expectLater(
        cache
            .watch(
              userId: null,
              epoch: cache.epoch,
              query: 'a',
              scope: InPortfolio<int>(_a),
              fetch: () async {
                fetched = true;
                return 1;
              },
              decode: _decodeInt,
              encode: _same,
            )
            .toList(),
        throwsA(isA<SessionExpired>()),
      );
      expect(fetched, isFalse);
    });

    test('a read whose store answers after another account is served shows '
        'nothing', () async {
      final slow = _SlowReads();
      final cache = SwrCache(slow)..serve(_user);
      await cache.write(
        _user,
        'a',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      slow.held = Completer();
      final reading = cache.read(
        _user,
        'a',
        InPortfolio<int>(_a),
        _decodeInt,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      cache.serve('u2');
      slow.held!.complete();
      expect(await reading, isNull);
    });

    test('a write that lands after another account is served is deleted, '
        'and shows nothing', () async {
      final slow = _SlowStore()..held = Completer();
      final cache = SwrCache(slow)..serve(_user);
      final writing = cache.write(
        _user,
        'x',
        InPortfolio<int>(_a),
        1,
        _same,
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      cache.serve('u2');
      slow.held!.complete();
      expect(await writing, isNull);
      expect(slow.inner.values, isEmpty);
    });

    test('a removal whose listing answers after another account is served '
        'deletes nothing', () async {
      await put('a', 1);
      await cache.seed('u3', 'a', 1, portfolio: _a);
      cache.applyPortfolios(
        _user,
        [_b],
        asked: cache.ask(),
        epoch: cache.epoch,
      );
      await pumpEventQueue();
      await cache.seed(_user, 'a', 1, portfolio: _a);
      await cache.seed('u3', 'a', 1, portfolio: _a);
      final listing = store.keysHeld = Completer();
      final pruning = cache.prune(_user);
      final forgetting = cache.forgetOthers(_user);
      await pumpEventQueue();
      store.keysHeld = null;
      cache.serve('u2');
      listing.complete();
      await Future.wait([pruning, forgetting]);
      expect(store.values, hasLength(2));
    });

    test('a fetch that comes after another account is served is neither '
        'saved nor shown', () async {
      final answer = Completer<int>();
      final watching = cache
          .watch(
            userId: _user,
            epoch: cache.epoch,
            query: 'x',
            scope: InPortfolio<int>(_a),
            fetch: () => answer.future,
            decode: _decodeInt,
            encode: _same,
          )
          .toList();
      await pumpEventQueue();
      cache.serve('u2');
      answer.complete(3);
      expect(await watching, isEmpty);
      expect(store.values, isEmpty);
    });

    test('the copies of a query whose portfolio comes from its value are not '
        'removed for a session that has ended', () async {
      final listing = store.keysHeld = Completer();
      await cache.write(
        _user,
        'u.h',
        _fromRows,
        [_a],
        _same,
        epoch: cache.epoch,
      );
      // Its removal of the other copies waits for the listing; the next
      // session of the same account saves a copy of its own.
      cache
        ..serve(null)
        ..serve(_user);
      await cache.seed(_user, 'u.h', <String>[]);
      store.keysHeld = null;
      listing.complete();
      await pumpEventQueue();
      expect(store.values, hasLength(2));
    });
  });
}

/// A store whose listing of the keys waits for [listing].
final class _HeldKeys implements KeyValueStore {
  new(this.listing);

  final Future<void> listing;
  final inner = MemoryStore();

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<Set<String>> keys() async {
    await listing;
    return await inner.keys();
  }
}
