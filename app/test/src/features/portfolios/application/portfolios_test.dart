import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

/// Waits until [container]'s current portfolio has settled.
Future<AsyncValue<PortfolioMembership?>> _current(ProviderContainer container) {
  listen(container, currentPortfolioProvider);
  return pumpEventQueue().then((_) => container.read(currentPortfolioProvider));
}

void main() {
  group('the list', () {
    test('shows the saved copy first, then the server one', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
      ]);
      app.portfolios.gate.close();
      final container = containerFor(app);
      final states = <AsyncValue<Snapshot<List<PortfolioMembership>>>>[];
      container.listen(
        portfoliosProvider(testUserId),
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(states.last.value!.value, [gulberg]);
      expect(states.last.value!.fromCache, isTrue);
      app.portfolios.gate.open();
      await pumpEventQueue();
      expect(states.last.value!.value, [gulberg, plaza]);
      expect(states.last.value!.source, SnapshotSource.network);
      // The fresh list is saved for next time.
      final saved = await app.cache.read(
        testUserId,
        PortfoliosController.query,
        (json) => json,
      );
      expect((saved!.value! as List).length, 2);
    });

    test('a failed refresh keeps the saved copy next to the error', () async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      await app.cache.seed(testUserId, PortfoliosController.query, [
        plaza.toRow(),
      ]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final state = container.read(portfoliosProvider(testUserId));
      expect(state.error, isA<NetworkFailure>());
      expect(state.value!.value, [plaza]);
    });

    test('a corrupt saved copy is ignored', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, PortfoliosController.query, {
        'not': 'a list',
      });
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        gulberg,
        plaza,
      ]);
    });
  });

  group('a portfolio gone from the list', () {
    Set<String> keys(TestApp app) => app.store.values.keys.toSet();

    test('takes the saved copies of the records with it', () async {
      // Deleted by its owner, or the user was removed from it.
      final app = TestApp(portfolios: [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      await app.cache.seed(testUserId, 'tenant.someone', 1);
      await app.cache.seed('another-user', 'tenants.${plaza.id}', [1]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        gulberg,
      ]);
      expect(keys(app), {
        'mm.swr.v1.$testUserId.${PortfoliosController.query}',
        'mm.swr.v1.another-user.tenants.${plaza.id}',
      });
    });

    test('a list that only grew keeps them', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
      ]);
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(
        keys(app),
        contains('mm.swr.v1.$testUserId.tenants.${gulberg.id}'),
      );
    });

    test('deleting one takes them too', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      await container
          .read(portfoliosProvider(testUserId).notifier)
          .delete(plaza.id, confirmation: plaza.name);
      expect(keys(app), {
        'mm.swr.v1.$testUserId.${PortfoliosController.query}',
      });
    });

    for (final stillShown in [true, false]) {
      test('a list of its records asked for before, which comes back after, '
          'is not saved, and the next start finds nothing (its screen '
          '${stillShown ? 'still' : 'no longer'} shown)', () async {
        // The server: the user is no longer in plaza.
        final app = TestApp(portfolios: const [gulberg]);
        // The tenants were asked for before the removal and answered then
        // (the fake has no row-level security): the answer carries plaza's.
        app.tenants.byPortfolio[plaza.id] = [aliRaza];
        // The device's list from before the removal.
        await app.cache.seed(testUserId, PortfoliosController.query, [
          gulberg.toRow(),
          plaza.toRow(),
        ]);
        final tenantsKey = 'mm.swr.v1.$testUserId.tenants.${plaza.id}.active.';

        final container = containerFor(app);
        app.tenants.gate.close();
        final shown = listen(
          container,
          tenantsProvider((portfolioId: plaza.id, archived: false, search: '')),
        );
        await pumpEventQueue();
        expect(app.tenants.calls, hasLength(1), reason: 'request on its way');

        // The portfolio list refreshes: plaza is gone, its records go.
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(container.read(portfoliosProvider(testUserId)).value!.value, [
          gulberg,
        ]);
        expect(keys(app), isNot(contains(tenantsKey)));

        if (!stillShown) shown.close();
        await pumpEventQueue();
        // The tenants' answer arrives.
        app.tenants.gate.open();
        await pumpEventQueue();
        expect(keys(app), isNot(contains(tenantsKey)));

        // The next start: the saved list no longer has plaza, so nothing
        // would find a copy left behind.
        container.dispose();
        listen(containerFor(app), portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(keys(app), {
          'mm.swr.v1.$testUserId.${PortfoliosController.query}',
        });
      });
    }

    for (final (why, refuse) in <(String, void Function(TestApp, String))>[
      ('cannot be deleted', (app, key) => app.store.undeletable.add(key)),
      (
        'was not deleted before the app closed',
        (app, key) => app.store.silent.add(key),
      ),
    ]) {
      test('is still named by the saved list while a copy of its records '
          '$why, and the next start forgets them', () async {
        final app = TestApp(portfolios: const [gulberg]);
        await app.cache.seed(testUserId, PortfoliosController.query, [
          gulberg.toRow(),
          plaza.toRow(),
        ]);
        await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
        await app.cache.seed(testUserId, 'leases.${plaza.id}', [1]);
        const listKey = 'mm.swr.v1.$testUserId.${PortfoliosController.query}';
        final stuck = 'mm.swr.v1.$testUserId.tenants.${plaza.id}';
        refuse(app, stuck);

        Future<List<Object?>> savedList() async => (await app.cache.read(
          testUserId,
          PortfoliosController.query,
          (json) => json! as List,
        ))!.value;

        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        // The other copies went; the list was not saved without plaza.
        expect(keys(app), {listKey, stuck});
        expect(await savedList(), hasLength(2));

        // The next start, with a store that answers.
        container.dispose();
        app
          ..store.undeletable.clear()
          ..store.silent.clear()
          ..cache = SwrCache(app.store);
        final next = containerFor(app);
        listen(next, portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(keys(app), {listKey});
        expect(await savedList(), hasLength(1));
        expect(next.read(portfoliosProvider(testUserId)).value!.value, [
          gulberg,
        ]);
      });
    }

    test('a list that could not be saved for it is shown all the same, and '
        'the next save forgets what was left', () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      const listKey = 'mm.swr.v1.$testUserId.${PortfoliosController.query}';
      final stuck = 'mm.swr.v1.$testUserId.tenants.${plaza.id}';
      app.store.undeletable.add(stuck);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final shown = container.read(portfoliosProvider(testUserId)).value!;
      expect(shown.value, [gulberg]);
      expect(shown.source, SnapshotSource.network);
      expect(shown.savedAt.isUtc, isTrue);
      expect(keys(app), {listKey, stuck});

      // The list on show no longer names plaza; the saved one does.
      app.store.undeletable.clear();
      await container.read(portfoliosProvider(testUserId).notifier).reload();
      expect(keys(app), {listKey});
      final saved = await app.cache.read(
        testUserId,
        PortfoliosController.query,
        (json) => json! as List,
      );
      expect(saved!.value, hasLength(1));
    });

    test('the list goes on being saved after it', () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(keys(app), {
        'mm.swr.v1.$testUserId.${PortfoliosController.query}',
      });
      await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      final saved = await app.cache.read(
        testUserId,
        PortfoliosController.query,
        (json) => json,
      );
      expect((saved!.value! as List).length, 2);
    });

    test('a list that comes back after the device was wiped is not kept, '
        'though a portfolio left it', () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      app.portfolios.gate.close();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      // The session ends while the list loads.
      await app.cache.clear();
      app.portfolios.gate.open();
      await pumpEventQueue();
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        gulberg,
      ]);
      expect(app.store.values, isEmpty);
      // Nor one a command shows after it.
      await container.read(portfoliosProvider(testUserId).notifier).reload();
      expect(app.store.values, isEmpty);
    });

    test(
      'a list that comes back after the device was wiped is not kept',
      () async {
        final app = TestApp();
        app.portfolios.gate.close();
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        // The session ends while the list loads.
        await app.cache.clear();
        app.portfolios.gate.open();
        await pumpEventQueue();
        expect(app.store.values, isEmpty);
        // Nor one a command shows after it.
        await container.read(portfoliosProvider(testUserId).notifier).reload();
        expect(app.store.values, isEmpty);
      },
    );
  });

  group('saves of the list that meet', () {
    const listKey = 'mm.swr.v1.$testUserId.${PortfoliosController.query}';

    Future<List<Object?>?> savedList(TestApp app) async =>
        (await app.cache.read(
          testUserId,
          PortfoliosController.query,
          (json) => json! as List,
        ))?.value;

    /// Lets the store finish every write it holds, the newest first, until
    /// no more come.
    Future<void> finishWrites(TestApp app) async {
      await pumpEventQueue();
      while (app.store.heldWrites > 0) {
        app.store.finishHeldWritesNewestFirst();
        await pumpEventQueue();
      }
    }

    test('land in the order they were asked, so a portfolio that leaves '
        'later still takes its records', () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
      ]);
      app.store.holding.add(listKey);
      final container = containerFor(app);
      // The list loads, and its save is on its way...
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      // ...when the user joins plaza and the list is read again.
      app.portfolios.memberships.add(plaza);
      final list = container.read(portfoliosProvider(testUserId).notifier);
      final reloading = list.reload();
      // The store finishes the later write first.
      await finishWrites(app);
      await reloading;
      app.store.holding.clear();
      expect(await savedList(app), hasLength(2));

      // plaza's records are saved, and then plaza leaves.
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      app.portfolios.memberships.remove(plaza);
      await list.reload();
      expect(app.store.values.keys, [listKey]);
    });

    test('a save that fails holds up none after it', () async {
      final app = TestApp(portfolios: const [gulberg]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final list = container.read(portfoliosProvider(testUserId).notifier);
      app.store.writeFailure = Exception('full');
      await expectLater(list.reload(), throwsException);
      app.store.writeFailure = null;
      app.portfolios.memberships.add(plaza);
      await list.reload();
      expect(await savedList(app), hasLength(2));
    });

    test('a save that waited for another is still not kept when the device '
        'was wiped meanwhile', () async {
      final app = TestApp(portfolios: const [gulberg]);
      app.store.holding.add(listKey);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final reloading = container
          .read(portfoliosProvider(testUserId).notifier)
          .reload();
      await pumpEventQueue();
      expect(app.store.heldWrites, 1, reason: 'the second save waits');
      // The session ends while both are on their way.
      await app.cache.clear();
      await finishWrites(app);
      await reloading;
      expect(app.store.values, isEmpty);
    });

    test('one stuck before the device was wiped does not hold up the next '
        "session's", () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      // plaza's records cannot be forgotten: the save waits on the store.
      app.store.silent.add('mm.swr.v1.$testUserId.tenants.${plaza.id}');
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(container.read(portfoliosProvider(testUserId)).hasValue, isTrue);
      expect(
        container.read(portfoliosProvider(testUserId)).value!.fromCache,
        isTrue,
      );
      // The session ends; the store still has not answered for plaza.
      app.store.silent.clear();
      await app.cache.clear();
      container
        ..invalidate(portfoliosProvider(testUserId))
        ..read(portfoliosProvider(testUserId));
      await pumpEventQueue();
      final shown = container.read(portfoliosProvider(testUserId)).value!;
      expect(shown.value, [gulberg]);
      expect(shown.source, SnapshotSource.network);
      expect(await savedList(app), hasLength(1));
    });
  });

  group('a list made from the one on show, after the device was wiped and '
      'while the list built anew has not loaded, is not kept:', () {
    for (final (name, command)
        in <(String, Future<void> Function(PortfoliosController))>[
          ('creating', (list) => list.create(name: 'Khan family', id: 'p-new')),
          (
            'deleting',
            (list) => list.delete(plaza.id, confirmation: plaza.name),
          ),
          (
            'answering the owner-abroad question',
            (list) => list.answerOwnerAbroad(gulberg.id, abroad: true),
          ),
        ]) {
      test(name, () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        // The session ends, the same account signs in again, and the list
        // is built anew by a read that fails: the old list stays on show.
        await app.cache.clear();
        app.portfolios.listFailure = const NetworkFailure();
        container
          ..invalidate(portfoliosProvider(testUserId))
          ..read(portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(container.read(portfoliosProvider(testUserId)).value, isNotNull);
        await command(container.read(portfoliosProvider(testUserId).notifier));
        expect(app.store.values, isEmpty);
        // The list is shown all the same.
        expect(
          container.read(portfoliosProvider(testUserId)).value!.source,
          SnapshotSource.network,
        );
      });
    }
  });

  group('a list a command asked for before the device was wiped is not kept '
      'by the list built again for the next session:', () {
    for (final (name, command, offline)
        in <(String, Future<void> Function(PortfoliosController), bool)>[
          (
            'creating',
            (list) => list.create(name: 'Khan family', id: 'p-new'),
            true,
          ),
          (
            'deleting',
            (list) => list.delete(plaza.id, confirmation: plaza.name),
            true,
          ),
          (
            'answering the owner-abroad question',
            (list) => list.answerOwnerAbroad(gulberg.id, abroad: true),
            true,
          ),
          ('reading again', (list) => list.reload(), false),
        ]) {
      test(name, () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        final list = container.read(portfoliosProvider(testUserId).notifier);
        // The command's request is on its way, and stays there...
        final gate = app.portfolios.gate..close();
        final running = command(list);
        await pumpEventQueue();
        // ...while the session ends.
        await app.cache.clear();
        // The same account signs in again and the list is built anew, by a
        // read that brings nothing: it fails, or does not answer.
        final void Function() answerCommand;
        if (offline) {
          app.portfolios.listFailure = const NetworkFailure();
          answerCommand = gate.open;
        } else {
          answerCommand = gate.holdLaterCallsApart();
        }
        container
          ..invalidate(portfoliosProvider(testUserId))
          ..read(portfoliosProvider(testUserId));
        await pumpEventQueue();
        // Only then does the command's answer come.
        answerCommand();
        await running;
        await pumpEventQueue();
        expect(app.store.values, isEmpty);
      });
    }
  });

  group('the current portfolio', () {
    test('is the first by name until one is chosen', () async {
      final container = containerFor(TestApp());
      expect((await _current(container)).value, gulberg);
      expect(container.read(portfolioGateProvider), PortfolioGate.some);
    });

    test('is remembered on the device, per user', () async {
      final app = TestApp(
        settings: {AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}'},
      );
      final container = containerFor(app);
      expect((await _current(container)).value, plaza);
      await container
          .read(selectedPortfolioProvider(testUserId).notifier)
          .select(gulberg.id);
      expect(container.read(currentPortfolioProvider).value, gulberg);
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${gulberg.id}',
      );
    });

    test("another user's choice is not this user's", () async {
      final app = TestApp(
        settings: {AppSettings.currentPortfolioKey: 'someone-else/${plaza.id}'},
      );
      final container = containerFor(app);
      expect(container.read(selectedPortfolioProvider(testUserId)), isNull);
      expect((await _current(container)).value, gulberg);
    });

    test('a portfolio the user left falls back to the first', () async {
      final app = TestApp(
        portfolios: const [plaza],
        settings: {
          AppSettings.currentPortfolioKey: '$testUserId/${gulberg.id}',
        },
      );
      expect((await _current(containerFor(app))).value, plaza);
    });

    test('stays on the saved copy when the refresh fails', () async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      await app.cache.seed(testUserId, PortfoliosController.query, [
        plaza.toRow(),
      ]);
      final container = containerFor(app);
      final current = await _current(container);
      expect(current.value, plaza);
      expect(current.hasError, isFalse);
      expect(container.read(portfolioGateProvider), PortfolioGate.some);
    });

    test('without a saved copy, a failure is the error', () async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      final container = containerFor(app);
      final current = await _current(container);
      expect(current.error, isA<NetworkFailure>());
      expect(container.read(portfolioGateProvider), PortfolioGate.unknown);
    });

    test('is null without portfolios, so the gate asks for one', () async {
      final container = containerFor(TestApp(portfolios: const []));
      expect((await _current(container)).value, isNull);
      expect(container.read(portfolioGateProvider), PortfolioGate.none);
    });

    test('is unknown while signed out or loading', () async {
      final signedOut = containerFor(TestApp(auth: const SignedOut()));
      expect(signedOut.read(currentPortfolioProvider).isLoading, isTrue);
      expect(signedOut.read(portfolioGateProvider), PortfolioGate.unknown);

      final app = TestApp()..portfolios.gate.close();
      final loading = containerFor(app);
      expect((await _current(loading)).isLoading, isTrue);
      expect(loading.read(portfolioGateProvider), PortfolioGate.unknown);
      app.portfolios.gate.open();
    });

    test('follows the signed-in user', () async {
      final app = TestApp();
      final container = containerFor(app);
      expect((await _current(container)).value, gulberg);
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(container.read(portfolioGateProvider), PortfolioGate.unknown);
    });

    test('pickCurrent', () {
      expect(pickCurrent(const [], 'x'), isNull);
      expect(pickCurrent(const [gulberg, plaza], plaza.id), plaza);
      expect(pickCurrent(const [gulberg, plaza], null), gulberg);
    });
  });

  group('creating', () {
    test('lists the new portfolio and makes it current', () async {
      final app = TestApp(portfolios: const []);
      final container = containerFor(app);
      await _current(container);
      final created = await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      expect(created.name, 'Khan family');
      expect(created.role, MemberRole.owner);
      // No answer chosen in advance.
      expect(
        app.portfolios.calls.firstWhere((call) => call.$1 == 'create').$2,
        ['Khan family', 'p-new', OwnerAbroad.notAnswered],
      );
      expect(container.read(currentPortfolioProvider).value, created);
      expect(container.read(portfolioGateProvider), PortfolioGate.some);
      final saved = await app.cache.read(
        testUserId,
        PortfoliosController.query,
        (json) => json,
      );
      expect((saved!.value! as List).single, created.toRow());
    });

    test(
      'when the list cannot refresh, the new one joins the known ones',
      () async {
        final app = TestApp(portfolios: const [plaza]);
        final container = containerFor(app);
        await _current(container);
        app.portfolios.listFailure = const NetworkFailure();
        final created = await container
            .read(portfoliosProvider(testUserId).notifier)
            .create(name: 'Abbottabad cottage', id: 'p-new');
        expect(container.read(portfoliosProvider(testUserId)).value!.value, [
          created,
          plaza,
        ]);
        expect(container.read(currentPortfolioProvider).value, created);
      },
    );

    test('a refusal changes nothing', () async {
      final app = TestApp();
      final container = containerFor(app);
      await _current(container);
      app.portfolios.gate.failure = const RejectedFailure(
        'portfolio_limit_reached',
      );
      await expectLater(
        container
            .read(portfoliosProvider(testUserId).notifier)
            .create(name: 'x', id: 'p-new'),
        throwsA(isA<RejectedFailure>()),
      );
      expect(container.read(currentPortfolioProvider).value, gulberg);
    });
  });

  group('the owner-abroad question', () {
    test('is answered at creation when the creator answers', () async {
      final app = TestApp(portfolios: const []);
      final container = containerFor(app);
      await _current(container);
      final created = await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(
            name: 'Khan family',
            id: 'p-new',
            ownerAbroad: OwnerAbroad.abroad,
          );
      expect(created.ownerAbroad, OwnerAbroad.abroad);
      expect(container.read(ownerAbroadQuestionProvider), isNull);
    });

    test("is never filled in from the creator's residence", () async {
      final app = TestApp(portfolios: const [])
        ..residences.residence = AccountResidence(
          residence: Residence(
            country: CountryCode.parse('GB'),
            timeZone: TimeZoneId.parse('Europe/London'),
          ),
          statedAt: DateTime.utc(2026, 11, 2),
        );
      final container = containerFor(app);
      await _current(container);
      final created = await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      expect(created.ownerAbroad, OwnerAbroad.notAnswered);
      expect(container.read(ownerAbroadQuestionProvider), 'p-new');
    });

    test(
      'is asked of owners and managers of an unanswered portfolio',
      () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, ownerAbroadQuestionProvider);
        await _current(container);
        expect(container.read(ownerAbroadQuestionProvider), gulberg.id);
        await container
            .read(selectedPortfolioProvider(testUserId).notifier)
            .select(plaza.id);
        expect(container.read(ownerAbroadQuestionProvider), plaza.id);
      },
    );

    test('is not asked of accountants and viewers, or once answered', () async {
      for (final membership in [
        gulbergAsViewer,
        const PortfolioMembership(
          id: 'p-accounts',
          name: 'Accounts',
          role: MemberRole.accountant,
        ),
        gulberg.withOwnerAbroad(OwnerAbroad.inPakistan),
        gulberg.withOwnerAbroad(OwnerAbroad.abroad),
      ]) {
        final container = containerFor(TestApp(portfolios: [membership]));
        listen(container, ownerAbroadQuestionProvider);
        await _current(container);
        expect(
          container.read(ownerAbroadQuestionProvider),
          isNull,
          reason: '$membership',
        );
      }
    });

    test(
      'is not asked from a saved copy, only once the server answered',
      () async {
        final app = TestApp();
        await app.cache.seed(testUserId, PortfoliosController.query, [
          gulberg.toRow(),
        ]);
        app.portfolios.gate.close();
        final container = containerFor(app);
        listen(container, ownerAbroadQuestionProvider);
        await _current(container);
        expect(container.read(currentPortfolioProvider).value, gulberg);
        expect(container.read(ownerAbroadQuestionProvider), isNull);
        app.portfolios.gate.open();
        await pumpEventQueue();
        expect(container.read(ownerAbroadQuestionProvider), gulberg.id);
      },
    );

    test('is not asked while signed out or without portfolios', () async {
      final signedOut = containerFor(TestApp(auth: const SignedOut()));
      expect(signedOut.read(ownerAbroadQuestionProvider), isNull);
      final none = containerFor(TestApp(portfolios: const []));
      listen(none, ownerAbroadQuestionProvider);
      await _current(none);
      expect(none.read(ownerAbroadQuestionProvider), isNull);
      final loading = TestApp()..portfolios.gate.close();
      final whileLoading = containerFor(loading);
      listen(whileLoading, ownerAbroadQuestionProvider);
      await pumpEventQueue();
      expect(whileLoading.read(ownerAbroadQuestionProvider), isNull);
    });

    test('an answer shows in the list and ends the question', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, ownerAbroadQuestionProvider);
      await _current(container);
      final answer = await container
          .read(portfoliosProvider(testUserId).notifier)
          .answerOwnerAbroad(gulberg.id, abroad: true);
      expect(answer, OwnerAbroad.abroad);
      expect(app.portfolios.calls.last.$2, [gulberg.id, true]);
      final list = container.read(portfoliosProvider(testUserId)).value!;
      expect(list.value.first.ownerAbroad, OwnerAbroad.abroad);
      expect(list.value.last, plaza);
      expect(container.read(ownerAbroadQuestionProvider), isNull);
      final saved = await app.cache.read(
        testUserId,
        PortfoliosController.query,
        (json) => json,
      );
      expect((saved!.value! as List).first, list.value.first.toRow());
    });

    test('a stale question gets the answer someone else gave', () async {
      final app = TestApp();
      final container = containerFor(app);
      await _current(container);
      // A co-owner answered on another device after this list was read.
      app.portfolios.memberships[0] = gulberg.withOwnerAbroad(
        OwnerAbroad.inPakistan,
      );
      final answer = await container
          .read(portfoliosProvider(testUserId).notifier)
          .answerOwnerAbroad(gulberg.id, abroad: true);
      expect(answer, OwnerAbroad.inPakistan);
      expect(
        container.read(currentPortfolioProvider).value!.ownerAbroad,
        OwnerAbroad.inPakistan,
      );
    });

    test('answering before the list loaded only answers', () async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final answer = await container
          .read(portfoliosProvider(testUserId).notifier)
          .answerOwnerAbroad(gulberg.id, abroad: false);
      expect(answer, OwnerAbroad.inPakistan);
      expect(container.read(portfoliosProvider(testUserId)).hasError, isTrue);
    });

    test('a refused answer throws and changes nothing', () async {
      final app = TestApp()..portfolios.ownerAbroadFailure = const Forbidden();
      final container = containerFor(app);
      await _current(container);
      await expectLater(
        container
            .read(portfoliosProvider(testUserId).notifier)
            .answerOwnerAbroad(gulberg.id, abroad: true),
        throwsA(isA<Forbidden>()),
      );
      expect(container.read(currentPortfolioProvider).value, gulberg);
    });
  });

  test('the user id comes from the session', () {
    final container = containerFor(TestApp(auth: const SignedOut()));
    expect(container.read(currentUserIdProvider), isNull);
  });
}
