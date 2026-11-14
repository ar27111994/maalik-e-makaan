// Reproduction of the review finding on SwrCache.forgetUser (PR #70): a
// fetch begun before a portfolio left the user's list, and answered after
// the prune, saves the removed portfolio's records again, and no later
// refresh removes them. Not part of the PR: kept uncommitted.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

void main() {
  test('cache: a fetch begun before forgetUser stores nothing for the '
      'forgotten entries', () async {
    final store = MemoryStore();
    final cache = SwrCache(store);
    final fetch = Completer<int>();
    final done = cache
        .watch<int>(
          userId: 'u1',
          query: 'tenants.p2',
          fetch: () => fetch.future,
          decode: (json) => json! as int,
          encode: (value) => value,
        )
        .drain<void>();
    await pumpEventQueue();
    // The portfolio p2 left u1's list while the request was on its way.
    await cache.forgetUser('u1', keep: 'portfolios');
    fetch.complete(5);
    await done;
    expect(store.values.keys, isNot(contains('mm.swr.v1.u1.tenants.p2')));
  });

  for (final stillShown in [true, false]) {
    test('app: a tenant list answered before the user left a portfolio, '
        'arriving after the prune, is not saved, and a later refresh '
        'leaves nothing (screen ${stillShown ? 'still' : 'no longer'} '
        'shown)', () async {
      // The server: the user is no longer in plaza.
      final app = TestApp(portfolios: const [gulberg]);
      // The tenant request was answered before the removal (the fake has
      // no row-level security), so it carries plaza's tenants.
      app.tenants.byPortfolio[plaza.id] = [aliRaza];
      // The device's list from before the removal.
      await app.cache.write(testUserId, PortfoliosController.query, [
        gulberg.toRow(),
        plaza.toRow(),
      ]);
      final tenantsKey = 'mm.swr.v1.$testUserId.tenants.${plaza.id}.active.';
      bool saved() => app.store.values.containsKey(tenantsKey);

      final container = containerFor(app);
      app.tenants.gate.close();
      final shown = listen(
        container,
        tenantsProvider((portfolioId: plaza.id, archived: false, search: '')),
      );
      await pumpEventQueue();
      expect(app.tenants.calls, hasLength(1), reason: 'request in flight');

      // The portfolio list refreshes: plaza is gone, the prune runs.
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      expect(container.read(portfoliosProvider(testUserId)).value!.value, [
        gulberg,
      ]);
      expect(saved(), isFalse, reason: 'precondition: nothing saved yet');

      if (!stillShown) shown.close();
      await pumpEventQueue();
      // The tenant answer arrives.
      app.tenants.gate.open();
      await pumpEventQueue();
      final afterLateAnswer = saved();

      // The next start: the saved list no longer has plaza, so the
      // refresh sees nothing removed.
      container.dispose();
      final next = containerFor(app);
      listen(next, portfoliosProvider(testUserId));
      await pumpEventQueue();
      final afterNextRefresh = saved();

      expect(
        (afterLateAnswer: afterLateAnswer, afterNextRefresh: afterNextRefresh),
        (afterLateAnswer: false, afterNextRefresh: false),
        reason: 'plaza tenants on the device: ${app.store.values[tenantsKey]}',
      );
    });
  }
}
