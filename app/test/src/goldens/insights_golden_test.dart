@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/dashboard_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/payment_score_section.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/reports_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/search_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/tax_year_screen.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Ali Raza's tenant id ([aliRaza] is not a constant).
const aliRazaId = '0192d0c4-4444-7000-8000-000000000001';

void main() {
  screenGoldenEveryVariant(
    'dashboard',
    () => const DashboardScreen(),
    size: const Size(360, 3560),
    sizes: {
      MmVariant.largeText: const Size(360, 8300),
      MmVariant.urdu: const Size(360, 4610),
    },
  );

  // Every insight card, past the first three.
  screenGoldenEveryVariant(
    'dashboard_insights',
    () => const DashboardScreen(),
    size: const Size(360, 5090),
    sizes: {
      MmVariant.largeText: const Size(360, 11750),
      MmVariant.urdu: const Size(360, 6590),
    },
    // Tall enough to show the whole page, the button included.
    act: (tester) async {
      await tester.tap(find.byIcon(MmIcons.expand));
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'dashboard_quiet',
    () => const DashboardScreen(),
    app: () => TestApp()
      ..insights.dashboardAnswer = quietDashboardJson()
      ..insights.positions = const []
      ..insights.rentRollAnswer = [],
  );

  screenGoldenEveryVariant(
    'reports',
    () => const ReportsScreen(),
    size: const Size(360, 2580),
    sizes: {
      MmVariant.largeText: const Size(360, 5270),
      MmVariant.urdu: const Size(360, 3110),
    },
  );

  screenGoldenEveryVariant(
    'tax_year',
    () => const TaxYearScreen(),
    size: const Size(360, 2300),
    sizes: {
      MmVariant.largeText: const Size(360, 5600),
      MmVariant.urdu: const Size(360, 3100),
    },
  );

  screenGoldenEveryVariant(
    'search',
    () => const SearchScreen(),
    app: () => TestApp()..insights.searchFilters = false,
    sizes: {MmVariant.largeText: const Size(360, 1400)},
    act: (tester) async {
      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pump(SearchScreen.searchDelay);
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'payment_score',
    () => const MmPage(
      title: 'Ali Raza',
      body: PaymentScoreSection(tenantId: aliRazaId),
    ),
    sizes: {MmVariant.largeText: const Size(360, 1400)},
  );

  screenGoldenEveryVariant(
    'owner_statement_sheet',
    () => const ReportsScreen(),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 1800)},
    act: (tester) async {
      final tile = find.text('Owner statement').evaluate().isEmpty
          ? find.text('مالک کا گوشوارہ')
          : find.text('Owner statement');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'export_sheet',
    () => const ReportsScreen(),
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: (tester) async {
      final tile = find.text('Export to a spreadsheet').evaluate().isEmpty
          ? find.text('اسپریڈ شیٹ میں ایکسپورٹ')
          : find.text('Export to a spreadsheet');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    },
  );
}
