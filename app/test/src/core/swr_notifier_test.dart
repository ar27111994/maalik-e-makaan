import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';

import '../../support/fakes.dart' show ListAnswers, MemoryStore;

/// What the next fetch answers; a test holds it on a completer.
final _answer = Provider<Future<int> Function()>(
  (ref) =>
      () async => 1,
);

/// A query of a number, as the features' lists are queries of rows.
final class _Count extends SwrNotifier<int> {
  @override
  String get query => 'count';

  /// Of the portfolio 'pA', named before the fetch.
  @override
  RecordScope<int> get scope => InPortfolio('pA');

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
    expect(saved(), ['mm.swr.v2.u1.p:pA.count']);
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

  Future<int?> savedCount() async =>
      (await cache.read('u1', 'count', InPortfolio<int>('pA'), (json) {
        return json! as int;
      }))?.value;

  /// The server's list of u1's portfolios is [ids].
  Future<void> listIs(List<String> ids) => cache.answer('u1', ids);

  group('when its portfolio left the list', () {
    test('its saved copy goes, a reload still on its way saves nothing, and '
        'shows what came back', () async {
      final reload = container.read(_count.notifier).reload();
      await pumpEventQueue();
      await listIs(['pB']);
      expect(saved(), isEmpty);
      held.complete(2);
      await reload;
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 2);
    });

    test('a reload begun after it saves nothing, nor what is made from the '
        'value on show', () async {
      await listIs(['pB']);
      held.complete(3);
      final notifier = container.read(_count.notifier);
      await notifier.reload();
      expect(saved(), isEmpty);
      expect(container.read(_count).value!.value, 3);
      await notifier.show(4, epoch: notifier.shownEpoch);
      expect(saved(), isEmpty);
    });

    test('a query built again after it shows nothing saved', () async {
      await listIs(['pB']);
      container.invalidate(_count);
      await pumpEventQueue();
      held.completeError(const NetworkFailure());
      await pumpEventQueue();
      final state = container.read(_count);
      expect(state.hasError, isTrue);
      // The value of the build before stays on show; nothing came from the
      // device.
      expect(state.value!.value, 1);
      expect(state.value!.fromCache, isFalse);
      expect(saved(), isEmpty);
    });

    test('once it is back in the list, a reload is saved, and what is made '
        'from it', () async {
      await listIs(['pB']);
      await listIs(['pA', 'pB']);
      held.complete(5);
      final notifier = container.read(_count.notifier);
      await notifier.reload();
      expect(await savedCount(), 5);
      await notifier.show(6, epoch: notifier.shownEpoch);
      expect(await savedCount(), 6);
    });
  });

  group('when another portfolio left the list', () {
    test('a reload still on its way is saved', () async {
      await listIs(['pA', 'pB']);
      final reload = container.read(_count.notifier).reload();
      await pumpEventQueue();
      await listIs(['pA']);
      expect(saved(), ['mm.swr.v2.u1.p:pA.count']);
      held.complete(2);
      await reload;
      expect(await savedCount(), 2);
    });

    test('an answer asked for before it is saved, and so is what is made '
        'from the value on show', () async {
      await listIs(['pA', 'pB']);
      final notifier = container.read(_count.notifier);
      final asked = notifier.requestEpoch();
      await listIs(['pA']);
      await notifier.show(4, epoch: asked);
      expect(await savedCount(), 4);
      await notifier.show(5, epoch: notifier.shownEpoch);
      expect(await savedCount(), 5);
    });
  });

  test('a query built after the wipe saves again', () async {
    await cache.clear();
    container.invalidate(_count);
    await pumpEventQueue();
    held.complete(4);
    await pumpEventQueue();
    expect(saved(), ['mm.swr.v2.u1.p:pA.count']);
    final notifier = container.read(_count.notifier);
    await notifier.show(5, epoch: notifier.requestEpoch());
    expect(await savedCount(), 5);
  });

  group('in the session after a wipe, a value made from the one on show is '
      'saved', () {
    test('when the query built for it brought that one', () async {
      await cache.clear();
      container.invalidate(_count);
      await pumpEventQueue();
      held.complete(4);
      await pumpEventQueue();
      final notifier = container.read(_count.notifier);
      // "Load more": made from the value on show.
      await notifier.show(5, epoch: notifier.shownEpoch);
      expect(await savedCount(), 5);
    });

    test('when a reload brought that one', () async {
      await cache.clear();
      container.invalidate(_count);
      await pumpEventQueue();
      // The query built for the session cannot read the server...
      held.completeError(const NetworkFailure());
      await pumpEventQueue();
      expect(saved(), isEmpty);
      // ...and a reload can.
      held = Completer()..complete(6);
      final notifier = container.read(_count.notifier);
      await notifier.reload();
      expect(await savedCount(), 6);
      await notifier.show(7, epoch: notifier.shownEpoch);
      expect(await savedCount(), 7);
    });
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
