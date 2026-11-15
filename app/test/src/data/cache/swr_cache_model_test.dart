// A reference model of what SwrCache keeps, run against SwrCache over random
// sequences of its operations, with a fixed seed (so a failure is the same on
// every run, and is printed shrunk to the fewest operations that show it).
//
// The rule: a write asked for in epoch e, of query q, for user u, must not be
// on the store once its write has landed if, after e, the cache was cleared,
// or u's entries were forgotten with q not kept, or another user's entries
// alone were kept (forgetOthers). An entry no removal covers must be there,
// unless a write of the same key with a higher number landed first (the
// documented out-of-order delete), or its key's deletion failed or hung. A
// write the store fails deletes its key, which is unsettled until a write
// asked after the failure lands and is kept.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

const _users = ['u1', 'u2'];
const _queries = ['portfolios', 'profile', 'residence', 'tenants.A', 'lease.1'];

String _key(String u, String q) => 'mm.swr.v1.$u.$q';

/// The number of the write whose entry [value] is.
int _idOf(String value) =>
    ((jsonDecode(value) as Map<String, Object?>)['value']!
            as Map<String, Object?>)['w']!
        as int;

/// A store whose every write waits until the test lands or fails it, in any
/// order, and whose deletions and listings fail or hang on request.
final class _CtlStore implements KeyValueStore {
  final values = <String, String>{};
  final pending = <(int, String, String, Completer<void>)>[];
  final undeletable = <String>{};
  final silent = <String>{};
  String keysMode = 'ok';

  /// Keys whose last deletion failed or never answered.
  final dirty = <String>{};

  /// Ids of the writes the store was asked for.
  final asked = <int>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) {
    final id = _idOf(value);
    asked.add(id);
    final done = Completer<void>();
    pending.add((id, key, value, done));
    return done.future;
  }

  @override
  Future<void> delete(String key) async {
    if (silent.contains(key)) {
      dirty.add(key);
      await Completer<void>().future;
    }
    if (undeletable.contains(key)) {
      dirty.add(key);
      throw StateError('cannot delete $key');
    }
    dirty.remove(key);
    values.remove(key);
  }

  @override
  Future<Set<String>> keys() async {
    if (keysMode == 'hang') await Completer<void>().future;
    if (keysMode == 'fail') throw StateError('keys failed');
    return values.keys.toSet();
  }
}

final class _W {
  new(this.id, this.u, this.q, this.epoch);
  final int id;
  final String u;
  final String q;
  final int epoch;
  bool landed = false;
}

/// Removals, as the model sees them: (kind, user, keep, epoch).
final class _Removal {
  new(this.kind, this.user, this.keep, this.epoch);
  final String kind; // clear, forget, others
  final String? user;
  final Set<String> keep;
  final int epoch;

  bool covers(_W w) {
    if (w.epoch >= epoch) return false;
    switch (kind) {
      case 'clear':
        return true;
      case 'forget':
        return w.u == user && !keep.contains(w.q);
      default:
        return w.u != user;
    }
  }
}

/// One operation, as data, so that a sequence can be replayed and shrunk.
typedef _Op = List<int>;

String _show(_Op op) {
  Set<String> keep(int mask) => {
    for (var i = 0; i < _queries.length; i++)
      if (mask & (1 << i) != 0) _queries[i],
  };
  return switch (op[0]) {
    0 => 'write(${_users[op[1]]}, ${_queries[op[2]]}, epochSel ${op[3]})',
    1 => 'land(#${op[1]})',
    2 => 'failWrite(#${op[1]})',
    3 => 'clear()',
    4 => 'forgetUser(${_users[op[1]]}, keep: ${keep(op[2])})',
    5 => 'forgetOthers(${_users[op[1]]})',
    6 => 'undeletable(${_queries[op[2]]} of ${_users[op[1]]})',
    7 => 'silent(${_queries[op[2]]} of ${_users[op[1]]})',
    8 => 'mend deletes',
    9 => 'keys ${['ok', 'fail', 'hang'][op[1]]}',
    _ => '?',
  };
}

_Op _randomOp(Random r) {
  final p = r.nextInt(100);
  if (p < 30) {
    return [0, r.nextInt(2), r.nextInt(_queries.length), r.nextInt(4)];
  }
  if (p < 50) return [1, r.nextInt(8)];
  if (p < 55) return [2, r.nextInt(8)];
  if (p < 61) return [3];
  if (p < 73) return [4, r.nextInt(2), r.nextInt(1 << _queries.length)];
  if (p < 78) return [5, r.nextInt(2)];
  if (p < 82) return [6, r.nextInt(2), r.nextInt(_queries.length)];
  if (p < 84) return [7, r.nextInt(2), r.nextInt(_queries.length)];
  if (p < 89) return [8];
  if (p < 93) {
    return [9, if (r.nextInt(10) < 7) 0 else 1 + r.nextInt(2)];
  }
  return [1, r.nextInt(8)];
}

/// Runs [ops]; returns the first difference from the model, or null.
Future<String?> _run(List<_Op> ops) async {
  final store = _CtlStore();
  final cache = SwrCache(store);
  final writes = <int, _W>{};
  final removals = <_Removal>[];
  var modelEpoch = 0;
  var nextId = 0;
  // The id of each key's writes in the order they landed.
  final landedOrder = <String, List<int>>{};
  // Keys whose last write to end failed: the cache deleted them.
  final failedLast = <String>{};
  // The newest id asked when a write of each key last failed, and the
  // newest id of each key that landed and was kept ([SwrCache.unsettled]).
  final failedAt = <String, int>{};
  final kept = <String, int>{};

  bool covered(_W w) => removals.any((r) => r.covers(w));

  Set<String> keepOf(int mask) => {
    for (var i = 0; i < _queries.length; i++)
      if (mask & (1 << i) != 0) _queries[i],
  };

  for (var step = 0; step < ops.length; step++) {
    final op = ops[step];
    switch (op[0]) {
      case 0:
        final u = _users[op[1]];
        final q = _queries[op[2]];
        // 0, 1: the current epoch; 2: requestEpoch of a reader made at a
        // random earlier epoch; 3: a random earlier epoch (a value made
        // from one on show).
        final made = modelEpoch == 0
            ? 0
            : (op[3] * 7919 + step) % (modelEpoch + 1);
        final epoch = switch (op[3]) {
          0 || 1 => cache.epoch,
          2 => cache.requestEpoch(madeIn: made),
          _ => made,
        };
        final w = _W(nextId++, u, q, epoch);
        writes[w.id] = w;
        unawaited(
          cache
              .write(u, q, {'w': w.id}, epoch: epoch)
              .then((_) {}, onError: (_) {}),
        );
        await Future<void>.delayed(Duration.zero);
        if (!covered(w) && !store.asked.contains(w.id)) {
          return 'step $step: an uncovered write was not asked of the store';
        }
      case 1 || 2:
        if (store.pending.isEmpty) break;
        final (id, key, value, done) = store.pending.removeAt(
          op[1] % store.pending.length,
        );
        if (op[0] == 1) {
          store.values[key] = value;
          store.dirty.remove(key);
          writes[id]!.landed = true;
          (landedOrder[key] ??= []).add(id);
          failedLast.remove(key);
          if (!covered(writes[id]!) && id > (kept[key] ?? -1)) kept[key] = id;
          done.complete();
        } else {
          failedLast.add(key);
          failedAt[key] = nextId - 1;
          done.completeError(StateError('write failed'));
        }
      case 3 || 4 || 5:
        final kind = ['clear', 'forget', 'others'][op[0] - 3];
        final user = op[0] == 3 ? null : _users[op[1]];
        final keep = op[0] == 4 ? keepOf(op[2]) : <String>{};
        final removal = _Removal(kind, user, keep, ++modelEpoch);
        removals.add(removal);
        if (store.keysMode != 'ok') {
          // The removal cannot list the keys: what it would delete stays.
          for (final key in store.values.keys) {
            final w = writes[_idOf(store.values[key]!)]!;
            if (removal.covers(w)) store.dirty.add(key);
          }
        }
        final f = switch (op[0]) {
          3 => cache.clear(),
          4 => cache.forgetUser(user!, keep: keep),
          _ => cache.forgetOthers(user!),
        };
        unawaited(f.then((_) {}, onError: (_) {}));
        if (cache.epoch != modelEpoch) {
          return 'step $step: epoch ${cache.epoch}, model $modelEpoch';
        }
      case 6:
        store.undeletable.add(_key(_users[op[1]], _queries[op[2]]));
      case 7:
        store.silent.add(_key(_users[op[1]], _queries[op[2]]));
      case 8:
        store
          ..undeletable.clear()
          ..silent.clear();
      case 9:
        store.keysMode = ['ok', 'fail', 'hang'][op[1]];
    }
    await Future<void>.delayed(Duration.zero);
    // Privacy: nothing covered stays once landed, but where a deletion failed.
    for (final MapEntry(:key, :value) in store.values.entries) {
      final w = writes[_idOf(value)]!;
      if (w.landed && covered(w) && !store.dirty.contains(key)) {
        return 'step $step: $key holds write #${w.id} (epoch ${w.epoch}), '
            'which a removal covers';
      }
    }
    // A failed write deletes its key, and leaves it unsettled until one
    // asked after the failure lands and is kept.
    for (final u in _users) {
      for (final q in _queries) {
        final key = _key(u, q);
        final unsettled =
            failedAt.containsKey(key) && (kept[key] ?? -1) <= failedAt[key]!;
        if (cache.unsettled(u, q) != unsettled) {
          return 'step $step: unsettled($u, $q) is ${!unsettled}, model '
              '$unsettled';
        }
        if (failedLast.contains(key) &&
            store.values.containsKey(key) &&
            !store.dirty.contains(key)) {
          return 'step $step: $key stays after its write failed';
        }
      }
    }
    // Loss: the last write landed of each key is there when nothing covers
    // it and no write with a higher number landed before it, nor failed
    // after it.
    for (final MapEntry(:key, value: order) in landedOrder.entries) {
      if (failedLast.contains(key)) continue;
      final last = writes[order.last]!;
      if (covered(last)) continue;
      if (order.any((id) => id > last.id)) continue;
      final held = store.values[key];
      final heldId = held == null ? null : _idOf(held);
      if (heldId != last.id && !store.dirty.contains(key)) {
        return 'step $step: $key should hold write #${last.id} '
            '(epoch ${last.epoch}), '
            'holds ${heldId == null ? 'nothing' : '#$heldId'}';
      }
    }
  }
  return null;
}

Future<List<_Op>> _shrink(List<_Op> ops) async {
  var current = ops;
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < current.length; i++) {
      final candidate = [...current]..removeAt(i);
      if (await _run(candidate) != null) {
        current = candidate;
        changed = true;
        break;
      }
    }
  }
  return current;
}

/// Sequences with forgetOthers at most once, as the app calls it (once per
/// run, at start-up).
List<_Op> _oncePerRun(List<_Op> ops) {
  var seen = false;
  return [
    for (final op in ops)
      if (op[0] != 5)
        op
      else if (!seen) ...[
        (() {
          seen = true;
          return op;
        })(),
      ],
  ];
}

/// How many random sequences a run checks: enough to meet the shortest
/// known failures of earlier designs many times over, in a few seconds.
const _sequences = 3000;

void main() {
  test('SwrCache agrees with the reference model over $_sequences random '
      'sequences (forgetOthers at most once per sequence)', () async {
    final random = Random(20261115);
    final failures = <String>{};
    for (var s = 0; s < _sequences; s++) {
      final ops = _oncePerRun([
        for (var i = 0, n = 5 + random.nextInt(36); i < n; i++)
          _randomOp(random),
      ]);
      if (await _run(ops) != null) {
        final shrunk = _oncePerRun(await _shrink(ops));
        final why = await _run(shrunk);
        failures.add('${shrunk.map(_show).join('; ')}\n  -> $why');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
