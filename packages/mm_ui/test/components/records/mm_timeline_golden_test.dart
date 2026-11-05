@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// A tenant's history, newest first: icon and dot markers in each tone, an
/// item with no detail line, and a title long enough to wrap.
Widget timelineGolden() => GoldenPage(
  (context, say) => Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(MmSpace.s4),
      child: MmTimeline(
        items: [
          MmTimelineItem(
            dateLabel: say('7 Oct 2026', '7 اکتوبر 2026'),
            title: say('Payment received', 'ادائیگی موصول ہوئی'),
            subtitle: say(
              'Rs 45,000 by bank transfer',
              'بینک ٹرانسفر سے 45,000 روپے',
            ),
            icon: MmIcons.payment,
            tone: MmTimelineTone.paid,
          ),
          MmTimelineItem(
            dateLabel: say('5 Oct 2026', '5 اکتوبر 2026'),
            title: say('October rent due', 'اکتوبر کا کرایہ واجب الادا'),
            subtitle: say('Rs 45,000', '45,000 روپے'),
            tone: MmTimelineTone.dueSoon,
          ),
          MmTimelineItem(
            dateLabel: say('11 Sep 2026', '11 ستمبر 2026'),
            title: say('September rent overdue', 'ستمبر کا کرایہ بقایا'),
            subtitle: say('6 days late', '6 دن تاخیر'),
            icon: MmIcons.warning,
            tone: MmTimelineTone.overdue,
          ),
          MmTimelineItem(
            dateLabel: say('1 Sep 2026', '1 ستمبر 2026'),
            title: say(
              'Lease renewed for 11 months at Rs 45,000',
              'معاہدے کی 11 ماہ کے لیے 45,000 روپے پر تجدید',
            ),
            icon: MmIcons.lease,
            tone: MmTimelineTone.primary,
          ),
          MmTimelineItem(
            dateLabel: say('1 Aug 2025', '1 اگست 2025'),
            title: say('Ali Raza moved in', 'علی رضا منتقل ہوئے'),
          ),
        ],
      ),
    ),
  ),
);

/// The surface mm_timeline goldens are drawn on: tall enough for the
/// history at 200% text.
const timelineGoldenSize = Size(360, 1100);

void main() {
  goldenEveryVariant('mm_timeline', timelineGolden, size: timelineGoldenSize);
}
