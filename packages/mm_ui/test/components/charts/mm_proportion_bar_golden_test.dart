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
              '60% ادا، 16% اس ہفتے واجب، 12% بقایا، 12% ابھی واجب نہیں',
            ),
            segments: [
              MmProportionSegment(
                label: say('Paid', 'ادا شدہ'),
                value: const Money.fromRupees(75000),
                tone: MmSegmentTone.paid,
              ),
              MmProportionSegment(
                label: say('Due this week', 'اس ہفتے واجب'),
                value: const Money.fromRupees(20000),
                tone: MmSegmentTone.dueSoon,
              ),
              MmProportionSegment(
                label: say('Overdue', 'بقایا'),
                value: const Money.fromRupees(15000),
                tone: MmSegmentTone.overdue,
              ),
              MmProportionSegment(
                label: say('Not yet due', 'ابھی واجب نہیں'),
                value: const Money.fromRupees(15000),
                tone: MmSegmentTone.neutral,
              ),
            ],
          ),
        ),
        chartCard(
          context,
          heading: say('Overdue by age', 'بقایا، مدت کے لحاظ سے'),
          MmProportionBar(
            semanticSummary: say(
              '45% 1 to 30 days late, 30% 31 to 60 days, 25% over 60 days',
              '45% ایک سے 30 دن، 30% 31 سے 60 دن، 25% 60 دن سے زیادہ',
            ),
            segments: [
              MmProportionSegment(
                label: say('1–30 days', '1 تا 30 دن'),
                value: const Money.fromRupees(45000),
                tone: MmSegmentTone.dueSoon,
              ),
              MmProportionSegment(
                label: say('31–60 days', '31 تا 60 دن'),
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
              '83% زرِ ضمانت، 17% پیشگی کرایہ',
            ),
            segments: [
              MmProportionSegment(
                label: say('Security deposits', 'زرِ ضمانت'),
                value: const Money.fromRupees(150000),
                tone: MmSegmentTone.primary,
              ),
              MmProportionSegment(
                label: say('Advance rent', 'پیشگی کرایہ'),
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
              'ابھی کوئی کرایہ واجب نہیں',
            ),
            emptyLabel: say(
              'No rent is due yet for December.',
              'دسمبر کا کرایہ ابھی واجب نہیں ہوا۔',
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

void main() {
  goldenEveryVariant(
    'mm_proportion_bar',
    proportionBarGolden,
    size: const Size(360, 1500),
  );
}
