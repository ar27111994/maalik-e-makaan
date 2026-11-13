import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
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
      await app.cache.write(testUserId, PortfoliosController.query, [
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
      await app.cache.write(testUserId, PortfoliosController.query, [
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
      await app.cache.write(testUserId, PortfoliosController.query, {
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
      await app.cache.write(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      await app.cache.write(testUserId, 'tenants.${plaza.id}', [1]);
      await app.cache.write(testUserId, 'tenant.someone', 1);
      await app.cache.write('another-user', 'tenants.${plaza.id}', [1]);
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
      await app.cache.write(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
      ]);
      await app.cache.write(testUserId, 'tenants.${gulberg.id}', [1]);
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
      await app.cache.write(testUserId, 'tenants.${plaza.id}', [1]);
      await container
          .read(portfoliosProvider(testUserId).notifier)
          .delete(plaza.id, confirmation: plaza.name);
      expect(keys(app), {
        'mm.swr.v1.$testUserId.${PortfoliosController.query}',
      });
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
      await app.cache.write(testUserId, PortfoliosController.query, [
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
        await app.cache.write(testUserId, PortfoliosController.query, [
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
