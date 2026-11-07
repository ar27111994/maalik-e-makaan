import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// [child] with amounts grouped in lakhs and crores ("Rs 1,25,000"), as a
/// Pakistani landlord would set it, in the ambient language.
Widget lakhGrouping(Widget child) => Builder(
  builder: (context) => MmFormats(
    money: MmFormats.defaultFor(Localizations.localeOf(context))
        .copyWith(grouping: DigitGrouping.southAsian),
    child: child,
  ),
);

/// A card with a heading over [child], as the charts sit on a screen.
Widget chartCard(BuildContext context, Widget child, {String? heading}) {
  final text = Theme.of(context).textTheme;
  return Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(MmSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          if (heading != null)
            Semantics(
              header: true,
              child: Text(heading, style: text.titleMedium),
            ),
          child,
        ],
      ),
    ),
  );
}

/// The months June to November, in the ambient language.
List<String> months(Say say) => [
  say('Jun', 'جون'),
  say('Jul', 'جولائی'),
  say('Aug', 'اگست'),
  say('Sep', 'ستمبر'),
  say('Oct', 'اکتوبر'),
  say('Nov', 'نومبر'),
];

/// Rent collected each month of [months] at Gulberg Heights.
const collected = [
  Money.fromRupees(110000),
  Money.fromRupees(125000),
  Money.fromRupees(125000),
  Money.fromRupees(95000),
  Money.fromRupees(125000),
  Money.fromRupees(45000),
];

/// Rent due each month of [months].
const due = Money.fromRupees(125000);

/// Net income each month of [months]: August paid for a new water pump.
const netIncome = [
  Money.fromRupees(85000),
  Money.fromRupees(92000),
  Money.fromRupees(-30000),
  Money.fromRupees(105000),
  Money.fromRupees(98000),
  Money.fromRupees(60000),
];

/// The rent chart of the samples: collected against due, by month.
MmBarChart rentChart(Say say, {bool autofocus = false}) => MmBarChart(
  title: say('Rent, last 6 months', 'کرایہ، پچھلے 6 ماہ'),
  semanticSummary: say(
    'Rent collected against rent due, June to November. '
        'November is lowest: Rs 45,000 of Rs 1,25,000.',
    'جون سے نومبر تک وصول شدہ اور واجب کرایہ۔ '
        'نومبر میں سب سے کم: 1,25,000 میں سے 45,000 روپے۔',
  ),
  groupLabel: say('Month', 'مہینہ'),
  autofocus: autofocus,
  series: [
    MmBarSeries(label: say('Collected', 'وصول شدہ')),
    MmBarSeries(label: say('Due', 'واجب')),
  ],
  groups: [
    for (final (index, month) in months(say).indexed)
      MmBarGroup(label: month, values: [collected[index], due]),
  ],
);

/// The net income chart of the samples: one series with a loss in August.
MmBarChart netIncomeChart(Say say) => MmBarChart(
  title: say('Net income', 'خالص آمدنی'),
  semanticSummary: say(
    'Net income, June to November. August was a loss of Rs 30,000.',
    'جون سے نومبر تک خالص آمدنی۔ اگست میں 30,000 روپے کا نقصان ہوا۔',
  ),
  groupLabel: say('Month', 'مہینہ'),
  series: [MmBarSeries(label: say('Net income', 'خالص آمدنی'))],
  groups: [
    for (final (index, month) in months(say).indexed)
      MmBarGroup(label: month, values: [netIncome[index]]),
  ],
);

/// Rent collected against rent due over a year at a building of shops in
/// Hall Road, Lahore: collected climbs back towards what is due.
MmBarChart yearChart(Say say) => MmBarChart(
  title: say('Rent, last 12 months', 'کرایہ، پچھلے 12 ماہ'),
  semanticSummary: say(
    'Rent collected against rent due, December to November. Collected '
        'rose from Rs 2.5 lakh to Rs 13.5 lakh.',
    'دسمبر سے نومبر تک وصول شدہ اور واجب کرایہ۔ وصولی 2.5 لاکھ سے بڑھ کر '
        '13.5 لاکھ روپے ہو گئی۔',
  ),
  groupLabel: say('Month', 'مہینہ'),
  series: [
    MmBarSeries(label: say('Collected', 'وصول شدہ')),
    MmBarSeries(label: say('Due', 'واجب')),
  ],
  groups: [
    for (final (index, month) in [
      say('Dec', 'دسمبر'),
      say('Jan', 'جنوری'),
      say('Feb', 'فروری'),
      say('Mar', 'مارچ'),
      say('Apr', 'اپریل'),
      say('May', 'مئی'),
      ...months(say),
    ].indexed)
      MmBarGroup(
        label: month,
        values: [
          Money.fromRupees(250000 + index * 100000),
          const Money.fromRupees(1250000),
        ],
      ),
  ],
);
