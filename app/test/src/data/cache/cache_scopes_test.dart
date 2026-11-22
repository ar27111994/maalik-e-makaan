// Every cached query says which portfolio its saved copy is of; this ties
// what each one says to what its fetch really returns. Each query is built
// over the fakes, whose rows are all of Gulberg's, and the key its value is
// saved under must name Gulberg, or no portfolio for an empty value.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:mm_core/mm_core.dart';

import '../../../support/container.dart';
import '../../../support/harness.dart';

/// A cached query: its provider, its notifier, and whether its portfolio
/// is named by a parameter (else read from the value).
typedef _Query = ({
  ProviderListenable<Object?> provider,
  SwrNotifier<Object?> Function(ProviderContainer c) notifier,
  bool byParameter,
});

_Query _q<N extends SwrNotifier<Object?>>(
  ProviderListenable<Object?> provider,
  Refreshable<N> notifier, {
  required bool byParameter,
}) => (
  provider: provider,
  notifier: (c) => c.read(notifier),
  byParameter: byParameter,
);

final ReportSpan _span = twelveMonthsTo(gulberg.id, MonthPeriod(2026, 11));
final TaxYearOf _of = (portfolioId: gulberg.id, taxYear: TaxYear(2026));
final DocumentList _docs = (
  portfolioId: gulberg.id,
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
);

/// Every query of the app's features: 19 by a parameter, 15 by the value.
final Map<String, _Query> _queries = {
  'portfolio details': _q(
    portfolioDetailsProvider(gulberg.id),
    portfolioDetailsProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'team': _q(
    teamProvider(gulberg),
    teamProvider(gulberg).notifier,
    byParameter: true,
  ),
  'cash book': _q(
    cashBookProvider(gulberg.id),
    cashBookProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'notifications': _q(
    notificationsProvider(gulberg.id),
    notificationsProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'receivables': _q(
    receivablesProvider(gulberg),
    receivablesProvider(gulberg).notifier,
    byParameter: true,
  ),
  'properties': _q(
    propertiesProvider((portfolioId: gulberg.id, archived: false)),
    propertiesProvider((portfolioId: gulberg.id, archived: false)).notifier,
    byParameter: true,
  ),
  'repairs': _q(
    maintenanceListProvider((portfolioId: gulberg.id, pending: true)),
    maintenanceListProvider((portfolioId: gulberg.id, pending: true)).notifier,
    byParameter: true,
  ),
  'expenses': _q(
    expensesProvider((portfolioId: gulberg.id, requestId: null)),
    expensesProvider((portfolioId: gulberg.id, requestId: null)).notifier,
    byParameter: true,
  ),
  'utility connections': _q(
    utilityAccountsProvider((portfolioId: gulberg.id, archived: false)),
    utilityAccountsProvider((portfolioId: gulberg.id, archived: false))
        .notifier,
    byParameter: true,
  ),
  'unpaid bills': _q(
    unpaidBillsProvider(gulberg.id),
    unpaidBillsProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'places': _q(
    placesProvider(gulberg.id),
    placesProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'tenants': _q(
    tenantsProvider((portfolioId: gulberg.id, archived: false, search: '')),
    tenantsProvider((portfolioId: gulberg.id, archived: false, search: ''))
        .notifier,
    byParameter: true,
  ),
  'dashboard': _q(
    dashboardProvider(gulberg),
    dashboardProvider(gulberg).notifier,
    byParameter: true,
  ),
  'insight extras': _q(
    insightExtrasProvider(gulberg.id),
    insightExtrasProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'payment facts': _q(
    paymentFactsProvider(gulberg.id),
    paymentFactsProvider(gulberg.id).notifier,
    byParameter: true,
  ),
  'cashflow': _q(
    cashflowProvider(_span),
    cashflowProvider(_span).notifier,
    byParameter: true,
  ),
  'performance': _q(
    performanceProvider(_span),
    performanceProvider(_span).notifier,
    byParameter: true,
  ),
  'tax year': _q(
    taxYearProvider(_of),
    taxYearProvider(_of).notifier,
    byParameter: true,
  ),
  'documents': _q(
    documentsProvider(_docs),
    documentsProvider(_docs).notifier,
    byParameter: true,
  ),
  'tenant': _q(
    tenantProvider(aliRaza.id),
    tenantProvider(aliRaza.id).notifier,
    byParameter: false,
  ),
  'property': _q(
    propertyProvider(gulbergHouse.id),
    propertyProvider(gulbergHouse.id).notifier,
    byParameter: false,
  ),
  'unit': _q(
    unitProvider(groundFloor.id),
    unitProvider(groundFloor.id).notifier,
    byParameter: false,
  ),
  'units': _q(
    unitsProvider(gulbergHouse.id),
    unitsProvider(gulbergHouse.id).notifier,
    byParameter: false,
  ),
  'lease': _q(
    leaseProvider(aliLease.id),
    leaseProvider(aliLease.id).notifier,
    byParameter: false,
  ),
  'leases': _q(
    leasesProvider((unitId: groundFloor.id, tenantId: null)),
    leasesProvider((unitId: groundFloor.id, tenantId: null)).notifier,
    byParameter: false,
  ),
  'tenancies': _q(
    tenanciesProvider((propertyId: gulbergHouse.id, unitId: null)),
    tenanciesProvider((propertyId: gulbergHouse.id, unitId: null)).notifier,
    byParameter: false,
  ),
  'ledger': _q(
    tenancyLedgerProvider(aliLease.id),
    tenancyLedgerProvider(aliLease.id).notifier,
    byParameter: false,
  ),
  'reminders': _q(
    remindersProvider(aliLease.id),
    remindersProvider(aliLease.id).notifier,
    byParameter: false,
  ),
  'payment': _q(
    paymentProvider('pay-oct'),
    paymentProvider('pay-oct').notifier,
    byParameter: false,
  ),
  'repair': _q(
    maintenanceRequestProvider(seepageJob.id),
    maintenanceRequestProvider(seepageJob.id).notifier,
    byParameter: false,
  ),
  'expense': _q(
    expenseProvider(plumberExpense.id),
    expenseProvider(plumberExpense.id).notifier,
    byParameter: false,
  ),
  'utility connection': _q(
    utilityAccountProvider(lescoMeter.id),
    utilityAccountProvider(lescoMeter.id).notifier,
    byParameter: false,
  ),
  'bill': _q(
    utilityBillProvider(novemberBill.id),
    utilityBillProvider(novemberBill.id).notifier,
    byParameter: false,
  ),
  'reading': _q(
    meterReadingProvider(novemberReading.id),
    meterReadingProvider(novemberReading.id).notifier,
    byParameter: false,
  ),
};

/// The keys of the store, but the user's own.
Iterable<String> _records(TestApp app) =>
    app.store.values.keys.where((key) => !key.contains('.own.'));

void main() {
  test('the table holds every cached query of the app', () {
    final declared = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ...RegExp('extends SwrNotifier<').allMatches(file.readAsStringSync()),
    ];
    expect(_queries, hasLength(declared.length));
    expect(declared, hasLength(34));
    expect(_queries.values.where((q) => q.byParameter), hasLength(19));
  });

  for (final MapEntry(key: name, value: query) in _queries.entries) {
    test('$name is saved under the portfolio of what it fetched', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, query.provider);
      await pumpEventQueue();
      final notifier = query.notifier(container);
      expect(
        notifier.scope,
        query.byParameter
            ? isA<InPortfolio<Object?>>()
            : isA<FromValue<Object?>>(),
      );
      // Its value came from the server, and is of Gulberg.
      expect(container.read(query.provider), isA<AsyncData<Object?>>());
      expect(_records(app), [
        SwrCache.keyOf(testUserId, PortfolioTag(gulberg.id), notifier.query),
      ]);
    });
  }

  group('an empty list names no portfolio', () {
    final empties =
        <String, (void Function(TestApp), ProviderListenable<Object?>)>{
          'units': (
            (app) => app.properties.unitList.clear(),
            unitsProvider(gulbergHouse.id),
          ),
          'leases': (
            (app) => app.leases.leaseList.clear(),
            leasesProvider((unitId: groundFloor.id, tenantId: null)),
          ),
          'tenancies': (
            (app) => app.operations.leaseList.clear(),
            tenanciesProvider((propertyId: gulbergHouse.id, unitId: null)),
          ),
          'reminders': (
            (app) => app.reminders.logs.clear(),
            remindersProvider(aliLease.id),
          ),
        };
    for (final MapEntry(key: name, value: (empty, provider))
        in empties.entries) {
      test(name, () async {
        final app = TestApp();
        empty(app);
        final container = containerFor(app);
        listen(container, provider);
        await pumpEventQueue();
        expect(_records(app), hasLength(1));
        expect(_records(app).single, contains('.unknown.'));
      });
    }
  });
}
