// An operational model of the cache's portfolio rule, run against SwrCache
// over random sequences of its operations with a fixed seed. It is written
// from the rules in docs/architecture/app.md (Reading, Writes after a
// removal) and builds keys with its own code from the documented format; it
// reads nothing private of SwrCache, and nothing of the other model.
//
// The rules it simulates, step by step:
// R1  a key `mm.swr.v2.<user>.<tag>.<query>` says what its entry holds: `own`,
//     `p:<portfolio>` or `unknown`.
// R2  only the newest-asked list answer of an epoch applies; it sets the
//     portfolios the user is in (S), then deletes, from the keys alone,
//     every entry S does not keep, another user's and older versions'.
// R3  a write is kept only if, when the store has written it, the cache
//     still serves its user in its epoch and S keeps its tag (S unknown:
//     kept); otherwise it is deleted as it lands. A later write of the
//     entry that landed first wins (the older is deleted as it lands).
// R6  the cache serves one user at a time: a clear starts an epoch nobody
//     owns, serving a user who does not own the current epoch starts one
//     they own (serving nobody: one nobody owns, unless nobody owns it).
//     Every operation (a read, a write, a list answer, a portfolio added
//     or removed, a removal) does anything only while its epoch is the
//     current one and its user owns it.
//
// The store is controlled: every write waits until the model lands it,
// fails it, or lets it land silently (stored, never answered); deletions of
// chosen keys fail or never answer; a listing of the keys fails. Since a
// deletion that fails or hangs leaves the value where it was, the model
// predicts the store exactly, and checks after every step that:
// - the store holds exactly what the model says (the code follows the rules);
// - privacy: an entry the rule rejects is there only while its last deletion
//   failed or hung, or it landed silently, or the listing of the last
//   removal failed;
// - a read never returns an entry the rule rejects, nor anything for a user
//   or an epoch the cache does not serve, and finds an entry whose portfolio
//   comes from its value under whatever tag it has;
// - the epoch moves only at a clear or at serving a new owner.
//
// Each of three defects of the cache (CacheFault) must make it report a
// divergence: the tests at the end run it over a cache built with each.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

const _users = ['u1', 'u2'];
const _portfolios = ['A', 'B', 'C'];

/// The queries, each of one kind.
const _ownList = 'portfolios';
const _profile = 'profile';
const _inA = 'tenants.A.active.';
const _inB = 'tenants.B';
const _fromValue = 'units.h.1';
const _unknown = 'note';
const List<String> _queries = [
  _ownList,
  _profile,
  _inA,
  _inB,
  _fromValue,
  _unknown,
];

/// The value a write saves: its number, and the portfolios it names (the
/// list's ids, or the rows' portfolios; null for a row of none).
final class _V {
  const new(this.w, this.names);

  factory fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return _V(map['w']! as int, [
      for (final n in map['names']! as List) n as String?,
    ]);
  }

  final int w;
  final List<String?> names;

  Object? toJson() => {'w': w, 'names': names};
}

CacheScope<_V> _scopeOf(String query) => switch (query) {
  _ownList => OwnScope.portfolioList<_V>((v) => [...v.names.nonNulls]),
  _profile => OwnScope.profile<_V>(),
  _inA => InPortfolio<_V>('A'),
  _inB => InPortfolio<_V>('B'),
  _fromValue => FromValue<_V>((v) => _one(v.names)),
  _ => const UnknownPortfolio<_V>(),
};

/// The one portfolio all of [names] name, else null.
String? _one(List<String?> names) {
  if (names.isEmpty || names.contains(null)) return null;
  return names.toSet().length == 1 ? names.first : null;
}

/// The model's own key builder, from the documented format.
String _key(String user, String tag, String query) =>
    'mm.swr.v2.$user.$tag.$query';

/// The tag the model gives [query]'s entry holding [names].
String _tagOf(String query, List<String?> names) => switch (query) {
  _ownList || _profile => 'own',
  _inA => 'p:A',
  _inB => 'p:B',
  _fromValue => _one(names) == null ? 'unknown' : 'p:${_one(names)}',
  _ => 'unknown',
};

int _idOf(String raw) =>
    ((jsonDecode(raw) as Map<String, Object?>)['value']!
            as Map<String, Object?>)['w']!
        as int;

/// A store whose writes wait for the model, and whose deletions and listings
/// fail or hang on request.
final class _Store implements KeyValueStore {
  final values = <String, String>{};
  final pending = <(int, String, String, Completer<void>)>[];
  final refusing = <String>{};
  final hanging = <String>{};
  bool listingFails = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) {
    final done = Completer<void>();
    pending.add((_idOf(value), key, value, done));
    return done.future;
  }

  @override
  Future<void> delete(String key) async {
    if (hanging.contains(key)) await Completer<void>().future;
    if (refusing.contains(key)) throw StateError('refused');
    values.remove(key);
  }

  @override
  Future<Set<String>> keys() async {
    if (listingFails) throw StateError('no listing');
    return values.keys.toSet();
  }
}

/// A write the model asked for.
typedef _Write = ({
  int w,
  String user,
  String query,
  String tag,
  List<String?> names,
  int epoch,
});

/// The model's state.
final class _Model {
  int epoch = 0;
  int cleared = 0;
  int asked = 0;

  /// The user who owns [epoch]; null when nobody does.
  String? owner;

  /// The owner's portfolios (S), under their id, once a list was applied in
  /// the epoch; nobody else's.
  final members = <String, Set<String>>{};
  int claimed = 0;
  final newest = <String, int>{};

  /// Whether the cache serves [user] in [at].
  bool serves(String? user, int at) =>
      user != null && at == epoch && user == owner;

  /// A new epoch, owned by [user].
  void start(String? user) {
    epoch++;
    owner = user;
    members.clear();
    claimed = 0;
  }

  /// What the store holds, by key: the number of the write.
  final store = <String, int>{};

  /// Keys whose last deletion failed or never answered.
  final dirty = <String>{};

  /// Keys that landed silently since the last removal that listed them.
  final silentlyLanded = <String>{};

  /// Users whose last removal could not list the keys.
  final unlisted = <String>{};

  /// The keys of an earlier version the store still holds: the model never
  /// touches the store, so a cache that stopped deleting them is caught.
  final legacy = <String>{};

  bool keeps(String user, String tag, List<String?> names) {
    final s = members[user];
    if (s == null) return true;
    if (tag == 'own') return names.nonNulls.every(s.contains);
    if (tag.startsWith('p:')) return s.contains(tag.substring(2));
    return false;
  }
}

String _entry(String user, String query) => '$user/$query';

Future<void> _settle() => pumpEventQueue(times: 30);

/// Runs one random sequence; returns a description of the first broken
/// property, or null.
Future<String?> _run(
  Random random,
  int steps,
  List<String> log, {
  CacheFault? fault,
}) async {
  final store = _Store();
  var clock = DateTime.utc(2026, 11, 15);
  final cache = SwrCache(
    store,
    clock: () => clock = clock.add(const Duration(seconds: 1)),
    fault: fault,
  );
  final m = _Model();
  final writes = <int, _Write>{};
  var nextW = 0;
  final askedNumbers = <(int, int)>[]; // (number, epoch)

  // An earlier version's entry, and another user's.
  store.values['mm.swr.v1.u1.tenants'] = '{}';
  m.legacy.add('mm.swr.v1.u1.tenants');
  // The app starts signed in, most often.
  if (random.nextInt(4) > 0) {
    final first = _users[random.nextInt(_users.length)];
    cache.serve(first);
    m.start(first);
    log.add('serve $first');
  }

  void deleteKey(String key) {
    if (store.hanging.contains(key) || store.refusing.contains(key)) {
      if (m.store.containsKey(key)) m.dirty.add(key);
      return;
    }
    m.store.remove(key);
    m.dirty.remove(key);
    m.silentlyLanded.remove(key);
  }

  /// Every key of the cache's the store lists: the model's own record of
  /// what a removal that lists the keys finds.
  Iterable<String> listed() => [...m.store.keys, ...m.legacy];

  /// A removal deletes [key] of an earlier version, unless its deletion
  /// fails or hangs (none of them do: their faults are only drawn for this
  /// version's keys).
  void deleteLegacy(String key) {
    if (!store.hanging.contains(key) && !store.refusing.contains(key)) {
      m.legacy.remove(key);
    }
  }

  /// Whether the removal keeps [key]: the user's own always (they hold
  /// nothing of a portfolio but the list's names, which a read checks), a
  /// portfolio's while S keeps it.
  bool keyKept(String key) {
    final w = writes[m.store[key]]!;
    return w.tag == 'own' || m.keeps(w.user, w.tag, w.names);
  }

  void prune(String user) {
    if (!m.serves(user, m.epoch) || m.members[user] == null) return;
    if (store.listingFails) {
      m.unlisted.add(user);
      return;
    }
    m.unlisted.remove(user);
    final mine = 'mm.swr.v2.$user.';
    for (final key in [...listed()]) {
      if (!key.startsWith(mine)) {
        if (m.store.containsKey(key)) {
          deleteKey(key);
        } else {
          deleteLegacy(key);
        }
        continue;
      }
      if (!keyKept(key)) deleteKey(key);
    }
  }

  void dropCopies(String user, String query, String except, int w) {
    if (!m.serves(user, writes[w]!.epoch)) return;
    final s = m.members[user];
    final List<String> keys;
    if (s != null) {
      keys = [
        for (final p in s) _key(user, 'p:$p', query),
        _key(user, 'unknown', query),
      ];
    } else {
      if (store.listingFails) return;
      keys = [
        for (final key in m.store.keys)
          if (key.startsWith('mm.swr.v2.$user.') &&
              key.endsWith('.$query') &&
              !key.startsWith('mm.swr.v2.$user.own.') &&
              key.split('.').length == _key(user, 'x', query).split('.').length)
            key,
      ];
    }
    for (final key in keys) {
      if (key != except && m.newest[_entry(user, query)] == w) {
        if (m.store.containsKey(key)) deleteKey(key);
      }
    }
  }

  String? check(String step) {
    final actual = {
      for (final e in store.values.entries)
        if (e.key.startsWith('mm.swr.v2.')) e.key: _idOf(e.value),
    };
    if (!_mapEquals(actual, m.store)) {
      return '$step: store $actual, model ${m.store}';
    }
    // Every other key of the cache's, by its name.
    final older = {
      for (final key in store.values.keys)
        if (key.startsWith('mm.swr.') && !key.startsWith('mm.swr.v2.')) key,
    };
    if (older.length != m.legacy.length || !older.containsAll(m.legacy)) {
      return '$step: older keys $older, model ${m.legacy}';
    }
    if (cache.epoch != m.epoch) return '$step: epoch ${cache.epoch}';
    for (final key in m.store.keys) {
      final w = writes[m.store[key]]!;
      final excused =
          m.dirty.contains(key) ||
          m.silentlyLanded.contains(key) ||
          m.unlisted.contains(w.user);
      if (w.epoch < m.cleared && !excused) {
        return '$step: $key of an ended session stays';
      }
      if (!keyKept(key) && !excused) return '$step: $key is kept unkept';
    }
    return null;
  }

  for (var step = 0; step < steps; step++) {
    var user = _users[random.nextInt(_users.length)];
    var query = _queries[random.nextInt(_queries.length)];
    final op = random.nextInt(16);
    String desc;
    switch (op) {
      case 14 || 15:
        // A status is applied: a user signed in, or nobody.
        final who = random.nextInt(3) == 0 ? null : user;
        desc = 'serve $who';
        cache.serve(who);
        if (who != m.owner) m.start(who);
      case 0 || 1 || 2:
        final names = switch (query) {
          _ownList => [
            for (final p in _portfolios)
              if (random.nextBool()) p,
          ],
          _fromValue => [
            for (var i = random.nextInt(3); i > 0; i--)
              _portfolios[random.nextInt(4) == 0 ? random.nextInt(2) : 0],
          ],
          _ => <String?>[],
        };
        final old = random.nextInt(5) == 0 && m.epoch > 0;
        final epoch = old ? m.epoch - 1 : m.epoch;
        final w = ++nextW;
        final tag = _tagOf(query, names);
        writes[w] = (
          w: w,
          user: user,
          query: query,
          tag: tag,
          names: names,
          epoch: epoch,
        );
        desc = 'write#$w $user $query $tag $names e$epoch';
        unawaited(
          cache
              .write(
                user,
                query,
                _scopeOf(query),
                _V(w, names),
                (v) => v.toJson(),
                epoch: epoch,
              )
              .then((_) {}, onError: (_) {}),
        );
        if (!m.serves(user, epoch)) break;
        if (!m.keeps(user, tag, names)) {
          m.newest[_entry(user, query)] = w;
          if (query == _fromValue) dropCopies(user, query, '', w);
        }
      case 3 || 4:
        // A held write lands, fails, or lands silently.
        await _settle();
        if (store.pending.isEmpty) {
          desc = 'nothing held';
          break;
        }
        final i = random.nextInt(store.pending.length);
        final (w, key, raw, done) = store.pending.removeAt(i);
        final wr = writes[w]!;
        final how = random.nextInt(6);
        if (how == 0) {
          desc = 'fail#$w';
          done.completeError(StateError('full'));
          deleteKey(key);
        } else if (how == 1) {
          desc = 'silent#$w';
          store.values[key] = raw;
          m.store[key] = w;
          m.dirty.remove(key);
          m.silentlyLanded.add(key);
        } else {
          desc = 'land#$w';
          store.values[key] = raw;
          m.store[key] = w;
          m.dirty.remove(key);
          m.silentlyLanded.remove(key);
          done.complete();
          final entry = _entry(wr.user, wr.query);
          if (!m.serves(wr.user, wr.epoch) ||
              !m.keeps(wr.user, wr.tag, wr.names) ||
              (m.newest[entry] ?? 0) > w) {
            deleteKey(key);
          } else {
            m.newest[entry] = w;
            if (wr.query == _fromValue) dropCopies(wr.user, wr.query, key, w);
          }
        }
      case 5:
        desc = 'clear';
        m
          ..start(null)
          ..cleared = m.epoch;
        unawaited(cache.clear().then((_) {}, onError: (_) {}));
        // A wipe that cannot list leaves everything, as one whose deletions
        // fail: the residue of a failed wipe.
        if (store.listingFails) m.dirty.addAll(m.store.keys);
        if (!store.listingFails) {
          for (final key in [...listed()]) {
            if (m.store.containsKey(key)) {
              deleteKey(key);
            } else {
              deleteLegacy(key);
            }
          }
        }
      case 6 || 7:
        // A list answer, asked now or earlier, maybe before a clear.
        if (askedNumbers.isEmpty || random.nextBool()) {
          askedNumbers.add((cache.ask(), m.epoch));
          m.asked++;
        }
        final (number, epoch) =
            askedNumbers[random.nextInt(askedNumbers.length)];
        final ids = [
          for (final p in _portfolios)
            if (random.nextBool()) p,
        ];
        final applied = cache.applyPortfolios(
          user,
          ids,
          asked: number,
          epoch: epoch,
        );
        final expected = m.serves(user, epoch) && m.claimed <= number;
        desc = 'apply $user $ids #$number e$epoch -> $applied';
        if (applied != expected) return '$desc: model says $expected';
        if (expected) {
          m.claimed = number;
          m.members[user] = {...ids};
          prune(user);
        }
      case 8:
        final p = _portfolios[random.nextInt(_portfolios.length)];
        final add = random.nextBool();
        desc = '${add ? 'add' : 'remove'} $user $p';
        // In the epoch now, or in the one before.
        final epoch = random.nextInt(4) == 0 ? m.epoch - 1 : m.epoch;
        desc += ' e$epoch';
        final served = m.serves(user, epoch);
        if (add) {
          cache.addPortfolio(user, p, epoch: epoch);
          if (served) m.members[user]?.add(p);
        } else {
          cache.removePortfolio(user, p, epoch: epoch);
          if (served && (m.members[user]?.remove(p) ?? false)) prune(user);
        }
      case 9:
        final key = random.nextBool()
            ? _key(user, _tagOf(query, const ['A']), query)
            : _key(user, 'p:B', _fromValue);
        final which = random.nextInt(3);
        desc = 'fault $key $which';
        store.refusing.remove(key);
        store.hanging.remove(key);
        if (which == 0) store.refusing.add(key);
        if (which == 1) store.hanging.add(key);
      case 10:
        store.listingFails = !store.listingFails;
        desc = 'listing fails: ${store.listingFails}';
      case 11:
        desc = 'prune $user';
        unawaited(cache.prune(user).then((_) {}, onError: (_) {}));
        prune(user);
      case 12:
        desc = 'forgetOthers $user';
        unawaited(cache.forgetOthers(user).then((_) {}, onError: (_) {}));
        if (m.serves(user, m.epoch) && !store.listingFails) {
          for (final key in [...listed()]) {
            if (key.startsWith('mm.swr.v2.$user.')) continue;
            if (m.store.containsKey(key)) {
              deleteKey(key);
            } else {
              deleteLegacy(key);
            }
          }
        }
      default:
        // A read: never an entry the rule rejects. Half the time, of an
        // entry the store holds that the rule rejects (its deletion failed
        // or hung, it landed silently, or a removal could not list it).
        final rejected = [
          for (final w in m.store.values.map((w) => writes[w]!))
            if (!m.keeps(w.user, w.tag, w.names)) w,
        ];
        if (rejected.isNotEmpty && random.nextBool()) {
          final w = rejected[random.nextInt(rejected.length)];
          user = w.user;
          query = w.query;
        }
        if (query == _fromValue &&
            m.members[user] == null &&
            store.listingFails) {
          desc = 'read skipped';
          break;
        }
        await _settle();
        // In the epoch now, or in the one before.
        final epoch = random.nextInt(4) == 0 ? m.epoch - 1 : m.epoch;
        final served = m.serves(user, epoch);
        desc = 'read $user $query e$epoch';
        final read = await cache.read(
          user,
          query,
          _scopeOf(query),
          _V.fromJson,
          epoch: epoch,
        );
        if (read != null && !served) {
          return '$desc: read #${read.value.w} for a session not served';
        }
        if (!served) break;
        if (read != null) {
          final w = writes[read.value.w]!;
          if (w.user != user || w.query != query) {
            return "$desc: read another entry's #${w.w}";
          }
          if (!m.keeps(user, w.tag, w.names)) {
            return '$desc: read #${w.w}, which the rule rejects';
          }
        } else {
          // Found when the model holds one the rule keeps, whose key the
          // read looks at.
          final s = m.members[user];
          for (final key in m.store.keys) {
            final w = writes[m.store[key]]!;
            if (w.user != user || w.query != query) continue;
            if (!m.keeps(user, w.tag, w.names)) continue;
            final looked =
                query != _fromValue ||
                s == null && !store.listingFails ||
                s != null && w.tag.startsWith('p:');
            if (looked) return '$desc: missed $key';
          }
        }
        // The read asks for the deletion of what it rejects.
        for (final key in [...m.store.keys]) {
          final w = writes[m.store[key]]!;
          if (w.user != user || w.query != query) continue;
          // A query found by its value reads only keys the rule keeps.
          if (query != _fromValue && !m.keeps(user, w.tag, w.names)) {
            deleteKey(key);
          }
        }
    }
    log.add(desc);
    await _settle();
    final broken = check(desc);
    if (broken != null) return broken;
  }
  return null;
}

bool _mapEquals(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

void main() {
  test('SwrCache keeps what the portfolio rule keeps, and nothing else, over '
      'random sequences', () async {
    const sequences = int.fromEnvironment('MODEL_SEQ', defaultValue: 500);
    const steps = int.fromEnvironment('MODEL_STEPS', defaultValue: 40);
    final random = Random(20261115);
    for (var i = 0; i < sequences; i++) {
      final log = <String>[];
      final broken = await _run(random, steps, log);
      if (broken != null) {
        fail('sequence $i: $broken\n  after: ${log.join('\n  ')}');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // The model catches each defect: a cache built with it diverges within a
  // few sequences of a fixed seed.
  for (final fault in CacheFault.values) {
    test('it catches a cache whose ${fault.name}', () async {
      final random = Random(20261116);
      String? broken;
      for (var i = 0; i < 200 && broken == null; i++) {
        broken = await _run(random, 40, [], fault: fault);
      }
      expect(broken, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
