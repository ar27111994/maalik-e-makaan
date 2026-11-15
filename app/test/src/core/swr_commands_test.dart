import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:mm_core/mm_core.dart';

import '../../support/container.dart';
import '../../support/harness.dart';

/// The saved copy of [query] for the test user, or null.
Future<Snapshot<Object?>?> _saved(TestApp app, String query) =>
    app.cache.read<Object?>(testUserId, query, (json) => json);

/// A portfolio leaves the user's list: every saved record of theirs goes
/// but the list itself.
Future<void> _portfolioLeft(TestApp app) =>
    app.cache.forgetUser(testUserId, keep: PortfoliosController.kept);

/// A feature's command over one query.
final class _Command {
  const new(
    this.name, {
    required this.provider,
    required this.notifier,
    required this.run,
    required this.gate,
    this.setUp,
    this.readAfterFailedWrite = false,
  });

  final String name;

  /// The query's provider, kept alive for the test.
  final ProviderListenable<Object?> provider;

  /// The query's notifier.
  final SwrNotifier<Object?> Function(ProviderContainer container) notifier;

  /// Runs the command.
  final Future<Object?> Function(ProviderContainer container) run;

  /// The gate of the fake the command asks.
  final Gate Function(TestApp app) gate;

  /// What the fakes need before the query is built.
  final void Function(TestApp app)? setUp;

  /// Whether the answer shown is a read the command makes once its write
  /// failed: that read, not the write, is held.
  final bool readAfterFailedWrite;
}

/// Commands that show the server's answer to their own request, and read
/// the epoch for it before the request (`SwrNotifier.requestEpoch`).
final _answering = <_Command>[
  _Command(
    'saving a tenant',
    provider: tenantProvider(aliRaza.id),
    notifier: (c) => c.read(tenantProvider(aliRaza.id).notifier),
    run: (c) => c.read(tenantProvider(aliRaza.id).notifier).save(aliRaza),
    gate: (app) => app.tenants.gate,
  ),
  _Command(
    'archiving a tenant',
    provider: tenantProvider(aliRaza.id),
    notifier: (c) => c.read(tenantProvider(aliRaza.id).notifier),
    run: (c) =>
        c.read(tenantProvider(aliRaza.id).notifier).archive(archived: true),
    gate: (app) => app.tenants.gate,
  ),
  _Command(
    'saving a property',
    provider: propertyProvider(gulbergHouse.id),
    notifier: (c) => c.read(propertyProvider(gulbergHouse.id).notifier),
    run: (c) =>
        c.read(propertyProvider(gulbergHouse.id).notifier).save(gulbergHouse),
    gate: (app) => app.properties.gate,
  ),
  _Command(
    'archiving a property',
    provider: propertyProvider(gulbergHouse.id),
    notifier: (c) => c.read(propertyProvider(gulbergHouse.id).notifier),
    run: (c) => c
        .read(propertyProvider(gulbergHouse.id).notifier)
        .archive(archived: true),
    gate: (app) => app.properties.gate,
  ),
  _Command(
    'saving an expense',
    provider: expenseProvider(plumberExpense.id),
    notifier: (c) => c.read(expenseProvider(plumberExpense.id).notifier),
    run: (c) => c
        .read(expenseProvider(plumberExpense.id).notifier)
        .save(
          ExpenseDraft(
            category: ExpenseCategory.bankCharges,
            amount: const Money.fromRupees(300),
            spentOn: CalendarDate(2026, 11, 7),
          ),
        ),
    gate: (app) => app.operations.gate,
  ),
  _Command(
    'saving a repair',
    provider: maintenanceRequestProvider(seepageJob.id),
    notifier: (c) => c.read(maintenanceRequestProvider(seepageJob.id).notifier),
    run: (c) => c
        .read(maintenanceRequestProvider(seepageJob.id).notifier)
        .save(
          MaintenanceDraft(
            propertyId: gulbergHouse.id,
            title: 'Fix the seepage',
            reportedOn: CalendarDate(2026, 11, 7),
          ),
        ),
    gate: (app) => app.operations.gate,
  ),
  _Command(
    'moving a repair along',
    provider: maintenanceRequestProvider(seepageJob.id),
    notifier: (c) => c.read(maintenanceRequestProvider(seepageJob.id).notifier),
    run: (c) => c
        .read(maintenanceRequestProvider(seepageJob.id).notifier)
        .move(
          MaintenanceMove(
            MaintenanceStatus.resolved,
            resolvedOn: CalendarDate(2026, 11, 7),
          ),
        ),
    gate: (app) => app.operations.gate,
  ),
  _Command(
    'saving a bill',
    provider: utilityBillProvider(novemberBill.id),
    notifier: (c) => c.read(utilityBillProvider(novemberBill.id).notifier),
    run: (c) => c
        .read(utilityBillProvider(novemberBill.id).notifier)
        .save(
          BillDraft(
            billingMonth: novemberBill.billingMonth,
            amount: const Money.fromRupees(9900),
          ),
        ),
    gate: (app) => app.operations.gate,
  ),
  _Command(
    'saving whether a bill is paid',
    provider: utilityBillProvider(novemberBill.id),
    notifier: (c) => c.read(utilityBillProvider(novemberBill.id).notifier),
    run: (c) => c
        .read(utilityBillProvider(novemberBill.id).notifier)
        .setPayment(
          BillPayment(
            paidOn: CalendarDate(2026, 11, 7),
            paidBy: BillPayer.landlord,
          ),
        ),
    gate: (app) => app.operations.gate,
  ),
  _Command(
    'reading a ledger again after a refund whose answer was lost',
    provider: tenancyLedgerProvider(aliLease.id),
    notifier: (c) => c.read(tenancyLedgerProvider(aliLease.id).notifier),
    run: (c) async {
      try {
        await c
            .read(tenancyLedgerProvider(aliLease.id).notifier)
            .refundDeposit(
              amount: const Money.fromRupees(20000),
              refundedOn: CalendarDate(2026, 11, 7),
              method: PaymentMethod.cash,
            );
      } on NetworkFailure {
        // Not recorded: the failure stands once the ledger is read again.
      }
      return null;
    },
    gate: (app) => app.ledger.gate,
    setUp: (app) => app.ledger.writeFailures.add(const NetworkFailure()),
    readAfterFailedWrite: true,
  ),
  _Command(
    "saving a portfolio's settings",
    provider: portfolioDetailsProvider(gulberg.id),
    notifier: (c) => c.read(portfolioDetailsProvider(gulberg.id).notifier),
    run: (c) => c
        .read(portfolioDetailsProvider(gulberg.id).notifier)
        .save(
          PortfolioDetails(
            id: gulberg.id,
            name: 'Gulberg Homes',
            defaultDueDay: 10,
            defaultGraceDays: 3,
            defaultIncrementBasisPoints: 500,
          ),
        ),
    gate: (app) => app.portfolios.gate,
  ),
];

final TenantList _tenants = (
  portfolioId: gulberg.id,
  archived: false,
  search: '',
);
final PropertyList _properties = (portfolioId: gulberg.id, archived: false);
final DocumentList _documents = (
  portfolioId: gulberg.id,
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
);
final ExpenseList _expenses = (portfolioId: gulberg.id, requestId: null);
final MaintenanceList _repairs = (portfolioId: gulberg.id, pending: true);
final UtilityAccountList _connections = (
  portfolioId: gulberg.id,
  archived: false,
);

/// Commands that show a value made from the one on show (a page added to
/// it, a row of it changed), and hand it over with the epoch that value
/// was asked for in (`SwrNotifier.shownEpoch`). Each finds more to do
/// after a reload.
final _building = <_Command>[
  _Command(
    'loading more tenants',
    provider: tenantsProvider(_tenants),
    notifier: (c) => c.read(tenantsProvider(_tenants).notifier),
    run: (c) => c.read(tenantsProvider(_tenants).notifier).loadMore(),
    gate: (app) => app.tenants.gate,
    setUp: (app) => app.tenants.pageLimit = 1,
  ),
  _Command(
    'loading more properties',
    provider: propertiesProvider(_properties),
    notifier: (c) => c.read(propertiesProvider(_properties).notifier),
    run: (c) => c.read(propertiesProvider(_properties).notifier).loadMore(),
    gate: (app) => app.properties.gate,
    setUp: (app) {
      app.properties.pageLimit = 1;
      app.properties.byPortfolio[gulberg.id]!.add(saddarPlaza);
    },
  ),
  _Command(
    'loading more units',
    provider: unitsProvider(gulbergHouse.id),
    notifier: (c) => c.read(unitsProvider(gulbergHouse.id).notifier),
    run: (c) => c.read(unitsProvider(gulbergHouse.id).notifier).loadMore(),
    gate: (app) => app.properties.gate,
    setUp: (app) => app.properties.pageLimit = 1,
  ),
  _Command(
    'loading more documents',
    provider: documentsProvider(_documents),
    notifier: (c) => c.read(documentsProvider(_documents).notifier),
    run: (c) => c.read(documentsProvider(_documents).notifier).loadMore(),
    gate: (app) => app.documents.gate,
    setUp: (app) => app.documents.pageLimit = 1,
  ),
  _Command(
    'loading more expenses',
    provider: expensesProvider(_expenses),
    notifier: (c) => c.read(expensesProvider(_expenses).notifier),
    run: (c) => c.read(expensesProvider(_expenses).notifier).loadMore(),
    gate: (app) => app.operations.gate,
    setUp: (app) => app.operations.pageLimit = 1,
  ),
  _Command(
    'loading more repairs',
    provider: maintenanceListProvider(_repairs),
    notifier: (c) => c.read(maintenanceListProvider(_repairs).notifier),
    run: (c) => c.read(maintenanceListProvider(_repairs).notifier).loadMore(),
    gate: (app) => app.operations.gate,
    setUp: (app) => app.operations.pageLimit = 1,
  ),
  _Command(
    'loading more connections',
    provider: utilityAccountsProvider(_connections),
    notifier: (c) => c.read(utilityAccountsProvider(_connections).notifier),
    run: (c) =>
        c.read(utilityAccountsProvider(_connections).notifier).loadMore(),
    gate: (app) => app.operations.gate,
    setUp: (app) => app.operations.pageLimit = 1,
  ),
  _Command(
    "loading more of a connection's bills",
    provider: utilityAccountProvider(lescoMeter.id),
    notifier: (c) => c.read(utilityAccountProvider(lescoMeter.id).notifier),
    run: (c) =>
        c.read(utilityAccountProvider(lescoMeter.id).notifier).loadMoreBills(),
    gate: (app) => app.operations.gate,
    setUp: (app) => app.operations.pageLimit = 1,
  ),
  _Command(
    "loading more of a connection's readings",
    provider: utilityAccountProvider(lescoMeter.id),
    notifier: (c) => c.read(utilityAccountProvider(lescoMeter.id).notifier),
    run: (c) => c
        .read(utilityAccountProvider(lescoMeter.id).notifier)
        .loadMoreReadings(),
    gate: (app) => app.operations.gate,
    setUp: (app) => app.operations.pageLimit = 1,
  ),
  _Command(
    "loading more of a ledger's dues",
    provider: tenancyLedgerProvider(aliLease.id),
    notifier: (c) => c.read(tenancyLedgerProvider(aliLease.id).notifier),
    run: (c) =>
        c.read(tenancyLedgerProvider(aliLease.id).notifier).loadMoreCharges(),
    gate: (app) => app.ledger.gate,
    setUp: (app) => app.ledger.pageLimit = 1,
  ),
  _Command(
    "loading more of a ledger's payments",
    provider: tenancyLedgerProvider(aliLease.id),
    notifier: (c) => c.read(tenancyLedgerProvider(aliLease.id).notifier),
    run: (c) =>
        c.read(tenancyLedgerProvider(aliLease.id).notifier).loadMorePayments(),
    gate: (app) => app.ledger.gate,
    setUp: (app) => app.ledger.pageLimit = 1,
  ),
  _Command(
    'loading more handovers',
    provider: cashBookProvider(gulberg.id),
    notifier: (c) => c.read(cashBookProvider(gulberg.id).notifier),
    run: (c) => c.read(cashBookProvider(gulberg.id).notifier).loadMore(),
    gate: (app) => app.handovers.gate,
    setUp: (app) => app.handovers.pageLimit = 1,
  ),
  _Command(
    'loading more notifications',
    provider: notificationsProvider(gulberg.id),
    notifier: (c) => c.read(notificationsProvider(gulberg.id).notifier),
    run: (c) => c.read(notificationsProvider(gulberg.id).notifier).loadMore(),
    gate: (app) => app.notifications.gate,
    setUp: (app) => app.notifications.pageLimit = 1,
  ),
  _Command(
    'marking a notification read',
    provider: notificationsProvider(gulberg.id),
    notifier: (c) => c.read(notificationsProvider(gulberg.id).notifier),
    run: (c) {
      final shown = c.read(notificationsProvider(gulberg.id)).value!.value;
      return c
          .read(notificationsProvider(gulberg.id).notifier)
          .markRead(shown.items.firstWhere((n) => n.unread));
    },
    gate: (app) => app.notifications.gate,
  ),
];

void main() {
  group('an answer asked for before a portfolio left the list is not saved, '
      'and one asked for after it is:', () {
    for (final command in _answering) {
      test(command.name, () async {
        final app = TestApp();
        command.setUp?.call(app);
        final container = containerFor(app);
        listen(container, command.provider);
        await pumpEventQueue();
        final notifier = command.notifier(container);
        final query = notifier.query;
        expect(await _saved(app, query), isNotNull);
        final gate = command.gate(app)..close();
        // The command's request is on its way...
        final running = command.run(container);
        await pumpEventQueue();
        if (command.readAfterFailedWrite) {
          // ...its write fails, and the read it then makes is held.
          gate.holdLaterCallsApart()();
          await pumpEventQueue();
        }
        // ...when a portfolio leaves the list and its records go.
        await _portfolioLeft(app);
        gate.open();
        await running;
        await pumpEventQueue();
        expect(await _saved(app, query), isNull);
        // What is asked for after it is saved.
        await notifier.reload();
        expect(await _saved(app, query), isNotNull);
      });
    }
  });

  group('a command started after a portfolio left the list saves its '
      'answer, with no reload in between:', () {
    for (final command in _answering) {
      test(command.name, () async {
        final app = TestApp();
        // For the ledger, the refund's answer is lost again (setUp).
        command.setUp?.call(app);
        final container = containerFor(app);
        // The portfolio list is on show and saved, as in the app: a list
        // read again by the command (a portfolio's settings) then finds
        // nothing more has left it, and forgets nothing. The screen opens
        // once the list is saved: the first save of a session, finding no
        // saved list, forgets every record saved before it.
        listen(container, portfoliosProvider(testUserId));
        await pumpEventQueue();
        listen(container, command.provider);
        await pumpEventQueue();
        final query = command.notifier(container).query;
        expect(await _saved(app, query), isNotNull);
        // The value on show was asked for before the portfolio left...
        await _portfolioLeft(app);
        expect(await _saved(app, query), isNull);
        // ...and the command asks the server after it: its answer is saved
        // with the epoch read before its own request, not the shown one.
        await command.run(container);
        await pumpEventQueue();
        expect(await _saved(app, query), isNotNull);
      });
    }
  });

  group('a value made from one shown before a portfolio left the list is '
      'not saved, and one made after a reload is:', () {
    for (final command in _building) {
      test(command.name, () async {
        final app = TestApp();
        command.setUp?.call(app);
        final container = containerFor(app);
        listen(container, command.provider);
        await pumpEventQueue();
        final notifier = command.notifier(container);
        final query = notifier.query;
        expect(await _saved(app, query), isNotNull);
        // The rows on show were asked for before the portfolio left.
        await _portfolioLeft(app);
        await command.run(container);
        await pumpEventQueue();
        expect(await _saved(app, query), isNull);
        // Read again, they are saved with what is made from them.
        await notifier.reload();
        await pumpEventQueue();
        final reloaded = (await _saved(app, query))!.value;
        await command.run(container);
        await pumpEventQueue();
        expect((await _saved(app, query))!.value, isNot(equals(reloaded)));
      });
    }
  });
}
