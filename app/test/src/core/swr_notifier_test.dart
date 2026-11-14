import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';

import '../../support/fakes.dart' show MemoryStore;

/// What the next fetch answers; a test holds it on a completer.
final _answer = Provider<Future<int> Function()>(
  (ref) =>
      () async => 1,
);

/// A query of a number, as the features' lists are queries of rows.
final class _Count extends SwrNotifier<int> {
  @override
  String get query => 'count';

  @override
  Future<int> fetch() => ref.read(_answer)();

  @override
  int decode(Object? json) => json! as int;

  @override
  Object? encode(int value) => value;
}

final _count = StreamNotifierProvider<_Count, Snapshot<int>>(_Count.new);

void main() {
  late MemoryStore store;
  late SwrCache cache;
  late Completer<int> held;
  late ProviderContainer container;

  Iterable<String> saved() =>
      store.values.keys.where((key) => key.startsWith('mm.swr.'));

  setUp(() async {
    store = MemoryStore();
    cache = SwrCache(store);
    held = Completer();
    var first = true;
    container = ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(cache),
        currentUserIdProvider.overrideWithValue('u1'),
        _answer.overrideWithValue(() {
          // The first fetch answers at once; later ones wait for the test.
          if (first) {
            first = false;
            return Future.value(1);
          }
          return held.future;
        }),
      ],
    )..listen(_count, (_, _) {});
    await pumpEventQueue();
    expect(saved(), ['mm.swr.v1.u1.count']);
  });

  test('a reload still on its way when the device is wiped saves nothing, '
      'and shows what came back', () async {
    final reload = container.read(_count.notifier).reload();
    await pumpEventQueue();
    // The session ends: the device wipe clears the cache.
    await cache.clear();
    held.complete(2);
    await reload;
    expect(saved(), isEmpty);
    expect(container.read(_count).value!.value, 2);
  });

  test('a value shown after the wipe is not saved', () async {
    await cache.clear();
    await container.read(_count.notifier).show(3);
    expect(saved(), isEmpty);
    expect(container.read(_count).value!.value, 3);
  });

  test('a reload begun after the wipe, by a query built before it, saves '
      'nothing', () async {
    await cache.clear();
    held.complete(6);
    await container.read(_count.notifier).reload();
    expect(saved(), isEmpty);
    expect(container.read(_count).value!.value, 6);
  });

  group('when a portfolio left the list', () {
    test('a reload still on its way saves nothing, and shows what came '
        'back', () async {
      final reload = container.read(_count.notifier).reload();
      await pumpEventQueue();
      await cache.forgetUser('u1', keep: 'portfolios');
      expect(saved(), isEmpty);
      held.complete(2);
      await reload;
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 2);
    });

    test('a reload begun after it is saved, though the query was built '
        'before', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      held.complete(3);
      await container.read(_count.notifier).reload();
      final entry = await cache.read('u1', 'count', (json) => json! as int);
      expect(entry!.value, 3);
    });

    test('a value shown without its epoch is not saved: it may have been '
        'asked for before', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      await container.read(_count.notifier).show(4);
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 4);
      // With the epoch read before it was asked for, it is.
      await container.read(_count.notifier).show(5, epoch: cache.epoch);
      final entry = await cache.read('u1', 'count', (json) => json! as int);
      expect(entry!.value, 5);
    });

    test('a query built after it saves what it shows', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      container.invalidate(_count);
      await pumpEventQueue();
      held.complete(7);
      await pumpEventQueue();
      await container.read(_count.notifier).show(8);
      final entry = await cache.read('u1', 'count', (json) => json! as int);
      expect(entry!.value, 8);
    });
  });

  test('a query built after the wipe saves again', () async {
    await cache.clear();
    container.invalidate(_count);
    await pumpEventQueue();
    held.complete(4);
    await pumpEventQueue();
    expect(saved(), ['mm.swr.v1.u1.count']);
    await container.read(_count.notifier).show(5);
    final entry = await cache.read('u1', 'count', (json) => json! as int);
    expect(entry!.value, 5);
  });
}
