import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
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

  test('an answer asked for after the wipe, by a query built before it, is '
      'not saved', () async {
    await cache.clear();
    final notifier = container.read(_count.notifier);
    await notifier.show(3, epoch: notifier.requestEpoch());
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

  test('an answer asked for before the wipe is not saved by the query built '
      'for the next session', () async {
    final notifier = container.read(_count.notifier);
    final asked = notifier.requestEpoch();
    await cache.clear();
    // The same account signs in again: the query starts over.
    container.invalidate(_count);
    await pumpEventQueue();
    await notifier.show(9, epoch: asked);
    expect(saved(), isEmpty);
  });

  group('when a portfolio left the list', () {
    Future<int?> savedCount() async =>
        (await cache.read('u1', 'count', (json) => json! as int))?.value;

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
      expect(await savedCount(), 3);
    });

    test('an answer asked for before it is shown and not saved', () async {
      final notifier = container.read(_count.notifier);
      final asked = notifier.requestEpoch();
      await cache.forgetUser('u1', keep: 'portfolios');
      await notifier.show(4, epoch: asked);
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 4);
    });

    test('an answer asked for before it is not saved either when the query '
        'was built again before it came', () async {
      final notifier = container.read(_count.notifier);
      final asked = notifier.requestEpoch();
      await cache.forgetUser('u1', keep: 'portfolios');
      // The query starts over (a failed reload, a list that changed): the
      // same notifier, built in the new epoch.
      container.invalidate(_count);
      await pumpEventQueue();
      expect(notifier.requestEpoch(), greaterThan(asked));
      await notifier.show(9, epoch: asked);
      expect(saved(), isEmpty);
    });

    test('an answer asked for after it is saved, though the query was built '
        'before, and so is what is then made from it', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      final notifier = container.read(_count.notifier);
      await notifier.show(4, epoch: notifier.requestEpoch());
      expect(await savedCount(), 4);
      // A page added to it, a row of it changed.
      await notifier.show(5, epoch: notifier.shownEpoch);
      expect(await savedCount(), 5);
    });

    test('a value made from the one on show since before it is shown and '
        'not saved', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      final notifier = container.read(_count.notifier);
      // A page asked for now, added to rows whose saved copy was removed.
      await notifier.show(
        container.read(_count).value!.value + 10,
        epoch: notifier.shownEpoch,
      );
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 11);
      // Nor is what is made from that one.
      await notifier.show(12, epoch: notifier.shownEpoch);
      expect(saved(), isEmpty);
    });

    test('nor is it once the query was built again and could not be read: '
        'the value on show is still the old one', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      container.invalidate(_count);
      await pumpEventQueue();
      held.completeError(const NetworkFailure());
      await pumpEventQueue();
      final state = container.read(_count);
      expect(state.hasError, isTrue);
      expect(state.value!.value, 1);
      final notifier = container.read(_count.notifier);
      await notifier.show(state.value!.value + 10, epoch: notifier.shownEpoch);
      expect(saved(), isEmpty);
    });

    test('a value made from the one a reload brought after it is '
        'saved', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      held.complete(3);
      final notifier = container.read(_count.notifier);
      await notifier.reload();
      await notifier.show(13, epoch: notifier.shownEpoch);
      expect(await savedCount(), 13);
    });

    test('a query built after it saves what it shows, and what is made from '
        'that', () async {
      await cache.forgetUser('u1', keep: 'portfolios');
      container.invalidate(_count);
      await pumpEventQueue();
      held.complete(7);
      await pumpEventQueue();
      expect(await savedCount(), 7);
      final notifier = container.read(_count.notifier);
      await notifier.show(8, epoch: notifier.shownEpoch);
      expect(await savedCount(), 8);
    });
  });

  test('a query built after the wipe saves again', () async {
    await cache.clear();
    container.invalidate(_count);
    await pumpEventQueue();
    held.complete(4);
    await pumpEventQueue();
    expect(saved(), ['mm.swr.v1.u1.count']);
    final notifier = container.read(_count.notifier);
    await notifier.show(5, epoch: notifier.requestEpoch());
    final entry = await cache.read('u1', 'count', (json) => json! as int);
    expect(entry!.value, 5);
  });

  test('nobody signed in: nothing is shown or saved', () async {
    final signedOut = ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(cache),
        currentUserIdProvider.overrideWithValue(null),
      ],
    )..listen(_count, (_, _) {});
    await pumpEventQueue();
    store.values.clear();
    final notifier = signedOut.read(_count.notifier);
    await notifier.show(5, epoch: notifier.requestEpoch());
    expect(saved(), isEmpty);
    expect(signedOut.read(_count).hasValue, isFalse);
  });
}
