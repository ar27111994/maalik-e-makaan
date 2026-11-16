// A declarative reference model of the cache's portfolio rule. It keeps no
// simulated cache: it records what happened (writes asked, writes landed or
// failed, clears, list answers, faults) and, after every step, computes from
// that history alone two sets of entries, the ones allowed on the store and
// the ones that must be there, and compares the whole store with them. It
// runs over a MemoryStore with held writes, for many random sequences with
// fixed seeds. It is written from docs/architecture/app.md and the
// documented key format, apart from SwrCache's private parts and from the
// operational model.
//
// The epochs come from the history too: a clear starts one nobody owns,
// serving a user who does not own the current one starts one they own
// (serving nobody: one nobody owns, unless nobody owns it).
//
// Allowed: a key of this version whose value is a write of that key, asked
// by the owner of the epoch it was asked in, landed while that epoch was the
// current one, with no clear since, whose tag the portfolios the user is in
// keep (or the user's own), unless the key met a fault (a refused or hung
// deletion, a silent landing, a failed listing) since that write.
// Required: the last write asked of an entry, when it landed served and
// nothing since could remove it (no clear, no list without its portfolio,
// no list of another user's, no other write of its entry, no fault), is on
// the store.
// A read returns nothing for a user or an epoch the cache does not serve,
// and nothing the rule rejects.
//
// Each of three defects of the cache (CacheFault) must make it report a
// divergence: the tests at the end run it over a cache built with each.
//
// It also fuzzes the key format: random ids and queries with dots, `#`,
// spaces and Urdu; the tag reads back from the key alone, and the removal
// finds every entry by it.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

import '../../../support/fakes.dart' show MemoryStore;

const _alphabet = '0123456789abcdef';

String _uuid(Random r) => [8, 4, 4, 4, 12]
    .map((n) => List.generate(n, (_) => _alphabet[r.nextInt(16)]).join())
    .join('-');

const _pieces = ['tenants', 'active', '', 'علی رضا', '#1', 'a b', '0300', '.'];

/// A fuzzed query text after [kind], a prefix of its own: two queries of
/// different kinds never share a text (an empty value of one and a value
/// of the other would otherwise share a key).
String _query(Random r, String kind) => [
  kind,
  for (var i = 1 + r.nextInt(4); i > 0; i--) _pieces[r.nextInt(_pieces.length)],
].join('.');

/// A query's kind, and what its writes name.
enum _Kind { ownList, own, inPortfolio, fromValue, unknown }

/// A query of the sequence: its text, kind, and portfolio when named.
typedef _Q = ({String text, _Kind kind, String? portfolio});

/// The documented key, built here.
String _keyOf(String user, String tag, String query) =>
    'mm.swr.v2.$user.$tag.$query';

/// A write asked of the cache.
final class _W {
  new(this.id, this.user, this.q, this.names, this.epoch, this.tag);

  final int id;
  final String user;
  final _Q q;
  final List<String> names;
  final int epoch;
  final String tag;

  String get key => _keyOf(user, tag, q.text);

  /// How it ended: null while held; 'refused' (asked for a session the
  /// cache did not serve: nothing was written), 'landed', 'dropped' (it
  /// landed after its session ended, and was deleted), 'failed' or
  /// 'silent'.
  String? end;

  /// The step it ended at.
  int endedAt = -1;
}

/// One thing that happened, at a step.
sealed class _Event {
  const new(this.step);
  final int step;
}

final class _Clear extends _Event {
  const new(super.step);
}

/// A status applied: the cache serves [user], or nobody.
final class _Serve extends _Event {
  const new(super.step, this.user);
  final String? user;
}

final class _Members extends _Event {
  const new(super.step, this.user, this.ids);
  final String user;

  /// The portfolios after it.
  final Set<String> ids;
}

final class _Fault extends _Event {
  const new(super.step, this.key);

  /// The key, or null for every key (a failed listing).
  final String? key;
}

/// The faults of the store end: deletions answer, the keys list.
final class _Heal extends _Event {
  const new(super.step);
}

Object? _encode(_W w) => {'w': w.id};

int _idOf(String raw) =>
    ((jsonDecode(raw) as Map<String, Object?>)['value']!
            as Map<String, Object?>)['w']!
        as int;

CacheScope<_W> _scope(_Q q) => switch (q.kind) {
  _Kind.ownList => OwnScope.portfolioList<_W>((w) => w.names),
  _Kind.own => OwnScope.profile<_W>(),
  _Kind.inPortfolio => InPortfolio<_W>(q.portfolio!),
  _Kind.fromValue => FromValue<_W>(
    (w) => w.names.length == 1 ? w.names.single : null,
  ),
  _Kind.unknown => const UnknownPortfolio<_W>(),
};

/// What the sequence did, step by step, for a failure's message.
final _log = <String>[];

Future<String?> _sequence(Random r, int steps, {CacheFault? fault}) async {
  _log.clear();
  final store = MemoryStore();
  final cache = SwrCache(store, fault: fault);
  final users = [_uuid(r), _uuid(r)];
  final portfolios = [_uuid(r), _uuid(r), _uuid(r)];
  final queries = <_Q>[
    (text: 'portfolios', kind: _Kind.ownList, portfolio: null),
    (text: 'profile', kind: _Kind.own, portfolio: null),
    for (var i = 0; i < 3; i++)
      (
        text: _query(r, 'in$i'),
        kind: _Kind.inPortfolio,
        portfolio: portfolios[r.nextInt(3)],
      ),
    (text: _query(r, 'fv'), kind: _Kind.fromValue, portfolio: null),
    (text: _query(r, 'un'), kind: _Kind.unknown, portfolio: null),
  ];
  final writes = <_W>[];
  final events = <_Event>[];
  final asked = <(int, int)>[];

  // The documented format, and the tag back from it.
  for (final q in queries) {
    final tag = switch (q.kind) {
      _Kind.ownList || _Kind.own => const OwnTag(),
      _Kind.inPortfolio => PortfolioTag(q.portfolio!),
      _ => const UnknownTag(),
    };
    final key = SwrCache.keyOf(users[0], tag, q.text);
    if (key != _keyOf(users[0], tag.text, q.text)) return 'key $key';
    if (EntryTag.parse(tag.text) != tag) return 'tag ${tag.text}';
  }

  int lastClear(int step) => events
      .whereType<_Clear>()
      .where((e) => e.step <= step)
      .fold(-1, (a, e) => max(a, e.step));

  /// The epochs up to [step], from the history: each one's number, owner
  /// and the step it began at (the first, owned by nobody, at -1).
  List<({int epoch, String? owner, int from})> epochsTo(int step) {
    final epochs = [(epoch: 0, owner: null as String?, from: -1)];
    for (final e in events) {
      if (e.step > step) break;
      final last = epochs.last;
      if (e is _Clear) {
        epochs.add((epoch: last.epoch + 1, owner: null, from: e.step));
      } else if (e is _Serve && e.user != last.owner) {
        epochs.add((epoch: last.epoch + 1, owner: e.user, from: e.step));
      }
    }
    return epochs;
  }

  /// The current epoch at [step].
  ({int epoch, String? owner, int from}) epochAt(int step) =>
      epochsTo(step).last;

  /// Whether the cache serves [user] in [epoch] at [step].
  bool servesAt(String user, int epoch, int step) {
    final now = epochAt(step);
    return now.epoch == epoch && now.owner == user;
  }

  /// The portfolios [user] is in at [step], from the history: null unless
  /// they own the epoch and a list was applied since it began.
  Set<String>? membersAt(String user, int step) {
    final now = epochAt(step);
    if (now.owner != user) return null;
    Set<String>? s;
    for (final e in events.whereType<_Members>()) {
      if (e.step > step || e.step <= now.from || e.user != user) continue;
      s = e.ids;
    }
    return s;
  }

  bool keeps(String user, String tag, List<String> names, int step) {
    final s = membersAt(user, step);
    if (s == null) return true;
    if (tag == 'own') return names.every(s.contains);
    if (tag.startsWith('p:')) return s.contains(tag.substring(2));
    return false;
  }

  /// Whether [key] met a fault at any time from [step] on: one that began
  /// then or later, or began earlier and lasted until then.
  bool faultedSince(String key, int step) =>
      events.whereType<_Fault>().any((e) {
        if (e.key != null && e.key != key) return false;
        final healed = events
            .whereType<_Heal>()
            .where((h) => h.step > e.step)
            .fold<int?>(null, (a, h) => a == null ? h.step : min(a, h.step));
        return e.step >= step || healed == null || healed >= step;
      });

  var newestApplied = 0;
  var current = 0;
  // The app starts signed in, most often.
  if (r.nextInt(4) > 0) {
    final first = users[r.nextInt(2)];
    events.add(_Serve(-1, first));
    cache.serve(first);
  }
  for (var step = 0; step < steps; step++) {
    current = step;
    var user = users[r.nextInt(2)];
    var q = queries[r.nextInt(queries.length)];
    final opn = r.nextInt(14);
    final epoch = epochAt(step).epoch;
    _log.add(
      '$step op$opn ${user.substring(0, 4)} ${q.kind.name} e$epoch '
      'w${writes.length}',
    );
    switch (opn) {
      case 12 || 13:
        // A status is applied: a user signed in, or nobody.
        final who = r.nextInt(3) == 0 ? null : user;
        events.add(_Serve(step, who));
        cache.serve(who);
      case 0 || 1 || 2 || 3:
        final names = switch (q.kind) {
          _Kind.ownList => [
            for (final p in portfolios)
              if (r.nextBool()) p,
          ],
          _Kind.fromValue => [
            for (var i = r.nextInt(2); i >= 0; i--) portfolios[r.nextInt(2)],
          ].take(r.nextInt(3)).toList(),
          _ => <String>[],
        };
        final tag = switch (q.kind) {
          _Kind.ownList || _Kind.own => 'own',
          _Kind.inPortfolio => 'p:${q.portfolio}',
          _Kind.fromValue =>
            names.length == 1 ? 'p:${names.single}' : 'unknown',
          _Kind.unknown => 'unknown',
        };
        final w = _W(
          writes.length + 1,
          user,
          q,
          names,
          r.nextInt(6) == 0 ? max(0, epoch - 1) : epoch,
          tag,
        );
        writes.add(w);
        if (!servesAt(user, w.epoch, step)) {
          w
            ..end = 'refused'
            ..endedAt = step;
        }
        if (r.nextInt(3) == 0) store.holding.add(w.key);
        if (r.nextInt(12) == 0) {
          store.landingSilently.add(w.key);
          events.add(_Fault(step, w.key));
        }
        unawaited(
          cache
              .write(w.user, q.text, _scope(q), w, _encode, epoch: w.epoch)
              .then(
                (at) => w
                  ..end ??= at == null ? 'dropped' : 'landed'
                  ..endedAt = w.end == 'refused' ? w.endedAt : current,
                onError: (_) => w
                  ..end = 'failed'
                  ..endedAt = current,
              ),
        );
        store.landingSilently.remove(w.key);
      case 4:
        // The held writes end: newest first, oldest first, or failing.
        final how = r.nextInt(3);
        if (how == 0) store.finishHeldWritesNewestFirst();
        if (how == 1) store.finishHeldWritesOldestFirst();
        if (how == 2) {
          for (final w in writes.where((w) => w.end == null)) {
            events.add(_Fault(step, w.key));
          }
          store.failHeldWrites(StateError('full'));
        }
        store.holding.clear();
      case 5:
        events.add(_Clear(step));
        if (store.keysFailure != null) events.add(_Fault(step, null));
        unawaited(cache.clear().then((_) {}, onError: (_) {}));
      case 6 || 7:
        if (asked.isEmpty || r.nextBool()) asked.add((cache.ask(), epoch));
        final (number, e) = asked[r.nextInt(asked.length)];
        final ids = {
          for (final p in portfolios)
            if (r.nextBool()) p,
        };
        // Applied in a new epoch, the first answer is never stale.
        if (membersAt(user, step) == null) newestApplied = 0;
        if (cache.applyPortfolios(user, ids, asked: number, epoch: e)) {
          // The newest-asked answer of the epoch: never older than one
          // applied before it in the epoch, never of one the cache does not
          // serve.
          if (!servesAt(user, e, step) || number < newestApplied) {
            return 'applied a stale answer #$number';
          }
          newestApplied = number;
          events.add(_Members(step, user, ids));
          if (store.keysFailure != null) events.add(_Fault(step, null));
        }
      case 8:
        final key = writes.isEmpty
            ? null
            : writes[r.nextInt(writes.length)].key;
        if (key != null) {
          events.add(_Fault(step, key));
          if (r.nextBool()) {
            store.undeletable.add(key);
          } else {
            store.silent.add(key);
          }
        }
      case 9:
        events.add(_Heal(step));
        store
          ..undeletable.clear()
          ..silent.clear()
          ..keysFailure = r.nextInt(4) == 0 ? Exception('listing') : null;
        if (store.keysFailure != null) events.add(_Fault(step, null));
      case 10:
        final p = portfolios[r.nextInt(3)];
        final s = membersAt(user, step);
        // In the epoch now, or in the one before.
        final e = r.nextInt(4) == 0 ? epoch - 1 : epoch;
        final served = s != null && servesAt(user, e, step);
        if (r.nextBool()) {
          cache.addPortfolio(user, p, epoch: e);
          if (served) events.add(_Members(step, user, {...s, p}));
        } else {
          cache.removePortfolio(user, p, epoch: e);
          if (served) events.add(_Members(step, user, {...s}..remove(p)));
        }
      default:
        // Reads: what they return must be allowed. Half the time, of an
        // entry the store holds that the rule rejects now.
        await pumpEventQueue();
        final rejected = [
          for (final raw in store.values.values)
            if (writes[_idOf(raw) - 1] case final w
                when !keeps(w.user, w.tag, w.names, step))
              w,
        ];
        if (rejected.isNotEmpty && r.nextBool()) {
          final w = rejected[r.nextInt(rejected.length)];
          user = w.user;
          q = w.q;
        }
        // In the epoch now, or in the one before.
        final e = r.nextInt(4) == 0 ? epoch - 1 : epoch;
        final read = await cache.read(
          user,
          q.text,
          _scope(q),
          (json) => writes[((json! as Map<String, Object?>)['w']! as int) - 1],
          epoch: e,
        );
        if (read != null && !servesAt(user, e, step)) {
          return 'read #${read.value.id} for a session not served';
        }
        if (read != null) {
          final w = read.value;
          if (w.user != user || w.q != q) return 'read another entry';
          if (!keeps(user, w.tag, w.names, step)) {
            return 'read #${w.id}, which the rule rejects';
          }
        }
    }
    await pumpEventQueue();

    // The whole store against the two sets.
    final now = step;
    final epochs = epochsTo(now);

    /// Whether [w] was asked by the owner of its epoch, and landed while
    /// that epoch was the current one.
    bool servedAtLanding(_W w) {
      final asked = epochs.firstWhere((e) => e.epoch == w.epoch);
      return asked.owner == w.user && epochAt(w.endedAt).epoch == w.epoch;
    }

    /// Whether a clear came after [w]'s epoch.
    bool clearedSince(_W w) => epochs.any(
      (e) =>
          e.epoch > w.epoch &&
          events.whereType<_Clear>().any((c) => c.step == e.from),
    );
    final present = <String, int>{
      for (final e in store.values.entries)
        if (e.key.startsWith('mm.swr.')) e.key: _idOf(e.value),
    };
    for (final MapEntry(:key, :value) in present.entries) {
      final w = writes[value - 1];
      if (w.key != key) return 'step $step: $key holds #$value of ${w.key}';
      final excused = faultedSince(key, w.endedAt < 0 ? 0 : w.endedAt);
      if (excused) continue;
      if (clearedSince(w)) return 'step $step: #$value of an ended session';
      if (!servedAtLanding(w)) {
        return 'step $step: #$value of a session not served';
      }
      if (w.tag != 'own' && !keeps(w.user, w.tag, w.names, now)) {
        return 'step $step: #$value under ${w.tag} is kept unkept';
      }
    }
    // Required: the last write asked of each entry, landed, untouched.
    final last = <String, _W>{};
    for (final w in writes) {
      last['${w.user}/${w.q.text}'] = w;
    }
    for (final w in last.values) {
      if (w.end != 'landed') continue;
      if (clearedSince(w) || !servedAtLanding(w)) continue;
      // A list of another user's removes every entry but theirs.
      final others = events.whereType<_Members>().any(
        (e) => e.user != w.user && e.step >= w.endedAt,
      );
      if (others) continue;
      if (lastClear(now) > w.endedAt) continue;
      if (faultedSince(w.key, 0)) continue;
      if (!keeps(w.user, w.tag, w.names, w.endedAt)) continue;
      // Every list since it landed kept it.
      final dropped = events.whereType<_Members>().any(
        (e) =>
            e.user == w.user &&
            e.step >= w.endedAt &&
            !keeps(w.user, w.tag, w.names, e.step),
      );
      if (dropped || !keeps(w.user, w.tag, w.names, now)) continue;
      // An earlier write of the entry that landed after it deletes it (the
      // documented out-of-order loss).
      final crossed = writes.any(
        (o) =>
            o.id < w.id &&
            o.user == w.user &&
            o.q == w.q &&
            o.end != null &&
            o.end != 'refused' &&
            o.endedAt >= w.endedAt,
      );
      if (crossed) continue;
      if (present[w.key] != w.id) {
        return 'step $step: #${w.id} at ${w.key} is missing';
      }
    }
  }
  return null;
}

void main() {
  test('the store holds what the history allows, and what it requires, over '
      'random sequences', () async {
    const sequences = int.fromEnvironment('REF_SEQ', defaultValue: 400);
    const steps = int.fromEnvironment('REF_STEPS', defaultValue: 40);
    for (final seed in [20261115, 15112026]) {
      final r = Random(seed);
      for (var i = 0; i < sequences ~/ 2; i++) {
        final broken = await _sequence(r, steps);
        if (broken != null) {
          fail('seed $seed, sequence $i: $broken\n${_log.join('\n')}');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // The model catches each defect: a cache built with it diverges within a
  // few sequences of a fixed seed.
  for (final fault in CacheFault.values) {
    test('it catches a cache whose ${fault.name}', () async {
      final r = Random(20261116);
      String? broken;
      for (var i = 0; i < 200 && broken == null; i++) {
        broken = await _sequence(r, 40, fault: fault);
      }
      expect(broken, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
