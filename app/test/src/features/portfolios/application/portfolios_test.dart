import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

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
      expect(
        app.portfolios.calls.firstWhere((call) => call.$1 == 'create').$2,
        ['Khan family', 'p-new'],
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

  test('the user id comes from the session', () {
    final container = containerFor(TestApp(auth: const SignedOut()));
    expect(container.read(currentUserIdProvider), isNull);
  });
}
