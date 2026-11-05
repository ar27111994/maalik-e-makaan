import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _spoken = 'Payment score 82 out of 100, good';
const _caption = 'Based on 12 months of payments';

Widget _gauge({
  int score = 82,
  String band = 'Good',
  String? caption,
  double size = 120,
}) => MmScoreGauge(
  score: score,
  bandLabel: band,
  semanticLabel: _spoken,
  caption: caption,
  size: size,
);

/// The box the arc is drawn in.
Finder get _arcBox => find.descendant(
  of: find.byType(MmScoreGauge),
  matching: find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter != null,
  ),
);

void main() {
  group('MmScoreBand', () {
    test('bands scores at 50 and 75', () {
      expect(MmScoreBand.of(100), MmScoreBand.good);
      expect(MmScoreBand.of(75), MmScoreBand.good);
      expect(MmScoreBand.of(74), MmScoreBand.fair);
      expect(MmScoreBand.of(50), MmScoreBand.fair);
      expect(MmScoreBand.of(49), MmScoreBand.poor);
      expect(MmScoreBand.of(0), MmScoreBand.poor);
    });

    test('takes the status colours and icons of its band', () {
      for (final colors in [
        MmColorModes.light,
        MmColorModes.dark,
        MmColorModes.lightHighContrast,
        MmColorModes.darkHighContrast,
      ]) {
        expect(MmScoreBand.good.colorIn(colors), colors.paid);
        expect(MmScoreBand.good.containerIn(colors), colors.paidContainer);
        expect(MmScoreBand.good.onContainerIn(colors), colors.onPaidContainer);
        expect(MmScoreBand.fair.colorIn(colors), colors.dueSoon);
        expect(MmScoreBand.fair.containerIn(colors), colors.dueSoonContainer);
        expect(
          MmScoreBand.fair.onContainerIn(colors),
          colors.onDueSoonContainer,
        );
        expect(MmScoreBand.poor.colorIn(colors), colors.overdue);
        expect(MmScoreBand.poor.containerIn(colors), colors.overdueContainer);
        expect(
          MmScoreBand.poor.onContainerIn(colors),
          colors.onOverdueContainer,
        );
      }
      expect(MmScoreBand.good.icon, MmIcons.success);
      expect(MmScoreBand.fair.icon, MmIcons.warning);
      expect(MmScoreBand.poor.icon, MmIcons.error);
    });
  });

  group('MmScoreGauge', () {
    testEveryVariant('draws the arc in the band colour over a thin track', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _gauge(), variant: variant);
      final colors = colorsOf(variant);
      final box = tester.getSize(_arcBox);
      final stroke = box.width / 10;
      final arc = Rect.fromCircle(
        center: Offset(box.width / 2, box.width / 2),
        radius: box.width / 2 - stroke / 2,
      );
      final ltr = variant != MmVariant.urdu;
      expect(
        tester.renderObject(_arcBox),
        paints
          ..arc(
            rect: arc,
            startAngle: math.pi,
            sweepAngle: math.pi,
            color: colors.rule,
            strokeWidth: stroke / 2,
            strokeCap: StrokeCap.round,
          )
          ..arc(
            rect: arc,
            // From the start side: the left in English, the right in Urdu.
            startAngle: ltr ? math.pi : 0,
            sweepAngle: (ltr ? 1 : -1) * math.pi * 0.82,
            color: colors.paid,
            strokeWidth: stroke,
          ),
      );
    });

    testEveryVariant('shows the number in the amount face and the band in '
        'words with an icon', (tester, variant) async {
      await pumpThemed(
        tester,
        _gauge(score: 61, band: 'Fair'),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final number = styleOf(tester, '61');
      expect(number.fontFamily, contains(MmFontFamily.latin));
      expect(number.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(number.color, colors.ink);
      expect(styleOf(tester, 'Fair').color, colors.onDueSoonContainer);
      expect(
        tester.widget<Icon>(find.byIcon(MmIcons.warning)).color,
        colors.onDueSoonContainer,
      );
      final chip =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.byIcon(MmIcons.warning),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(chip.color, colors.dueSoonContainer);
      // The number sits inside the arc, the band under it.
      final arc = tester.getRect(_arcBox);
      final numberRect = tester.getRect(find.text('61'));
      expect(arc.contains(numberRect.center), isTrue);
      expect(
        tester.getRect(find.byIcon(MmIcons.warning)).top,
        greaterThan(arc.bottom),
      );
    });

    testWidgets('is exactly its semantic label; the caption reads after it', (
      tester,
    ) async {
      await pumpThemed(tester, _gauge(caption: _caption));
      expect(
        tester.getSemantics(find.text('82')),
        matchesSemantics(label: _spoken),
      );
      expect(find.bySemanticsLabel(_spoken), findsOneWidget);
      expect(find.bySemanticsLabel('Good'), findsNothing);
      expect(
        tester.getSemantics(find.text(_caption)),
        matchesSemantics(label: _caption),
      );
    });

    testWidgets('clamps scores to 0 to 100', (tester) async {
      await pumpThemed(tester, _gauge(score: 140));
      expect(find.text('100'), findsOneWidget);
      final box = tester.getSize(_arcBox);
      expect(
        tester.renderObject(_arcBox),
        paints
          ..arc(sweepAngle: math.pi)
          ..arc(sweepAngle: math.pi, color: MmColorModes.light.paid),
      );

      await pumpThemed(tester, _gauge(score: -10, band: 'Poor'));
      expect(find.text('0'), findsOneWidget);
      // An empty gauge draws only its track.
      expect(
        tester.renderObject(_arcBox),
        paintsExactlyCountTimes(#drawArc, 1),
      );
      expect(tester.getSize(_arcBox), box);
    });

    testWidgets('is as wide as its size, and its caption sits under it', (
      tester,
    ) async {
      await pumpThemed(tester, _gauge(size: 96, caption: _caption));
      final box = tester.getSize(_arcBox);
      expect(box.width, 96);
      expect(box.height, 96 / 2 + 96 / 10 / 2);
      final band = tester.getRect(find.byIcon(MmIcons.success));
      expect(tester.getRect(find.text(_caption)).top, greaterThan(band.bottom));
      expect(
        tester.getCenter(find.text(_caption)).dx,
        moreOrLessEquals(tester.getCenter(_arcBox).dx, epsilon: 0.01),
      );
      expect(styleOf(tester, _caption).color, MmColorModes.light.inkMuted);
    });

    testWidgets('grows with the text size', (tester) async {
      await pumpLargeNarrow(tester, _gauge(caption: _caption));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_arcBox).width, 240);
      final arc = tester.getRect(_arcBox);
      expect(arc.contains(tester.getRect(find.text('82')).center), isTrue);
    });

    testWidgets('at 200% on a 320 dp phone, scales a large gauge down to fit '
        'without overflowing', (tester) async {
      await pumpLargeNarrow(tester, _gauge(size: 200, caption: _caption));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_arcBox).width, lessThanOrEqualTo(288));
      final gauge = tester.getRect(find.byType(MmScoreGauge));
      expect(gauge.width, lessThanOrEqualTo(288));
    });

    testWidgets('fits a long number into a small gauge', (tester) async {
      await pumpLargeNarrow(tester, _gauge(score: 100, size: 48));
      expect(tester.takeException(), isNull);
      final arc = tester.getRect(_arcBox);
      final number = tester.getRect(find.text('100'));
      expect(number.width, lessThanOrEqualTo(arc.width));
    });

    testWidgets('repaints when the score changes', (tester) async {
      await pumpThemed(tester, _gauge(score: 40, band: 'Poor'));
      await pumpThemed(tester, _gauge(score: 90));
      expect(
        tester.renderObject(_arcBox),
        paints
          ..arc()
          ..arc(sweepAngle: math.pi * 0.9, color: MmColorModes.light.paid),
      );
    });

    test('needs a positive size', () {
      expect(
        () => MmScoreGauge(
          score: 50,
          bandLabel: 'Fair',
          semanticLabel: 'Payment score 50 out of 100, fair',
          size: 0,
        ),
        throwsAssertionError,
      );
    });
  });
}
