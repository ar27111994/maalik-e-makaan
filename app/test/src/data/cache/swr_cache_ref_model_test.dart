// An independent reference model of SwrCache's removal rule, run against
// SwrCache over a MemoryStore for many random sequences (fixed seed).
//
// The rule: an entry asked for in epoch e, under query q, for user u, must
// not be on the store once its write has landed if, after e, a clear, a
// forgetUser(u) that did not keep q, or a forgetOthers of another user
// happened; an entry no removal covers must be there (unless a write of the
// same key with a higher number landed and was kept first, the documented
// out-of-order delete, or the store refused, hung on, or could not list it
// for a deletion). A write the store fails deletes its key, and leaves the
// key unsettled until a write asked after the failure lands and is kept. A
// write that lands where it is to go, and whose deletion the store refuses
// or hangs on, leaves its user strayed while the store holds it.
//
// It runs 2,000 sequences by default (a few seconds); -DREF_SEQ=20000 runs
// the 20,000 the verifier first ran, REF_ANY=true also lets forgetOthers
// run any number of times (the app calls it once per run, and the cache
// keeps only the last call's user), and REF_MAXF caps the differences kept.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

import '../../../support/fakes.dart';

const _users = ['u1', 'u2'];
const _queries = [
  'portfolios',
  'profile',
  'residence',
  'tenants.A',
  'tenant.x',
];
String _key(String u, String q) => 'mm.swr.v1.$u.$q';

int _idOf(String raw) =>
    ((jsonDecode(raw) as Map<String, Object?>)['value']!
            as Map<String, Object?>)['w']!
        as int;

/// Holds each write until the test lands or fails it; everything else is
/// the MemoryStore underneath.
final class _HeldStore implements KeyValueStore {
  new(this.mem);
  final MemoryStore mem;
  final held = <int, (String, String, Completer<void>)>{};
  String keysMode = 'ok';

  @override
  Future<String?> read(String key) => mem.read(key);

  @override
  Future<void> write(String key, String value) {
    final done = Completer<void>();
    held[_idOf(value)] = (key, value, done);
    return done.future;
  }

  void land(int id) {
    final (key, value, done) = held.remove(id)!;
    mem.values[key] = value;
    done.complete();
  }

  void fail(int id) {
    final (_, _, done) = held.remove(id)!;
    done.completeError(StateError('write failed'));
  }

  @override
  Future<void> delete(String key) => mem.delete(key);

  @override
  Future<Set<String>> keys() async {
    if (keysMode == 'hang') await Completer<void>().future;
    if (keysMode == 'fail') throw StateError('keys failed');
    return mem.values.keys.toSet();
  }
}

sealed class _Op {
  const new();
}

final class _Ask extends _Op {
  const new(this.id, this.u, this.q, this.back);
  final int id;
  final String u;
  final String q;
  final int back; // epoch read this many removals ago (clamped)
  @override
  String toString() => 'ask#$id($u,$q,epoch-$back)';
}

final class _Land extends _Op {
  const new(this.id);
  final int id;
  @override
  String toString() => 'land#$id';
}

final class _Fail extends _Op {
  const new(this.id);
  final int id;
  @override
  String toString() => 'fail#$id';
}

final class _ForgetUser extends _Op {
  const new(this.u, this.keep);
  final String u;
  final Set<String> keep;
  @override
  String toString() => 'forgetUser($u,keep:$keep)';
}

final class _ForgetOthers extends _Op {
  const new(this.u);
  final String u;
  @override
  String toString() => 'forgetOthers($u)';
}

final class _Clear extends _Op {
  const new();
  @override
  String toString() => 'clear';
}

final class _Block extends _Op {
  const new(this.key, this.how);
  final String key;
  final String how; // undeletable, silent, none
  @override
  String toString() => 'block($key,$how)';
}

final class _Keys extends _Op {
  const new(this.mode);
  final String mode;
  @override
  String toString() => 'keys($mode)';
}

/// A removal: what it covers, whatever the epoch.
final class _Removal {
  const new clear() : kind = 'clear', u = null, keep = const {};
  const new forgetUser(this.u, this.keep) : kind = 'user';
  const new forgetOthers(this.u) : kind = 'others', keep = const {};
  final String kind;
  final String? u;
  final Set<String> keep;

  bool covers(String user, String q) => switch (kind) {
    'clear' => true,
    'user' => user == u && !keep.contains(q),
    _ => user != u,
  };
}

final class _MW {
  new(this.id, this.u, this.q, this.epoch, this.number);
  final int id;
  final String u;
  final String q;
  final int epoch;
  final int number;
  int clearedAtAsk = 0; // removals.length of last clear when asked
}

/// Runs [ops]; returns the first difference as text, or null.
Future<String?> _run(List<_Op> ops) async {
  final mem = MemoryStore();
  final store = _HeldStore(mem);
  final cache = SwrCache(store);
  final removals = <_Removal>[];
  var lastClear = 0; // removals.length right after the last clear
  final pending = <int, _MW>{};
  final value = <String, int>{}; // key -> write id expected on the store
  final landed = <String, int>{}; // key -> number of newest kept landing
  final failed = <String, int>{}; // key -> numbers asked at its last failure
  final excused = <String>{}; // keys whose deletion was blocked once
  // key -> the write that landed when it was to go (a removal covered it,
  // or a later one landed first) and whose deletion was blocked.
  final strays = <String, int>{};
  final ids = <int, _MW>{};
  var numbers = 0;

  bool covered(int epoch, String u, String q) {
    for (var i = epoch; i < removals.length; i++) {
      if (removals[i].covers(u, q)) return true;
    }
    return false;
  }

  bool blocked(String key) =>
      mem.undeletable.contains(key) || mem.silent.contains(key);

  for (var step = 0; step < ops.length; step++) {
    final op = ops[step];
    switch (op) {
      case _Ask(:final id, :final u, :final q, :final back):
        final epoch = max(0, removals.length - back);
        if (!covered(epoch, u, q)) {
          final w = _MW(id, u, q, epoch, ++numbers)..clearedAtAsk = lastClear;
          pending[id] = w;
          ids[id] = w;
        }
        unawaited(
          cache
              .write(u, q, {'w': id}, epoch: epoch)
              .then((_) {}, onError: (_) {}),
        );
      case _Land(:final id):
        final w = pending.remove(id);
        if (w == null || !store.held.containsKey(id)) continue;
        store.land(id);
        final key = _key(w.u, w.q);
        value[key] = id;
        if (covered(w.epoch, w.u, w.q) || (landed[key] ?? 0) > w.number) {
          if (blocked(key)) {
            excused.add(key);
            strays[key] = id;
          } else {
            value.remove(key);
          }
        } else {
          landed[key] = w.number;
        }
      case _Fail(:final id):
        final w = pending.remove(id);
        if (w == null || !store.held.containsKey(id)) continue;
        store.fail(id);
        final key = _key(w.u, w.q);
        failed[key] = numbers;
        // The cache deletes the key: the store may hold any value or none.
        if (blocked(key)) {
          excused.add(key);
        } else {
          value.remove(key);
        }
      case _ForgetUser(:final u, :final keep):
        removals.add(_Removal.forgetUser(u, keep));
        _applyRemoval(removals.last, store, value, excused, blocked);
        unawaited(
          cache.forgetUser(u, keep: keep).then((_) {}, onError: (_) {}),
        );
      case _ForgetOthers(:final u):
        removals.add(_Removal.forgetOthers(u));
        _applyRemoval(removals.last, store, value, excused, blocked);
        unawaited(cache.forgetOthers(u).then((_) {}, onError: (_) {}));
      case _Clear():
        removals.add(const _Removal.clear());
        lastClear = removals.length;
        _applyRemoval(removals.last, store, value, excused, blocked);
        unawaited(cache.clear().then((_) {}, onError: (_) {}));
      case _Block(:final key, :final how):
        mem.undeletable.remove(key);
        mem.silent.remove(key);
        if (how == 'undeletable') mem.undeletable.add(key);
        if (how == 'silent') mem.silent.add(key);
      case _Keys(:final mode):
        store.keysMode = mode;
    }
    await pumpEventQueue(times: 2);

    // Compare.
    if (cache.epoch != removals.length) {
      return 'step $step ($op): epoch ${cache.epoch} != ${removals.length}';
    }
    for (final u in _users) {
      for (final q in _queries) {
        final key = _key(u, q);
        final raw = mem.values[key];
        final actual = raw == null ? null : _idOf(raw);
        if (actual != value[key]) {
          return 'step $step ($op): $key holds ${actual ?? '-'}, model '
              '${value[key] ?? '-'}';
        }
        // The rule itself: a covered value only where a deletion was blocked.
        if (actual != null) {
          final w = ids[actual]!;
          if (covered(w.epoch, u, q) && !excused.contains(key)) {
            return 'step $step ($op): $key holds removed write #$actual';
          }
          // A value left where it was to go is told by strayed.
          if (strays[key] == actual && !cache.strayed(u)) {
            return 'step $step ($op): $key holds stray #$actual, but '
                'strayed($u) is false';
          }
        }
        // writing(): the unfinished writes asked since the last clear.
        final want = [
          for (final w in pending.values)
            if (_key(w.u, w.q) == key && w.clearedAtAsk == lastClear) w.id,
        ]..sort();
        final got = [
          for (final v in cache.writing(u, q))
            (v! as Map<String, Object?>)['w']! as int,
        ]..sort();
        if (want.join(',') != got.join(',')) {
          return 'step $step ($op): writing($u,$q) $got, model $want';
        }
        final unsettled =
            failed.containsKey(key) && (landed[key] ?? 0) <= failed[key]!;
        if (cache.unsettled(u, q) != unsettled) {
          return 'step $step ($op): unsettled($u,$q) ${!unsettled}, model '
              '$unsettled';
        }
      }
    }
  }
  return null;
}

void _applyRemoval(
  _Removal r,
  _HeldStore store,
  Map<String, int> value,
  Set<String> excused,
  bool Function(String) blocked,
) {
  for (final key in [...value.keys]) {
    final rest = key.substring('mm.swr.v1.'.length);
    final dot = rest.indexOf('.');
    final u = rest.substring(0, dot);
    final q = rest.substring(dot + 1);
    if (!r.covers(u, q)) continue;
    if (store.keysMode != 'ok' || blocked(key)) {
      excused.add(key);
    } else {
      value.remove(key);
    }
  }
}

List<_Op> _sequence(Random rnd, {required int maxOthers}) {
  final ops = <_Op>[];
  final length = 1 + rnd.nextInt(40);
  var nextId = 1;
  var others = 0;
  final asked = <int>[];
  for (var i = 0; i < length; i++) {
    final r = rnd.nextInt(100);
    if (r < 32) {
      final id = nextId++;
      asked.add(id);
      ops.add(
        _Ask(
          id,
          _users[rnd.nextInt(_users.length)],
          _queries[rnd.nextInt(_queries.length)],
          rnd.nextInt(3),
        ),
      );
    } else if (r < 52 && asked.isNotEmpty) {
      ops.add(_Land(asked[rnd.nextInt(asked.length)]));
    } else if (r < 58 && asked.isNotEmpty) {
      ops.add(_Fail(asked[rnd.nextInt(asked.length)]));
    } else if (r < 72) {
      ops.add(
        _ForgetUser(_users[rnd.nextInt(_users.length)], {
          for (final q in _queries)
            if (rnd.nextInt(3) == 0) q,
        }),
      );
    } else if (r < 76 && others < maxOthers) {
      others++;
      ops.add(_ForgetOthers(_users[rnd.nextInt(_users.length)]));
    } else if (r < 84) {
      ops.add(const _Clear());
    } else if (r < 94) {
      final key = _key(
        _users[rnd.nextInt(_users.length)],
        _queries[rnd.nextInt(_queries.length)],
      );
      ops.add(
        _Block(
          key,
          const ['none', 'none', 'undeletable', 'silent'][rnd.nextInt(4)],
        ),
      );
    } else {
      ops.add(_Keys(const ['ok', 'ok', 'ok', 'fail', 'hang'][rnd.nextInt(5)]));
    }
  }
  return ops;
}

Future<(List<_Op>, String)> _shrink(List<_Op> ops, String why) async {
  var best = ops;
  var reason = why;
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < best.length; i++) {
      final shorter = [...best]..removeAt(i);
      final r = await _run(shorter);
      if (r != null) {
        best = shorter;
        reason = r;
        changed = true;
        break;
      }
    }
  }
  return (best, reason);
}

Future<void> _campaign(
  int seed,
  int sequences, {
  required int maxOthers,
}) async {
  final rnd = Random(seed);
  var steps = 0;
  final failures = <String>{};
  for (var s = 0; s < sequences; s++) {
    final ops = _sequence(rnd, maxOthers: maxOthers);
    steps += ops.length;
    final r = await _run(ops);
    if (r != null) {
      final (shrunk, why) = await _shrink(ops, r);
      failures.add('${shrunk.join(' ; ')}\n   => $why');
      if (failures.length >=
          const int.fromEnvironment('REF_MAXF', defaultValue: 5)) {
        break;
      }
    }
  }
  // The size of the run and each difference, for the person reading it.
  // ignore: avoid_print
  print(
    'seed $seed maxOthers $maxOthers: $sequences sequences, $steps steps, '
    '${failures.length} distinct shrunk differences',
  );
  for (final f in failures) {
    // A difference, shrunk, for the person reading the run.
    // ignore: avoid_print
    print('  DIFF: $f');
  }
  expect(failures, isEmpty, reason: failures.join('\n'));
}

void main() {
  const sequences = int.fromEnvironment('REF_SEQ', defaultValue: 2000);
  test(
    'SwrCache agrees with the reference model (forgetOthers at most once)',
    () => _campaign(20261115, sequences, maxOthers: 1),
    timeout: const Timeout(Duration(minutes: 20)),
  );
  test(
    'SwrCache agrees with the reference model (forgetOthers any number)',
    () => _campaign(7, sequences ~/ 4, maxOthers: 99),
    timeout: const Timeout(Duration(minutes: 20)),
    skip: !const bool.fromEnvironment('REF_ANY'),
  );
}
