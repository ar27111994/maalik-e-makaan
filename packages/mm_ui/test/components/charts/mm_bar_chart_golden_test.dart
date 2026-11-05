@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'samples.dart';

/// Two charts on a dashboard: rent collected against due (two series, the
/// chart focused so June's readout shows) and net income (one series with a
/// loss below the zero line), in lakh grouping.
Widget barChartGolden() => GoldenPage(
  (context, say) => lakhGrouping(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MmSpace.s3,
      children: [
        chartCard(context, rentChart(say, autofocus: true)),
        chartCard(context, netIncomeChart(say)),
      ],
    ),
  ),
);

void main() {
  goldenEveryVariant(
    'mm_bar_chart',
    barChartGolden,
    size: const Size(360, 1100),
  );
}
