@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The three bands: a good score with its caption at the default size,
/// and a fair and a poor score at a smaller size.
Widget scoreGaugeGolden() => GoldenPage(
  (context, say) => Padding(
    padding: const EdgeInsetsDirectional.all(MmSpace.s2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: MmSpace.s6,
      children: [
        MmScoreGauge(
          score: 82,
          bandLabel: say('Good', 'اچھا'),
          semanticLabel: say(
            'Payment score 82 out of 100, good',
            'ادائیگی کا اسکور 100 میں سے 82، اچھا',
          ),
          caption: say(
            'Based on 12 months of payments',
            '12 مہینوں کی ادائیگیوں کی بنیاد پر',
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: MmSpace.s8,
          runSpacing: MmSpace.s6,
          children: [
            MmScoreGauge(
              score: 61,
              bandLabel: say('Fair', 'درمیانہ'),
              semanticLabel: say(
                'Payment score 61 out of 100, fair',
                'ادائیگی کا اسکور 100 میں سے 61، درمیانہ',
              ),
              size: 96,
            ),
            MmScoreGauge(
              score: 34,
              bandLabel: say('Poor', 'کمزور'),
              semanticLabel: say(
                'Payment score 34 out of 100, poor',
                'ادائیگی کا اسکور 100 میں سے 34، کمزور',
              ),
              size: 96,
            ),
          ],
        ),
      ],
    ),
  ),
);

void main() {
  goldenEveryVariant('mm_score_gauge', scoreGaugeGolden);
}
