import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';

import '../../support/fakes.dart'
    show FakeAuthRepository, ListAnswers, MemoryStore;

const _u1 = SignedIn(userId: 'u1', email: 'u1@example.com');
const _u2 = SignedIn(userId: 'u2', email: 'u2@example.com');

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

int _int(Object? json) => json! as int;

void main() {
  late MemoryStore store;
  late SwrCache cache;
  late FakeAuthRepository auth;
  late Completer<int> held;
  late ProviderContainer container;

  /// How many times the query was fetched.
  late int fetches;

  Iterable<String> saved() =>
      store.values.keys.where((key) => key.startsWith('mm.swr.'));

  setUp(() async {
    store = MemoryStore();
    cache = SwrCache(store);
    auth = FakeAuthRepository(_u1);
    held = Completer();
    fetches = 0;
    container = ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(auth),
        _answer.overrideWithValue(() {
          // The first fetch answers at once; later ones wait for the test.
          if (fetches++ == 0) return Future.value(1);
          return held.future;
        }),
      ],
    )..listen(_count, (_, _) {});
    await pumpEventQueue();
    expect(saved(), ['mm.swr.v2.u1.p:pA.count']);
  });

  test('a reload still on its way when the device is wiped neither saves '
      'nor shows what came back', () async {
    final reload = container.read(_count.notifier).reload();
    await pumpEventQueue();
    // The session ends: the device wipe clears the cache.
    await cache.clear();
    held.complete(2);
    await reload;
    expect(saved(), isEmpty);
    expect(container.read(_count).value!.value, 1);
  });

  test('a query built before the wipe asks for nothing after it', () async {
    await cache.clear();
    final notifier = container.read(_count.notifier);
    expect(notifier.requestEpoch, throwsA(isA<SessionExpired>()));
    expect(() => notifier.shownEpoch, throwsA(isA<SessionExpired>()));
    // A command's reload sends no request, and its command hears why.
    await expectLater(notifier.reload(), throwsA(isA<SessionExpired>()));
    expect(fetches, 1);
    expect(saved(), isEmpty);
    expect(container.read(_count).value!.value, 1);
  });

  test('an answer asked for before the wipe is not saved by the query built '
      'for the next session of the same account', () async {
    final notifier = container.read(_count.notifier);
    final asked = notifier.requestEpoch();
    await cache.clear();
    // The same account signs in again: the query is built again by itself.
    auth.emit(_u1);
    await pumpEventQueue();
    expect(fetches, 2);
    await notifier.show(9, epoch: asked);
    expect(saved(), isEmpty);
    expect(container.read(_count).value?.value, isNot(9));
  });

  test("a build's fetch that comes after the session changed saves "
      'nothing', () async {
    // Built again for a new session of the same account, whose fetch waits.
    await cache.clear();
    auth.emit(_u1);
    await pumpEventQueue();
    // Another account's session replaces it before the fetch comes back.
    await cache.clear();
    auth.emit(_u2);
    await pumpEventQueue();
    // Both builds' fetches answer: the earlier build's is saved for
    // nobody, the new session's build's for its own account.
    held.complete(7);
    await pumpEventQueue();
    expect(fetches, 3);
    expect(saved(), ['mm.swr.v2.u2.p:pA.count']);
  });

  Future<int?> savedCount() async => (await cache.read(
    'u1',
    'count',
    InPortfolio<int>('pA'),
    _int,
    epoch: cache.epoch,
  ))?.value;

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

  test(
    'a query built for the next session of the same account saves again',
    () async {
      await cache.clear();
      auth.emit(_u1);
      await pumpEventQueue();
      held.complete(4);
      await pumpEventQueue();
      expect(saved(), ['mm.swr.v2.u1.p:pA.count']);
      final notifier = container.read(_count.notifier);
      await notifier.show(5, epoch: notifier.requestEpoch());
      expect(await savedCount(), 5);
    },
  );

  group('in the session after a wipe, a value made from the one on show is '
      'saved', () {
    test('when the query built for it brought that one', () async {
      await cache.clear();
      auth.emit(_u1);
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
      auth.emit(_u1);
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

  group('sessionChanged: built for another account', () {
    test(
      'the value on show goes at once, not when its first answer comes',
      () async {
        await cache.clear();
        auth.emit(_u2);
        await pumpEventQueue();
        // Its fetch has not answered yet.
        final state = container.read(_count);
        expect(state.isLoading, isTrue);
        expect(state.value, isNull);
      },
    );

    test('and stays gone when its first answer fails', () async {
      await cache.clear();
      auth.emit(_u2);
      await pumpEventQueue();
      held.completeError(const Forbidden());
      await pumpEventQueue();
      final state = container.read(_count);
      expect(state.error, isA<Forbidden>());
      expect(state.value, isNull);
    });

    test(
      'or for nobody: the value on show goes when the user signs out',
      () async {
        await cache.clear();
        auth.emit(const SignedOut());
        await pumpEventQueue();
        expect(container.read(_count).value, isNull);
      },
    );

    test('and the value of a write whose late deletion answers after it is '
        'not put on show', () async {
      final notifier = container.read(_count.notifier);
      final epoch = notifier.requestEpoch();
      // The store holds the write; meanwhile pA leaves the list.
      store.holding.add('mm.swr.v2.u1.p:pA.count');
      final showing = notifier.show(5, epoch: epoch);
      await pumpEventQueue();
      expect(store.heldWrites, 1);
      await cache.answer('u1', const []);
      // The write lands: the cache no longer keeps it, and deletes it; the
      // store holds that deletion.
      final deletion = store.nextDeletionHeld = Completer();
      store.finishHeldWritesOldestFirst();
      await pumpEventQueue();
      expect(store.heldDeletions, 1);
      // u1 signs out and u2 signs in while it waits.
      await cache.clear();
      auth.emit(_u2);
      await pumpEventQueue();
      expect(container.read(_count).value, isNull);
      deletion.complete();
      await showing;
      await pumpEventQueue();
      expect(container.read(_count).value, isNull);
      expect(saved(), isEmpty);
    });

    test('for a new session of the same account, the value on show stays '
        'until the new one comes', () async {
      await cache.clear();
      auth.emit(_u1);
      await pumpEventQueue();
      expect(container.read(_count).value!.value, 1);
      held.complete(2);
      await pumpEventQueue();
      expect(container.read(_count).value!.value, 2);
    });
  });

  test("a build whose saved copy is read after another account's status "
      'comes asks for nothing', () async {
    final store = MemoryStore();
    final cache = SwrCache(store);
    final auth = FakeAuthRepository(_u1);
    final asked = <String>[];
    final reading = store.readsHeld = Completer();
    ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(auth),
        _answer.overrideWithValue(() {
          asked.add((auth.status as SignedIn).userId);
          return Completer<int>().future;
        }),
      ],
    ).listen(_count, (_, _) {});
    await pumpEventQueue();
    // u1's build waits for its saved copy; u1 signs out and u2 signs in.
    await cache.clear();
    store.readsHeld = null;
    auth.emit(_u2);
    await pumpEventQueue();
    expect(asked, ['u2']);
    // u1's read answers: its fetch would go out with u2's token.
    reading.complete();
    await pumpEventQueue();
    expect(asked, ['u2']);
  });

  test('nobody signed in: nothing is asked for, shown or saved', () async {
    final signedOut = ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(SwrCache(store)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    )..listen(_count, (_, _) {});
    await pumpEventQueue();
    store.values.clear();
    final notifier = signedOut.read(_count.notifier);
    expect(notifier.requestEpoch, throwsA(isA<SessionExpired>()));
    await notifier.show(5, epoch: 0);
    expect(saved(), isEmpty);
    expect(signedOut.read(_count).error, isA<SessionExpired>());
    expect(fetches, 1);
  });
}
