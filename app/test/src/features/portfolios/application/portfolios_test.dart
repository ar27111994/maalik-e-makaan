import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
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

/// The keys of Gulberg's saved records.
Iterable<String> _ofGulberg(TestApp app) =>
    app.store.values.keys.where((key) => key.contains('.p:${gulberg.id}.'));

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
      final saved = await app.cache.saved<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
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
      // Another account's copy, which its wipe could not delete, goes too.
      expect(keys(app), {cacheKey(testUserId, PortfoliosController.query)});
    });

    test("but not the user's profile and residence, which hold nothing of a "
        'portfolio, whether the list was saved or not', () async {
      for (final saved in [true, false]) {
        final app = TestApp(portfolios: [gulberg]);
        if (saved) {
          await app.cache.seed(testUserId, PortfoliosController.query, [
            gulberg.toRow(),
            plaza.toRow(),
          ]);
        }
        await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
        await app.cache.seed(testUserId, ProfileController.query, {});
        await app.cache.seed(testUserId, ResidenceController.query, {});
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(keys(app), {
          cacheKey(testUserId, PortfoliosController.query),
          cacheKey(testUserId, ProfileController.query),
          cacheKey(testUserId, ResidenceController.query),
        }, reason: saved ? 'a saved list' : 'no saved list');
      }
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
        contains(
          cacheKey(testUserId, 'tenants.${gulberg.id}', portfolio: gulberg.id),
        ),
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
      expect(keys(app), {cacheKey(testUserId, PortfoliosController.query)});
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
        final tenantsKey = cacheKey(
          testUserId,
          'tenants.${plaza.id}.active.',
          portfolio: plaza.id,
        );

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
        expect(keys(app), {cacheKey(testUserId, PortfoliosController.query)});
      });
    }

    test('the list goes on being saved after it', () async {
      final app = TestApp(portfolios: const [gulberg]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(keys(app), {cacheKey(testUserId, PortfoliosController.query)});
      await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      final saved = await app.cache.saved<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
        (json) => json,
      );
      expect((saved!.value! as List).length, 2);
    });

    test('a list that comes back after the device was wiped is neither kept '
        'nor shown, though a portfolio left it', () async {
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
      // The saved list stays on the ended session's screen until the status
      // comes; the answer is not shown.
      expect(
        container.read(portfoliosProvider(testUserId)).value!.source,
        SnapshotSource.cache,
      );
      expect(app.store.values, isEmpty);
      // Nor does a command ask for one after it.
      final asked = app.portfolios.calls.length;
      await expectLater(
        container.read(portfoliosProvider(testUserId).notifier).reload(),
        throwsA(isA<SessionExpired>()),
      );
      expect(app.portfolios.calls, hasLength(asked));
      expect(app.store.values, isEmpty);
    });

    test('a list kept alive across a sign-out reads nothing while signed '
        'out, and applies the lists of the next session', () async {
      final app = TestApp();
      final container = containerFor(app);
      // Held by a listener that outlives the session.
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), isNotNull);
      // The session ends: the wipe, then the signed-out status.
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(
        container.read(portfoliosProvider(testUserId)).error,
        isA<SessionExpired>(),
      );
      expect(app.store.values, isEmpty);
      // The same account signs in again; a record of Gulberg is opened.
      app.auth.emit(signedIn);
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), {gulberg.id, plaza.id});
      expect(_ofGulberg(app), isNotEmpty);
      // The user leaves Gulberg, and the list is read again.
      app.portfolios.memberships.removeWhere((m) => m.id == gulberg.id);
      await container.read(portfoliosProvider(testUserId).notifier).reload();
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), {plaza.id});
      expect(_ofGulberg(app), isEmpty);
    });

    test('a list kept alive while another account takes the session reads '
        'nothing for its own account', () async {
      final app = TestApp();
      final container = containerFor(app);
      // Held by a listener that outlives the session.
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), isNotNull);
      final asked = app.portfolios.calls.length;
      // An e-mail link of another account replaces the session: the wipe,
      // then that account's status, with no signed-out status between.
      await app.cache.clear();
      app.auth.emit(
        const SignedIn(
          userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
          email: 'sana.malik@example.com',
        ),
      );
      await pumpEventQueue();
      expect(
        container.read(portfoliosProvider(testUserId)).error,
        isA<SessionExpired>(),
      );
      // Nothing was asked for under the other account's session, and
      // nothing of the first account is known or saved again.
      expect(app.portfolios.calls, hasLength(asked));
      expect(app.cache.portfoliosOf(testUserId), isNull);
      expect(app.store.values, isEmpty);
    });

    test('a list that comes back after the device was wiped is neither kept '
        'nor shown', () async {
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
      expect(container.read(portfoliosProvider(testUserId)).hasValue, false);
      // Nor does a command ask for one after it.
      await expectLater(
        container.read(portfoliosProvider(testUserId).notifier).reload(),
        throwsA(isA<SessionExpired>()),
      );
      expect(app.store.values, isEmpty);
    });
  });

  group('a list answer that comes after a later one', () {
    final listKey = cacheKey(testUserId, PortfoliosController.query);
    final gulbergTenants = cacheKey(
      testUserId,
      'tenants.${gulberg.id}',
      portfolio: gulberg.id,
    );

    test('is neither saved nor shown, so a portfolio that left is not named '
        'again', () async {
      final app = TestApp(portfolios: const []);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      app.portfolios.scripted = true;
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.portfolios.answers[0].complete([gulberg, plaza]);
      await pumpEventQueue();
      final list = container.read(portfoliosProvider(testUserId).notifier);
      // Read before Gulberg left, answered after the next read.
      final earlier = list.reload();
      final later = list.reload();
      await pumpEventQueue();
      app.portfolios.answers[2].complete([plaza]);
      await later;
      expect(app.store.values.keys, [listKey]);
      app.portfolios.answers[1].complete([gulberg, plaza]);
      await earlier;
      expect(await _savedList(app), [plaza.toRow()]);
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        plaza,
      ]);
    });

    test('nor forgets the records of a portfolio the later one names, and '
        "the first load's late answer is not shown either", () async {
      final app = TestApp(portfolios: const []);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        plaza.toRow(),
      ]);
      app.portfolios.scripted = true;
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      // The first load's read is on its way when the user joins Gulberg
      // and the list is read again.
      final list = container.read(portfoliosProvider(testUserId).notifier);
      final later = list.reload();
      await pumpEventQueue();
      app.portfolios.answers[1].complete([gulberg, plaza]);
      await later;
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      app.portfolios.answers[0].complete([plaza]);
      await pumpEventQueue();
      expect(app.store.values.keys, containsAll([listKey, gulbergTenants]));
      expect(await _savedList(app), [gulberg.toRow(), plaza.toRow()]);
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        gulberg,
        plaza,
      ]);
    });
  });

  group('the portfolio chosen by a command across the end of the session '
      'is not kept on the device', () {
    test('creating', () async {
      final app = TestApp();
      final container = containerFor(app);
      await _current(container);
      app.portfolios.gate.close();
      final creating = container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      await pumpEventQueue();
      await DeviceDataWipe(
        cache: app.cache,
        settings: app.settings,
        scratch: app.scratch,
      ).wipe(WipeReason.signedOut);
      app.portfolios.gate.open();
      // Created on the server; its session has ended, so the list is not
      // asked for, and the caller hears why.
      await expectLater(creating, throwsA(isA<SessionExpired>()));
      expect(app.store.values, isEmpty);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
      expect(
        container.read(selectedPortfolioProvider(testUserId)),
        isNot('p-new'),
      );
    });

    test('nothing is chosen while the cache serves another account, or '
        'nobody', () async {
      final app = TestApp();
      final container = containerFor(app);
      await _current(container);
      final selected = container.read(
        selectedPortfolioProvider(testUserId).notifier,
      );
      // The wipe has begun; the status after it has not come.
      await app.cache.clear();
      await selected.select(plaza.id);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
      // Another account's status has come.
      app.auth.emit(
        const SignedIn(
          userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
          email: 'sana.malik@example.com',
        ),
      );
      await pumpEventQueue();
      await selected.select(plaza.id);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
    });

    test('but a portfolio created in the session is chosen', () async {
      final app = TestApp();
      final container = containerFor(app);
      await _current(container);
      await container
          .read(portfoliosProvider(testUserId).notifier)
          .create(name: 'Khan family', id: 'p-new');
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/p-new',
      );
    });
  });

  group('a command begun in its session, which ends during its request, '
      'asks for and shows nothing after', () {
    const other = SignedIn(
      userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
      email: 'sana.malik@example.com',
    );
    final commands =
        <(String, Future<Object?> Function(PortfoliosController), String)>[
          (
            'creating',
            (list) => list.create(name: 'Khan family', id: 'p-new'),
            'create',
          ),
          (
            'deleting',
            (list) => list.delete(plaza.id, confirmation: plaza.name),
            'delete',
          ),
          (
            'answering the owner-abroad question',
            (list) => list.answerOwnerAbroad(gulberg.id, abroad: true),
            'answerOwnerAbroad',
          ),
          ('reloading', (list) => list.reload(), 'listMine'),
        ];

    for (final (session, status) in <(String, AuthStatus)>[
      ('signed out', const SignedOut()),
      ('replaced by another account', other),
    ]) {
      for (final (name, command, request) in commands) {
        test('$name, $session', () async {
          final app = TestApp();
          final container = containerFor(app);
          listen(container, portfoliosProvider(testUserId));
          listen(container, currentPortfolioProvider);
          await pumpEventQueue();
          app.portfolios.gate.close();
          final running = command(
            container.read(portfoliosProvider(testUserId).notifier),
          );
          await pumpEventQueue();
          // The session ends while the request is on its way: the wipe,
          // then the status.
          await app.cache.clear();
          app.auth.emit(status);
          await pumpEventQueue();
          app.portfolios.gate.open();
          Object? outcome;
          try {
            outcome = await running;
          } on SessionExpired catch (expired) {
            outcome = expired;
          }
          await pumpEventQueue();
          // A command that asks for the list after its request reports the
          // expired session; the others return what the server answered.
          expect(
            outcome,
            request == 'create' || request == 'delete'
                ? isA<SessionExpired>()
                : isNot(isA<SessionExpired>()),
          );
          // Nothing was asked for the ended session after its request.
          expect(
            [
              for (final (name, arguments) in app.portfolios.calls)
                if (name != 'listMine' || arguments.first == testUserId) name,
            ],
            ['listMine', request],
          );
          expect(
            container.read(portfoliosProvider(testUserId)).error,
            isA<SessionExpired>(),
          );
          expect(app.cache.portfoliosOf(testUserId), isNull);
          expect(
            app.store.values.keys.where((key) => key.contains(testUserId)),
            isEmpty,
          );
          expect(
            app.settings.values[AppSettings.currentPortfolioKey],
            isNot(startsWith('$testUserId/')),
          );
        });
      }
    }
  });

  group('a command called when its user is not the one signed in asks for, '
      'shows and saves nothing', () {
    // A caller that read the user before a request of its own (leaving a
    // portfolio, changing one's own role) calls the list after it.
    const other = SignedIn(
      userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
      email: 'sana.malik@example.com',
    );
    final commands = <(String, Future<void> Function(PortfoliosController))>[
      ('reloading', (list) => list.reload()),
      ('creating', (list) => list.create(name: 'Khan family', id: 'p-new')),
      ('deleting', (list) => list.delete(plaza.id, confirmation: plaza.name)),
      (
        'answering the owner-abroad question',
        (list) => list.answerOwnerAbroad(gulberg.id, abroad: true),
      ),
    ];

    for (final (session, status) in <(String, AuthStatus)>[
      ('after the session ended', const SignedOut()),
      ('with another account signed in', other),
    ]) {
      for (final (name, command) in commands) {
        test('$name, $session', () async {
          final app = TestApp();
          final container = containerFor(app);
          // Held by a listener that outlives the session.
          listen(container, portfoliosProvider(testUserId));
          await pumpEventQueue();
          // The session ends, or is replaced: the wipe, then the status.
          await app.cache.clear();
          app.auth.emit(status);
          await pumpEventQueue();
          final asked = app.portfolios.calls.length;
          await expectLater(
            command(container.read(portfoliosProvider(testUserId).notifier)),
            throwsA(isA<SessionExpired>()),
          );
          await pumpEventQueue();
          expect(app.portfolios.calls, hasLength(asked));
          expect(app.cache.portfoliosOf(testUserId), isNull);
          expect(app.store.values, isEmpty);
          expect(
            app.settings.values,
            isNot(contains(AppSettings.currentPortfolioKey)),
          );
          expect(
            container.read(portfoliosProvider(testUserId)).error,
            isA<SessionExpired>(),
          );
        });
      }
    }

    test('nor on a list first read after the session ended', () async {
      final app = TestApp();
      final container = containerFor(app);
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      await expectLater(
        container.read(portfoliosProvider(testUserId).notifier).reload(),
        throwsA(isA<SessionExpired>()),
      );
      await pumpEventQueue();
      expect(app.portfolios.calls, isEmpty);
      expect(app.cache.portfoliosOf(testUserId), isNull);
      expect(app.store.values, isEmpty);
    });
  });

  group('a list made from the one on show is saved when that list was asked '
      'for in this session', () {
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
            false,
          ),
        ]) {
      for (final from in ['the saved list', 'the server', 'a reload']) {
        test('$name, the list on show from $from', () async {
          final app = TestApp();
          // A session ended before this one began: the epoch is not 0.
          await app.cache.clear();
          switch (from) {
            case 'the saved list':
              await app.cache.seed(testUserId, PortfoliosController.query, [
                gulberg.toRow(),
                plaza.toRow(),
              ]);
              app.portfolios.listFailure = const NetworkFailure();
            case 'a reload':
              // The first read never answers; a reload shows the list.
              app.portfolios.gate.close();
          }
          final container = containerFor(app);
          listen(container, portfoliosProvider(testUserId));
          await pumpEventQueue();
          final list = container.read(portfoliosProvider(testUserId).notifier);
          if (from == 'a reload') {
            app.portfolios.gate.holdLaterCallsApart();
            final reloading = list.reload();
            app.portfolios.gate.open();
            await reloading;
          }
          expect(
            container.read(portfoliosProvider(testUserId)).value,
            isNotNull,
          );
          if (offline) app.portfolios.listFailure = const NetworkFailure();
          final before = await _savedList(app);
          await command(list);
          final after = await _savedList(app);
          expect(after, isNotNull);
          expect(after, isNot(equals(before)));
        });
      }
    }
  });

  group('a list made from the one on show, after the device was wiped and '
      'while the list built anew has not loaded, is neither kept nor '
      'shown:', () {
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
        app.auth.emit(signedIn);
        await pumpEventQueue();
        final before = container.read(portfoliosProvider(testUserId)).value;
        expect(before, isNotNull);
        await command(container.read(portfoliosProvider(testUserId).notifier));
        expect(app.store.values, isEmpty);
        // Made from a list of the session that ended, it is not shown.
        expect(
          container.read(portfoliosProvider(testUserId)).value,
          same(before),
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
        app.auth.emit(signedIn);
        await pumpEventQueue();
        // Only then does the command's answer come.
        answerCommand();
        try {
          await running;
        } on SessionExpired {
          // It asks for the list after its request: not for a session that
          // has ended.
        }
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
      final saved = await app.cache.saved<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
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
      final saved = await app.cache.saved<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
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

/// The saved portfolio list of the test user, as stored, or null.
Future<List<Object?>?> _savedList(TestApp app) async =>
    (await app.cache.saved<Object?>(
          testUserId,
          PortfoliosController.query,
          scopeOf(PortfoliosController.query),
          (json) => json,
        ))?.value
        as List<Object?>?;
