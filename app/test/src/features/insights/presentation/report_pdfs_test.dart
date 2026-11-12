import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/report_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';

/// How many pages [pdf] has, read from its page objects.
int _pages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

/// How many images [pdf] holds (the Urdu text Flutter drew).
int _images(Uint8List pdf) =>
    RegExp(r'/Subtype\s*/Image').allMatches(latin1.decode(pdf)).length;

void main() {
  DocumentSetup setup(DocumentLanguage language, {String issuer = 'Ayesha'}) =>
      DocumentSetup(
        language: language,
        issuer: issuer,
        today: CalendarDate(2026, 11, 7),
      );

  final taxYear = TaxYearStatement(
    taxYear: TaxYear(2026),
    properties: [for (final row in taxYearJson()) TaxYearProperty.fromRow(row)],
  );

  final dashboard = Dashboard.fromJson(dashboardJson());
  final owner = OwnerStatement(
    portfolioName: 'Gulberg Houses',
    month: MonthPeriod(2026, 10),
    flow: CashflowMonth.fromRow(cashflowJson(MonthPeriod(2026, 10), 2)),
    properties: [
      for (final row in performanceJson()) PropertyPerformance.fromRow(row),
    ],
    outstanding: dashboard.outstanding,
    arrears: dashboard.topArrears,
    cash: FakeHandoverRepository().positions,
    asOf: dashboard.asOf,
  );

  testWidgets('a tax-year statement in English is PDF text', (tester) async {
    final pdf = (await tester.runAsync(
      () => taxYearPdf(taxYear, setup(DocumentLanguage.english)),
    ))!;
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_pages(pdf), greaterThanOrEqualTo(1));
    expect(_images(pdf), 0);
  });

  testWidgets('a tax-year statement in Urdu draws its Urdu with Flutter', (
    tester,
  ) async {
    final pdf = (await tester.runAsync(
      () => taxYearPdf(taxYear, setup(DocumentLanguage.urdu)),
    ))!;
    expect(_images(pdf), greaterThan(0));
  });

  testWidgets('a tax year with nothing, or one property, has no totals', (
    tester,
  ) async {
    for (final properties in [
      const <TaxYearProperty>[],
      [taxYear.properties.first],
    ]) {
      final pdf = (await tester.runAsync(
        () => taxYearPdf(
          TaxYearStatement(taxYear: TaxYear(2025), properties: properties),
          setup(DocumentLanguage.english),
        ),
      ))!;
      expect(_pages(pdf), 1);
    }
  });

  testWidgets('an owner statement in both languages', (tester) async {
    final english = (await tester.runAsync(
      () => ownerStatementPdf(owner, setup(DocumentLanguage.english)),
    ))!;
    expect(_images(english), 0);
    expect(_pages(english), greaterThanOrEqualTo(1));
    final urdu = (await tester.runAsync(
      () => ownerStatementPdf(owner, setup(DocumentLanguage.urdu)),
    ))!;
    expect(_images(urdu), greaterThan(0));
  });

  testWidgets('a quiet month says only what there is', (tester) async {
    final quiet = Dashboard.fromJson(quietDashboardJson());
    final pdf = (await tester.runAsync(
      () => ownerStatementPdf(
        OwnerStatement(
          portfolioName: 'Ayesha',
          month: MonthPeriod(2026, 10),
          flow: CashflowMonth(
            month: MonthPeriod(2026, 10),
            received: Money.zero,
            rent: Money.zero,
            deposits: Money.zero,
            other: Money.zero,
            taxWithheld: Money.zero,
            expenses: Money.zero,
            depositRefunds: Money.zero,
          ),
          properties: const [],
          outstanding: quiet.outstanding,
          arrears: const [],
          cash: const <CashPosition>[],
          asOf: quiet.asOf,
        ),
        setup(DocumentLanguage.english),
      ),
    ))!;
    expect(_pages(pdf), 1);
  });
}
