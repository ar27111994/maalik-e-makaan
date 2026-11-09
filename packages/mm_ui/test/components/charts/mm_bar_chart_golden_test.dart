@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'samples.dart';

/// Two charts on a dashboard, in lakh grouping: rent collected against due
/// (two series), focused from the keyboard with September picked, and net
/// income (one series with a loss below the zero line) showing the latest
/// month.
Widget barChartGolden() => GoldenPage(
  (context, say) => lakhGrouping(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MmSpace.s3,
      children: [
        chartCard(context, rentChart(say)),
        chartCard(context, netIncomeChart(say)),
      ],
    ),
  ),
);

/// Money in and money out side by side, showing the latest month.
Widget barChartCashFlowGolden() => GoldenPage(
  (context, say) => lakhGrouping(chartCard(context, cashFlowChart(say))),
);

/// The rent chart swapped for its table.
Widget barChartTableGolden() => GoldenPage(
  (context, say) => lakhGrouping(chartCard(context, rentChart(say))),
);

/// Net income by unit: named groups, every one labelled. At 200% text the
/// names no longer fit under their bars and the chart is its table.
Widget barChartUnitsGolden() => GoldenPage(
  (context, say) => lakhGrouping(chartCard(context, unitsChart(say))),
);

/// A year of months on the narrowest phone.
Widget barChartYearGolden() => GoldenPage(
  width: 288,
  (context, say) => lakhGrouping(chartCard(context, yearChart(say))),
);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testEveryVariant('mm_bar_chart golden', (tester, variant) async {
    useKeyboardHighlights();
    await pumpThemed(
      tester,
      barChartGolden(),
      variant: variant,
      size: Size(360, switch (variant) {
        MmVariant.largeText => 1300,
        MmVariant.urdu => 1000,
        _ => 900,
      }),
    );
    // Tab past the table toggle to the chart, go to June and step forward
    // in time to September (leftward in Urdu).
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.home);
    final later = variant.locale.languageCode == 'ur'
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    for (var month = 0; month < 3; month++) {
      await _press(tester, later);
    }
    await expectAccessible(tester);
    await expectGolden('mm_bar_chart', variant);
  });

  testEveryVariant('mm_bar_chart_table golden', (tester, variant) async {
    await pumpThemed(
      tester,
      barChartTableGolden(),
      variant: variant,
      size: Size(360, variant == MmVariant.largeText ? 900 : 740),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectGolden('mm_bar_chart_table', variant);
  });

  goldenEveryVariant('mm_bar_chart_units', barChartUnitsGolden);

  goldenEveryVariant(
    'mm_bar_chart_cash_flow',
    barChartCashFlowGolden,
    sizes: const {MmVariant.largeText: Size(360, 900)},
  );

  goldenEveryVariant(
    'mm_bar_chart_year',
    barChartYearGolden,
    size: const Size(320, 740),
    sizes: const {MmVariant.largeText: Size(320, 900)},
  );
}
