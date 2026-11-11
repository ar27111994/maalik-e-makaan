@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'samples.dart';

/// Every tone: November's rent by status (with a part not yet due),
/// overdue rent by age, tenant balances, and a month with nothing due yet.
Widget proportionBarGolden() => GoldenPage(
  (context, say) => lakhGrouping(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MmSpace.s3,
      children: [
        chartCard(
          context,
          heading: say('November rent', 'نومبر کا کرایہ'),
          MmProportionBar(
            semanticSummary: say(
              '60% paid, 16% due this week, 12% overdue, 12% not yet due',
              '60% ادا، 16% کی اس ہفتے تاریخ، 12% لیٹ، '
                  '12% کی ابھی تاریخ نہیں آئی',
            ),
            segments: [
              MmProportionSegment(
                label: say('Paid', 'ادا شدہ'),
                value: const Money.fromRupees(75000),
                tone: MmSegmentTone.paid,
              ),
              MmProportionSegment(
                label: say('Due this week', 'اس ہفتے تاریخ'),
                value: const Money.fromRupees(20000),
                tone: MmSegmentTone.dueSoon,
              ),
              MmProportionSegment(
                label: say('Overdue', 'لیٹ'),
                value: const Money.fromRupees(15000),
                tone: MmSegmentTone.overdue,
              ),
              MmProportionSegment(
                label: say('Not yet due', 'ابھی تاریخ نہیں آئی'),
                value: const Money.fromRupees(15000),
                tone: MmSegmentTone.neutral,
              ),
            ],
          ),
        ),
        chartCard(
          context,
          heading: say('Overdue by age', 'لیٹ، کتنے دن سے'),
          MmProportionBar(
            semanticSummary: say(
              '45% 1 to 30 days late, 30% 31 to 60 days, 25% over 60 days',
              '45% ایک سے 30 دن، 30% 31 سے 60 دن، 25% 60 دن سے زیادہ',
            ),
            segments: [
              MmProportionSegment(
                label: say('1–30 days', '1 سے 30 دن'),
                value: const Money.fromRupees(45000),
                tone: MmSegmentTone.dueSoon,
              ),
              MmProportionSegment(
                label: say('31–60 days', '31 سے 60 دن'),
                value: const Money.fromRupees(30000),
                tone: MmSegmentTone.overdue,
              ),
              MmProportionSegment(
                label: say('Over 60 days', '60 دن سے زیادہ'),
                value: const Money.fromRupees(25000),
                tone: MmSegmentTone.overdueSevere,
              ),
            ],
          ),
        ),
        chartCard(
          context,
          heading: say('Held for tenants', 'کرایہ داروں کی امانت'),
          MmProportionBar(
            semanticSummary: say(
              '83% security deposits, 17% advance rent',
              '83% سیکیورٹی ڈپازٹ، 17% ایڈوانس کرایہ',
            ),
            segments: [
              MmProportionSegment(
                label: say('Security deposits', 'سیکیورٹی ڈپازٹ'),
                value: const Money.fromRupees(150000),
                tone: MmSegmentTone.primary,
              ),
              MmProportionSegment(
                label: say('Advance rent', 'ایڈوانس کرایہ'),
                value: const Money.fromRupees(30000),
                tone: MmSegmentTone.credit,
              ),
            ],
          ),
        ),
        chartCard(
          context,
          heading: say('December rent', 'دسمبر کا کرایہ'),
          MmProportionBar(
            semanticSummary: say(
              'No rent due yet',
              'ابھی کسی کرائے کی تاریخ نہیں آئی',
            ),
            emptyLabel: say(
              'No rent is due yet for December.',
              'دسمبر کے کرائے کی ابھی تاریخ نہیں آئی۔',
            ),
            segments: [
              MmProportionSegment(
                label: say('Paid', 'ادا شدہ'),
                value: Money.zero,
                tone: MmSegmentTone.paid,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

/// What tenants owe by age in four overdue buckets and a part not yet due:
/// the lines, the lattice and the solid red grow heavier with age.
Widget proportionBarAgingGolden() => GoldenPage(
  (context, say) => lakhGrouping(
    chartCard(
      context,
      heading: say('Owed by age', 'باقی رقم، کتنی پرانی'),
      MmProportionBar(
        semanticSummary: say(
          '20% not yet due, 30% 1 to 30 days late, 20% 31 to 60 days, '
              '15% 61 to 90 days, 15% over 90 days',
          '20% کی ابھی تاریخ نہیں آئی، 30% ایک سے 30 دن، 20% 31 سے 60 دن، '
              '15% 61 سے 90 دن، 15% 90 دن سے زیادہ',
        ),
        segments: [
          MmProportionSegment(
            label: say('Not yet due', 'ابھی تاریخ نہیں آئی'),
            value: const Money.fromRupees(40000),
            tone: MmSegmentTone.neutral,
          ),
          MmProportionSegment(
            label: say('1–30 days', '1 سے 30 دن'),
            value: const Money.fromRupees(60000),
            tone: MmSegmentTone.dueSoon,
          ),
          MmProportionSegment(
            label: say('31–60 days', '31 سے 60 دن'),
            value: const Money.fromRupees(40000),
            tone: MmSegmentTone.overdue,
          ),
          MmProportionSegment(
            label: say('61–90 days', '61 سے 90 دن'),
            value: const Money.fromRupees(30000),
            tone: MmSegmentTone.overdueOlder,
          ),
          MmProportionSegment(
            label: say('Over 90 days', '90 دن سے زیادہ'),
            value: const Money.fromRupees(30000),
            tone: MmSegmentTone.overdueSevere,
          ),
        ],
      ),
    ),
  ),
);

void main() {
  goldenEveryVariant(
    'mm_proportion_bar_aging',
    proportionBarAgingGolden,
    sizes: const {MmVariant.largeText: Size(360, 1000)},
  );

  goldenEveryVariant(
    'mm_proportion_bar',
    proportionBarGolden,
    size: const Size(360, 1500),
  );
}
