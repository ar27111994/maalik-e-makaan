// The probes earlier rounds of review ran against the portfolio prune (P1 to
// P9 and N1 to N10; see docs/architecture/app.md, Writes after a removal),
// kept as tests of the rule that replaced it: each saved entry names its
// portfolio, and each list of portfolios the server answers removes, from
// the keys alone, every entry it does not keep.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

/// Gulberg's tenants in use, unsearched.
const TenantList _gulbergTenants = (
  portfolioId: _g,
  archived: false,
  search: '',
);
const _g = '0192d0c4-0000-7000-8000-000000000001';

/// Every key of the store that names Gulberg.
Iterable<String> _ofGulberg(TestApp app) =>
    app.store.values.keys.where((key) => key.contains('p:${gulberg.id}'));

/// The keys of the store, apart from the user's own.
Iterable<String> _records(TestApp app) =>
    app.store.values.keys.where((key) => !key.contains('.own.'));

/// The server no longer lists Gulberg (left on another device).
void _leaveGulberg(TestApp app) =>
    app.portfolios.memberships.removeWhere((m) => m.id == gulberg.id);

PortfoliosController _list(ProviderContainer container) =>
    container.read(portfoliosProvider(testUserId).notifier);

Future<void> _reload(ProviderContainer container) async {
  await _list(container).reload();
  await pumpEventQueue();
}

void main() {
  group('P1, P2: the removal cannot list the keys at the first list', () {
    for (final (name, fault)
        in <(String, void Function(TestApp, {required bool on}))>[
          (
            'the listing fails',
            (app, {required on}) =>
                app.store.keysFailure = on ? Exception('no listing') : null,
          ),
          (
            'the listing hangs',
            (app, {required on}) => app.store.hangingKeys = on,
          ),
        ]) {
      test('$name: the list is saved, the records are kept while Gulberg '
          'stays, and go once it leaves', () async {
        final app = TestApp();
        await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
        fault(app, on: true);
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        expect(
          app.store.values.keys,
          contains(cacheKey(testUserId, PortfoliosController.query)),
        );
        expect(_ofGulberg(app), hasLength(1));
        fault(app, on: false);
        _leaveGulberg(app);
        await _reload(container);
        expect(_ofGulberg(app), isEmpty);
      });
    }
  });

  group('P3: a record opened by its link while the first list loads', () {
    test('lands first: kept until the list, which removes it', () async {
      final app = TestApp(portfolios: const [plaza]);
      app.portfolios.gate.close();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      expect(_ofGulberg(app), hasLength(1));
      app.portfolios.gate.open();
      await pumpEventQueue();
      expect(_ofGulberg(app), isEmpty);
    });

    test('lands after: never saved', () async {
      final app = TestApp(portfolios: const [plaza]);
      app.tenants.gate.close();
      final container = containerFor(app);
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.tenants.gate.open();
      await pumpEventQueue();
      expect(container.read(tenantProvider(aliRaza.id)).value!.value, aliRaza);
      expect(_ofGulberg(app), isEmpty);
    });
  });

  group("P4, P5: the user's own outlive every list", () {
    test('a profile write held across the first list is kept, and a '
        'language saved after a removal', () async {
      final app = TestApp(portfolios: const [plaza]);
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      app.profiles.gate.close();
      final saving = container
          .read(profileProvider(testUserId).notifier)
          .saveDetails(fullName: 'Ayesha K.', phone: null);
      await pumpEventQueue();
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_ofGulberg(app), isEmpty);
      app.profiles.gate.open();
      await saving;
      await container
          .read(profileProvider(testUserId).notifier)
          .saveLanguage(AppLanguage.urdu);
      final saved = await app.cache.read(
        testUserId,
        ProfileController.query,
        ProfileController.scope,
        Profile.fromRow,
      );
      expect(saved!.value.fullName, 'Ayesha K.');
      expect(saved.value.language, AppLanguage.urdu);
    });
  });

  group('P6, P7: what a wipe could not delete', () {
    test('a key the clear could not delete goes at the next session’s first '
        'list', () async {
      final app = TestApp(portfolios: const [plaza]);
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      final stuck = cacheKey(
        testUserId,
        'tenants.${gulberg.id}',
        portfolio: gulberg.id,
      );
      app.store.undeletable.add(stuck);
      await app.cache.clear().catchError((_) {});
      expect(app.store.values.keys, [stuck]);
      app.store.undeletable.clear();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_ofGulberg(app), isEmpty);
    });

    test('a write that lands after the clear and whose deletion is refused '
        'goes at the next list without its portfolio', () async {
      final app = TestApp();
      final key = cacheKey(testUserId, 'tenant.${aliRaza.id}', portfolio: _g);
      app.store.holding.add(key);
      final container = containerFor(app);
      final shown = listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      shown.close();
      await app.cache.clear();
      app.store.undeletable.add(key);
      app.store.finishHeldWritesOldestFirst();
      await pumpEventQueue();
      expect(app.store.values.keys, [key]);
      app.store.undeletable.clear();
      // The next session, of the same account, no longer in Gulberg.
      _leaveGulberg(app);
      final next = containerFor(app..cache = SwrCache(app.store));
      listen(next, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_ofGulberg(app), isEmpty);
    });
  });

  test('P8: a list write held across a leaving lands after it and is '
      'deleted; the records go', () async {
    final app = TestApp();
    final listKey = cacheKey(testUserId, PortfoliosController.query);
    app.store.holding.add(listKey);
    final container = containerFor(app);
    listen(container, portfoliosProvider(testUserId));
    listen(container, tenantsProvider(_gulbergTenants));
    await pumpEventQueue();
    expect(_ofGulberg(app), hasLength(1));
    _leaveGulberg(app);
    await _reload(container);
    expect(_ofGulberg(app), isEmpty);
    // Both list writes land, the older naming Gulberg last.
    app.store.finishHeldWritesNewestFirst();
    await pumpEventQueue();
    expect(app.store.values.keys, isNot(contains(listKey)));
    expect(_ofGulberg(app), isEmpty);
  });

  group('P9, N10: a portfolio joined elsewhere, opened here by its link, and '
      'left before this device loads the list again', () {
    test('after a list this session: the record is never saved', () async {
      final app = TestApp(portfolios: const [plaza]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      // Joined on another device; its tenant opened here by a link.
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      expect(container.read(tenantProvider(aliRaza.id)).value!.value, aliRaza);
      expect(_ofGulberg(app), isEmpty);
      await _reload(container);
      expect(_ofGulberg(app), isEmpty);
    });

    test('before any list this session: saved, then removed by the list '
        'load', () async {
      final app = TestApp(portfolios: const [plaza]);
      final container = containerFor(app);
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      expect(_ofGulberg(app), hasLength(1));
      // Left on the other device; this device loads the list.
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_ofGulberg(app), isEmpty);
    });
  });

  group('N1: leaving and rejoining', () {
    test('the leave removes the records, the rejoin saves them again, and '
        'leaving again removes them', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      final tenants = listen(container, tenantsProvider(_gulbergTenants));
      await pumpEventQueue();
      expect(_ofGulberg(app), hasLength(1));
      _leaveGulberg(app);
      await _reload(container);
      expect(_ofGulberg(app), isEmpty);
      app.portfolios.memberships.add(gulberg);
      await _reload(container);
      await container.read(tenantsProvider(_gulbergTenants).notifier).reload();
      await pumpEventQueue();
      expect(_ofGulberg(app), hasLength(1));
      _leaveGulberg(app);
      await _reload(container);
      expect(_ofGulberg(app), isEmpty);
      tenants.close();
    });

    test(
      'N1b: left and rejoined between two loads, the records stay',
      () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        listen(container, tenantsProvider(_gulbergTenants));
        await pumpEventQueue();
        await _reload(container);
        expect(_ofGulberg(app), hasLength(1));
      },
    );
  });

  group('N2: two portfolios leave', () {
    test('with a refused deletion between, nothing stays once the store '
        'answers', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      listen(container, profileProvider(testUserId));
      listen(container, tenantsProvider(_gulbergTenants));
      await pumpEventQueue();
      final plazaKey = cacheKey(
        testUserId,
        'tenants.${plaza.id}',
        portfolio: plaza.id,
      );
      // Plaza's key cannot be deleted, but Plaza is not leaving yet.
      app.store.undeletable.add(plazaKey);
      _leaveGulberg(app);
      await _reload(container);
      expect(_ofGulberg(app), isEmpty);
      final saved = await app.cache.read<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
        (json) => json,
      );
      expect(saved!.value! as List, hasLength(1));
      app.store.undeletable.clear();
      app.portfolios.memberships.clear();
      await _reload(container);
      expect(app.store.values.keys.toSet(), {
        cacheKey(testUserId, PortfoliosController.query),
        cacheKey(testUserId, ProfileController.query),
      });
    });

    test('N2b: a deletion refused, the app started again, and the other '
        'left: both go at the next list the store lets delete', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      final stuck = cacheKey(
        testUserId,
        'tenants.${gulberg.id}',
        portfolio: gulberg.id,
      );
      app.store.undeletable.add(stuck);
      _leaveGulberg(app);
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_ofGulberg(app), [stuck]);
      // While the list keeps it out, its own screen shows nothing saved.
      app.tenants.gate.close();
      listen(container, tenantsProvider(_gulbergTenants));
      await pumpEventQueue();
      expect(container.read(tenantsProvider(_gulbergTenants)).hasValue, false);
      container.dispose();
      // The app starts again; Plaza has left too.
      app
        ..store.undeletable.clear()
        ..cache = SwrCache(app.store);
      app.portfolios.memberships.clear();
      listen(containerFor(app), portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_records(app), isEmpty);
    });
  });

  test('N4: a write asked before a removal and landing after a later clear '
      'is deleted as it lands', () async {
    final app = TestApp();
    final key = cacheKey(testUserId, 'tenant.${aliRaza.id}', portfolio: _g);
    app.store.holding.add(key);
    final container = containerFor(app);
    listen(container, tenantProvider(aliRaza.id));
    await pumpEventQueue();
    await app.cache.answer(testUserId, [plaza.id]);
    await app.cache.clear();
    app.store.finishHeldWritesOldestFirst();
    await pumpEventQueue();
    expect(app.store.values, isEmpty);
  });

  test('N5b: deletions that never answer at a removal hold up nothing; the '
      'next list removes what they left once the store answers', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, portfoliosProvider(testUserId));
    listen(container, tenantsProvider(_gulbergTenants));
    await pumpEventQueue();
    final stuck = _ofGulberg(app).single;
    app.store.silent.add(stuck);
    _leaveGulberg(app);
    await _reload(container);
    // The list is saved all the same.
    final saved = await app.cache.read<Object?>(
      testUserId,
      PortfoliosController.query,
      scopeOf(PortfoliosController.query),
      (json) => json,
    );
    expect(saved!.value! as List, hasLength(1));
    expect(_ofGulberg(app), [stuck]);
    app.store.silent.clear();
    await _reload(container);
    expect(_ofGulberg(app), isEmpty);
  });

  test('N6: sign-out, then another account, with writes of the first in '
      'flight: nothing of the first stays', () async {
    final app = TestApp();
    final key = cacheKey(testUserId, 'tenant.${aliRaza.id}', portfolio: _g);
    app.store.holding.add(key);
    final container = containerFor(app);
    listen(container, tenantProvider(aliRaza.id));
    await pumpEventQueue();
    await DeviceDataWipe(
      cache: app.cache,
      settings: app.settings,
      scratch: app.scratch,
    ).wipe(WipeReason.signedOut);
    // Another account's list is saved.
    await app.cache.write<int>(
      'other-user',
      'tenants.x',
      InPortfolio('x'),
      1,
      (v) => v,
      epoch: app.cache.epoch,
    );
    app.store.finishHeldWritesOldestFirst();
    await pumpEventQueue();
    expect(app.store.values.keys, [
      SwrCache.keyOf('other-user', const PortfolioTag('x'), 'tenants.x'),
    ]);
  });

  test('N7: a start signed in with leftovers ends with the list, the '
      'profile and the residence', () async {
    final app = TestApp(portfolios: const [plaza]);
    await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
    await app.cache.seed(testUserId, 'tenant.${aliRaza.id}', aliRaza.toRow());
    await app.cache.seed('another-user', 'tenants.${plaza.id}', [1]);
    app.store.values['mm.swr.v1.$testUserId.tenants'] = '{}';
    await DeviceDataWipe(
      cache: app.cache,
      settings: app.settings,
      scratch: app.scratch,
    ).atStart(signedInAs: testUserId, photoMayReturn: true);
    expect(
      app.store.values.keys.where((k) => k.startsWith('mm.swr.v1.')),
      isEmpty,
    );
    final container = containerFor(app);
    listen(container, portfoliosProvider(testUserId));
    listen(container, profileProvider(testUserId));
    listen(container, residenceProvider(testUserId));
    await pumpEventQueue();
    expect(app.store.values.keys.toSet(), {
      cacheKey(testUserId, PortfoliosController.query),
      cacheKey(testUserId, ProfileController.query),
      cacheKey(testUserId, ResidenceController.query),
    });
  });

  group('N8: an answer out of date', () {
    test('an owner-abroad answer racing a list that drops a portfolio does '
        'not name it again', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.portfolios.gate.close();
      final reloading = _list(container).reload();
      await pumpEventQueue();
      _leaveGulberg(app);
      app.portfolios.gate.open();
      // The answer is asked while the list without Gulberg is applied.
      await Future.wait([
        reloading,
        _list(container).answerOwnerAbroad(plaza.id, abroad: true),
      ]);
      await pumpEventQueue();
      final shown = container.read(portfoliosProvider(testUserId)).value!;
      expect([for (final m in shown.value) m.id], [plaza.id]);
      final saved = await app.cache.read<Object?>(
        testUserId,
        PortfoliosController.query,
        scopeOf(PortfoliosController.query),
        (json) => json,
      );
      expect(saved!.value! as List, hasLength(1));
    });

    test('an answer asked before a wipe and landing after it, in the next '
        'session of the same account, sets nothing', () async {
      final app = TestApp();
      app.portfolios.scripted = true;
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      await app.cache.clear();
      // The next session's record, before its own list.
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      app.portfolios.answers.single.complete([plaza]);
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), isNull);
      expect(_ofGulberg(app), hasLength(1));
    });
  });

  group('N9: the list write fails as Gulberg joins', () {
    for (final late in [false, true]) {
      test('${late ? 'late' : 'at once'}: its records saved meanwhile go '
          'when it leaves', () async {
        final app = TestApp(portfolios: const [plaza]);
        final container = containerFor(app);
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        final listKey = cacheKey(testUserId, PortfoliosController.query);
        if (late) {
          app.store.holding.add(listKey);
        } else {
          app.store.writeFailure = Exception('full');
        }
        app.portfolios.memberships.add(gulberg);
        await _reload(container);
        if (late) app.store.failHeldWrites(Exception('full'));
        app.store.writeFailure = null;
        app.store.holding.clear();
        listen(container, tenantsProvider(_gulbergTenants));
        await pumpEventQueue();
        expect(_ofGulberg(app), hasLength(1));
        _leaveGulberg(app);
        await _reload(container);
        expect(_ofGulberg(app), isEmpty);
      });
    }
  });

  group('lists the controller builds itself, when the server list fails', () {
    test('creating adds the new portfolio without outranking a list '
        'answer asked earlier', () async {
      final app = TestApp();
      app.portfolios.scripted = true;
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.portfolios.answers[0].complete([gulberg, plaza]);
      await pumpEventQueue();
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [1]);
      // A reload is on its way (#1)...
      final reloading = _list(container).reload();
      await pumpEventQueue();
      // ...when a portfolio is created and the follow-up read (#2) fails.
      final creating = _list(container).create(name: 'Khan family', id: 'pN');
      await pumpEventQueue();
      app.portfolios.answers[2].completeError(const NetworkFailure());
      await creating;
      expect(app.cache.portfoliosOf(testUserId), {gulberg.id, plaza.id, 'pN'});
      // The earlier read answers without Gulberg (left elsewhere): applied.
      app.portfolios.answers[1].complete([plaza]);
      await reloading;
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), {plaza.id});
      expect(_ofGulberg(app), isEmpty);
    });

    test('deleting removes the portfolio and its records at once, and an '
        'answer asked earlier is still applied', () async {
      final app = TestApp();
      app.portfolios.scripted = true;
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.portfolios.answers[0].complete([gulberg, plaza]);
      await pumpEventQueue();
      await app.cache.seed(testUserId, 'tenants.${plaza.id}', [1]);
      final reloading = _list(container).reload();
      await pumpEventQueue();
      final deleting = _list(container)
          .delete(plaza.id, confirmation: plaza.name);
      await pumpEventQueue();
      expect(app.cache.portfoliosOf(testUserId), {gulberg.id});
      expect(_records(app), isEmpty);
      app.portfolios.answers[2].completeError(const NetworkFailure());
      await deleting;
      final shown = container.read(portfoliosProvider(testUserId)).value!;
      expect([for (final m in shown.value) m.id], [gulberg.id]);
      app.portfolios.answers[1].complete([gulberg]);
      await reloading;
      expect(app.cache.portfoliosOf(testUserId), {gulberg.id});
    });

    test('before any list, creating and deleting set nothing', () async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      await _list(container).create(name: 'Khan family', id: 'pN');
      await _list(container).delete(gulberg.id, confirmation: gulberg.name);
      expect(app.cache.portfoliosOf(testUserId), isNull);
    });

    test('a list built from a saved one that names a portfolio left since '
        'is cut to the portfolios the cache keeps', () async {
      final app = TestApp(portfolios: const [plaza]);
      await app.cache.seed(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      app.portfolios.listFailure = const NetworkFailure();
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      // The saved list is on show; the server's list applies in the cache
      // before a command builds on the one on show.
      await app.cache.answer(testUserId, [plaza.id]);
      await _list(container).answerOwnerAbroad(plaza.id, abroad: true);
      final shown = container.read(portfoliosProvider(testUserId)).value!;
      expect([for (final m in shown.value) m.id], [plaza.id]);
    });
  });

  group('records found by their own id', () {
    test('a tenant opened by its link shows its saved copy before the '
        'fetch', () async {
      final app = TestApp();
      await app.cache.seed(testUserId, 'tenant.${aliRaza.id}', aliRaza.toRow());
      app.tenants.gate.close();
      final container = containerFor(app);
      listen(container, tenantProvider(aliRaza.id));
      await pumpEventQueue();
      final shown = container.read(tenantProvider(aliRaza.id)).value!;
      expect(shown.fromCache, isTrue);
      expect(shown.value, aliRaza);
    });

    test('an empty list of units is not saved once a list is applied, and '
        'the first list removes one saved before', () async {
      final app = TestApp();
      app.properties.unitList.clear();
      final container = containerFor(app);
      listen(container, unitsProvider(gulbergHouse.id));
      await pumpEventQueue();
      expect(_records(app), hasLength(1));
      expect(_records(app).single, contains('.unknown.'));
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(_records(app), isEmpty);
      await container.read(unitsProvider(gulbergHouse.id).notifier).reload();
      await pumpEventQueue();
      expect(_records(app), isEmpty);
    });

    test('a search with dots and Urdu is kept whole in its key, and pruned '
        'by its portfolio', () async {
      final app = TestApp();
      const search = 'علی. رضا.';
      final container = containerFor(app);
      listen(container, portfoliosProvider(testUserId));
      listen(
        container,
        tenantsProvider((portfolioId: _g, archived: false, search: search)),
      );
      await pumpEventQueue();
      expect(
        app.store.values.keys,
        contains(
          cacheKey(
            testUserId,
            'tenants.$_g.active.$search',
            portfolio: gulberg.id,
          ),
        ),
      );
      _leaveGulberg(app);
      await _reload(container);
      expect(_ofGulberg(app), isEmpty);
    });
  });

  test('the old format goes at a list save as well', () async {
    final app = TestApp();
    app.store.values['mm.swr.v1.$testUserId.tenants'] = '{}';
    final container = containerFor(app);
    listen(container, portfoliosProvider(testUserId));
    await pumpEventQueue();
    expect(
      app.store.values.keys.where((k) => k.startsWith('mm.swr.v1.')),
      isEmpty,
    );
    expect(
      container.read(portfoliosProvider(testUserId)).value!.value,
      <PortfolioMembership>[gulberg, plaza],
    );
  });
}
