import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/payment_score_section.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/reports_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/tax_year_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(360, 4000);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label, String option) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Widget _reports() => const ReportsScreen();
Widget _taxYear() => const TaxYearScreen();

void main() {
  group('reports', () {
    testWidgets('chart the year, the properties and the scores', (
      tester,
    ) async {
      await pumpScreen(tester, _reports, size: _tall);
      expect(find.text('Cash flow, last 12 months'), findsOneWidget);
      expect(find.byType(MmBarChart), findsNWidgets(2));
      // What went out is drawn inside what came in.
      final flow = tester.widget<MmBarChart>(find.byType(MmBarChart).first);
      expect(flow.series.map((s) => (s.label, s.fill)), [
        ('Money in', MmBarFill.outlined),
        ('Money out', MmBarFill.solid),
      ]);
      expect(find.text('Gross yield'), findsOneWidget);
      expect(find.text('3.4% a year'), findsOneWidget);
      expect(
        find.text("Add the property's estimated value to see its yield."),
        findsOneWidget,
      );
      // The lowest score first.
      final ali = tester.getTopLeft(find.text('Ali Raza')).dy;
      final indus = tester.getTopLeft(find.text('Indus Tech (Pvt) Ltd')).dy;
      expect(ali, lessThan(indus));
      expect(shown('22/100'), findsOneWidget);
      expect(shown('100/100'), findsOneWidget);
      expect(shown('Owes 1.5 months'), findsOneWidget);
      expect(shown('Nothing overdue'), findsOneWidget);
    });

    testWidgets('a score opens the tenant', (tester) async {
      await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Ali Raza');
      expect(routeShown(Routes.tenant(aliRaza.id)), findsOneWidget);
    });

    testWidgets('the tax-year statement opens', (tester) async {
      await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Tax-year statement');
      expect(routeShown(Routes.taxYear), findsOneWidget);
    });

    testWidgets('a quiet year and a portfolio with one property', (
      tester,
    ) async {
      final app = TestApp()
        ..insights.quietCashflow = true
        ..insights.performanceAnswer = [performanceJson().first]
        ..insights.factsAnswer = [];
      await pumpScreen(tester, _reports, app: app, size: _tall);
      expect(
        find.text('No money came in or went out in the last 12 months.'),
        findsOneWidget,
      );
      // One property: no chart to compare it with.
      expect(find.byType(MmBarChart), findsNothing);
      expect(
        find.text('Scores appear once rent has fallen due.'),
        findsOneWidget,
      );
    });

    testWidgets('no properties yet', (tester) async {
      final app = TestApp()..insights.performanceAnswer = [];
      await pumpScreen(tester, _reports, app: app, size: _tall);
      expect(
        find.text('Add a property to see its income and expenses here.'),
        findsOneWidget,
      );
    });

    testWidgets('says what could not be read', (tester) async {
      final app = TestApp()..insights.failure = const ServerFailure('x');
      await pumpScreen(tester, _reports, app: app, size: _tall);
      expect(find.text('The cash flow could not be loaded'), findsOneWidget);
      expect(
        find.text("The properties' figures could not be loaded"),
        findsOneWidget,
      );
      expect(
        find.text('The payment scores could not be loaded'),
        findsOneWidget,
      );
      app.insights.failure = null;
      for (var i = 0; i < 3; i++) {
        await _tap(tester, 'Try again');
      }
      expect(find.text('Payment scores'), findsOneWidget);
      expect(shown('22/100'), findsOneWidget);
    });

    testWidgets('shows nothing until a portfolio is chosen', (tester) async {
      await pumpScreen(tester, _reports, app: TestApp(portfolios: const []));
      expect(find.text('Payment scores'), findsNothing);
    });

    testWidgets("the scores wait for the tenants' names", (tester) async {
      final app = TestApp()..ledger.gate.close();
      await pumpScreen(tester, _reports, app: app, size: _tall, settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Loading the payment scores'), findsOne);
      expect(
        find.text('Scores appear once rent has fallen due.'),
        findsNothing,
      );
      app.ledger.gate.open();
      await tester.pumpAndSettle();
      expect(shown('22/100'), findsOneWidget);
    });

    testWidgets("say when the tenants' names cannot be read", (tester) async {
      final app = TestApp()..ledger.readFailure = const ServerFailure('x');
      await pumpScreen(tester, _reports, app: app, size: _tall);
      expect(
        find.text('The payment scores could not be loaded'),
        findsOneWidget,
      );
      expect(
        find.text('Scores appear once rent has fallen due.'),
        findsNothing,
      );
      app.ledger.readFailure = null;
      await _tap(tester, 'Try again');
      expect(shown('22/100'), findsOneWidget);
    });
  });

  group('the owner statement', () {
    testWidgets('last month by default, shared in the chosen language', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Owner statement');
      expect(find.text('October 2026'), findsOneWidget);
      await _select(tester, 'Month', 'September 2026');
      await tester.tap(find.byType(Radio<DocumentLanguage>).last);
      await tester.pumpAndSettle();
      await _tap(tester, 'Share PDF');
      expect(app.made.single, ('owner statement', DocumentLanguage.urdu));
      final shared = app.sharer.shared.single;
      expect(shared.fileName, 'owner-statement-2026-09.pdf');
      expect(shared.title, 'مالک کا گوشوارہ، ستمبر 2026');
      expect(
        app.insights.calls.lastWhere((c) => c.$1 == 'cashflow').$2.skip(1),
        [CalendarDate(2026, 9, 1), CalendarDate(2026, 9, 30)],
      );
      // The sheet closes.
      expect(find.text('Language of the document'), findsNothing);
    });

    testWidgets('says why it could not be made', (tester) async {
      final app = TestApp()..sharer.failure = const NetworkFailure();
      await pumpScreen(tester, _reports, app: app, size: _tall);
      await _tap(tester, 'Owner statement');
      await _tap(tester, 'Share PDF');
      expect(shown('No connection'), findsOneWidget);
    });

    testWidgets('a maker that breaks is an unexpected failure', (tester) async {
      final app = TestApp()..makeError = StateError('no fonts');
      await pumpScreen(tester, _reports, app: app, size: _tall);
      await _tap(tester, 'Owner statement');
      await _tap(tester, 'Share PDF');
      expect(shown('Something went wrong. Please try again.'), findsOneWidget);
    });
  });

  group('the export', () {
    testWidgets('shares the chosen rows as a CSV file', (tester) async {
      final app = await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Export to a spreadsheet');
      await _tap(tester, 'Expenses');
      await _select(tester, 'Period', 'Tax year 2026: July 2025 to June 2026');
      await _tap(tester, 'Export CSV');
      final shared = app.sharer.shared.single;
      expect(shared.fileName, 'expenses-2025-07-01-2026-06-30.csv');
      expect(documentMimeType(shared.fileName), 'text/csv');
      expect(shared.title, 'Expenses, Tax year 2026: July 2025 to June 2026');
      expect(utf8.decode(shared.bytes.sublist(3)), startsWith('Spent on,'));
      expect(app.insights.calls.last.$2.skip(1), [
        CalendarDate(2025, 7, 1),
        CalendarDate(2026, 6, 30),
      ]);
    });

    testWidgets('says when the period has nothing to export', (tester) async {
      final app = await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Export to a spreadsheet');
      await _select(tester, 'Period', 'Last month');
      await _tap(tester, 'Export CSV');
      expect(find.text('Nothing was recorded in that period.'), findsOneWidget);
      expect(app.sharer.shared, isEmpty);
      expect(app.insights.calls.last.$2.skip(1), [
        CalendarDate(2026, 10, 1),
        CalendarDate(2026, 10, 31),
      ]);
      // Choosing again clears it.
      await _tap(tester, 'Payments');
      expect(find.text('Nothing was recorded in that period.'), findsNothing);
      await _tap(tester, 'Export CSV');
      expect(find.text('Nothing was recorded in that period.'), findsOneWidget);
      await _select(tester, 'Period', 'This month');
      expect(find.text('Nothing was recorded in that period.'), findsNothing);
    });

    testWidgets('exports the ledger and payments with whose they are', (
      tester,
    ) async {
      final ledger = FakeLedgerRepository();
      const tenancy = ExportTenancy(
        tenantName: 'Ali Raza',
        unitLabel: 'Ground floor',
        propertyName: 'Gulberg House',
      );
      final app = TestApp()
        ..insights.charges = [
          for (final c in ledger.chargesOf[aliLease.id]!)
            ExportCharge(charge: c, tenancy: tenancy),
        ]
        ..insights.payments = [
          for (final p in ledger.paymentsOf[aliLease.id]!)
            ExportPayment(payment: p, tenancy: tenancy),
        ];
      await pumpScreen(tester, _reports, app: app, size: _tall);
      await _tap(tester, 'Export to a spreadsheet');
      await _tap(tester, 'Export CSV');
      expect(app.sharer.shared.single.fileName, startsWith('ledger-'));
      await _tap(tester, 'Export to a spreadsheet');
      await _tap(tester, 'Payments');
      await _tap(tester, 'Export CSV');
      expect(app.sharer.shared.last.fileName, startsWith('payments-'));
    });

    testWidgets('says why it failed', (tester) async {
      final app = await pumpScreen(tester, _reports, size: _tall);
      await _tap(tester, 'Export to a spreadsheet');
      app.insights.failure = const Forbidden();
      await _tap(tester, 'Export CSV');
      expect(shown('You do not have permission'), findsOneWidget);
    });
  });

  group('the tax year', () {
    testWidgets('shows each property and the totals, not as tax advice', (
      tester,
    ) async {
      await pumpScreen(tester, _taxYear, size: const Size(360, 2400));
      expect(find.text('Not tax advice'), findsOneWidget);
      expect(
        find.text('Tax year 2027: July 2026 to June 2027'),
        findsOneWidget,
      );
      expect(find.text('Gulberg House'), findsOneWidget);
      expect(find.text('All properties'), findsOneWidget);
      expect(find.text('Society charges'), findsNWidgets(2));
    });

    testWidgets('shares a PDF in the chosen language and a CSV file', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _taxYear);
      await _tap(tester, 'Share PDF');
      await _tap(tester, 'Share PDF');
      expect(app.made.single, ('tax year', DocumentLanguage.english));
      expect(app.sharer.shared.single.fileName, 'tax-year-2027.pdf');
      expect(app.sharer.shared.single.title, 'Tax-year statement 2027');
      await _tap(tester, 'Share CSV');
      expect(app.sharer.shared.last.fileName, 'tax-year-2027.csv');
    });

    testWidgets('a CSV that cannot be shared says why', (tester) async {
      final app = TestApp()..sharer.failure = const NetworkFailure();
      await pumpScreen(tester, _taxYear, app: app);
      await _tap(tester, 'Share CSV');
      expect(shown('No connection'), findsOneWidget);
    });

    testWidgets('an earlier year with nothing recorded', (tester) async {
      await pumpScreen(tester, _taxYear);
      await _select(
        tester,
        'Tax year',
        'Tax year 2025: July 2024 to June 2025',
      );
      expect(
        find.text('No rent or expenses were recorded in this tax year.'),
        findsOneWidget,
      );
      expect(find.text('Share CSV'), findsNothing);
    });

    testWidgets('one property has no totals', (tester) async {
      final app = TestApp()..insights.taxYearAnswer = [taxYearJson().first];
      await pumpScreen(tester, _taxYear, app: app, size: const Size(360, 2000));
      expect(find.text('All properties'), findsNothing);
    });

    testWidgets('says when it cannot be read', (tester) async {
      final app = TestApp()
        ..insights.failure = const RejectedFailure('invalid_tax_year');
      await pumpScreen(tester, _taxYear, app: app);
      expect(find.text('The tax year could not be loaded'), findsOneWidget);
      expect(find.text('Choose a valid tax year.'), findsOneWidget);
      app.insights.failure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Gulberg House'), findsOneWidget);
    });

    testWidgets('waits for a portfolio', (tester) async {
      await pumpScreen(tester, _taxYear, app: TestApp(portfolios: const []));
      expect(find.text('Not tax advice'), findsOneWidget);
      expect(find.text('Share CSV'), findsNothing);
    });
  });

  group('a tenant payment score', () {
    Widget section(String tenantId) => MmPage(
      title: 'Tenant',
      body: PaymentScoreSection(tenantId: tenantId),
    );

    testWidgets('shows the gauge and what it is made of', (tester) async {
      await pumpScreen(tester, () => section(aliRaza.id));
      final gauge = tester.widget<MmScoreGauge>(find.byType(MmScoreGauge));
      expect(gauge.score, 22);
      expect(gauge.bandLabel, 'Often late');
      expect(gauge.semanticLabel, 'Payment score 22 out of 100, Often late');
      expect(gauge.caption, contains('On time 1 of 4'));
    });

    testWidgets('a tenant without history has none yet', (tester) async {
      await pumpScreen(tester, () => section(formerTenant.id));
      expect(
        find.text('Not enough rent history for a score yet.'),
        findsOneWidget,
      );
    });

    testWidgets('says when the scores cannot be read', (tester) async {
      final app = TestApp()..insights.failure = const ServerFailure('x');
      await pumpScreen(tester, () => section(aliRaza.id), app: app);
      expect(
        find.text('The payment scores could not be loaded'),
        findsOneWidget,
      );
      app.insights.failure = null;
      await _tap(tester, 'Try again');
      expect(find.byType(MmScoreGauge), findsOneWidget);
    });

    testWidgets('shows a skeleton while loading', (tester) async {
      final app = TestApp()..insights.gate.close();
      await pumpScreen(
        tester,
        () => section(aliRaza.id),
        app: app,
        settle: false,
      );
      expect(find.byType(MmSkeleton), findsOneWidget);
      app.insights.gate.open();
      await tester.pumpAndSettle();
    });

    testWidgets('waits for a portfolio', (tester) async {
      await pumpScreen(
        tester,
        () => section(aliRaza.id),
        app: TestApp(portfolios: const []),
      );
      expect(find.text('Payment score'), findsNothing);
    });
  });
}
