import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';
import 'package:mm_ui/src/components/charts/mm_proportion_bar.dart';

import '../../support/testing.dart';
import 'samples.dart';

const _paid = MmProportionSegment(
  label: 'Paid',
  value: Money.fromRupees(75000),
  tone: MmSegmentTone.paid,
);
const _dueSoon = MmProportionSegment(
  label: 'Due this week',
  value: Money.fromRupees(20000),
  tone: MmSegmentTone.dueSoon,
);
const _overdue = MmProportionSegment(
  label: 'Overdue',
  value: Money.fromRupees(15000),
  tone: MmSegmentTone.overdue,
);
const _notDue = MmProportionSegment(
  label: 'Not yet due',
  value: Money.fromRupees(15000),
  tone: MmSegmentTone.neutral,
);

const _summary = '60% paid, 16% due this week, 12% overdue, 12% not yet due';

Widget _bar({
  List<MmProportionSegment> segments = const [
    _paid,
    _dueSoon,
    _overdue,
    _notDue,
  ],
  String? emptyLabel,
  double width = 328,
}) => SizedBox(
  width: width,
  child: MmProportionBar(
    segments: segments,
    semanticSummary: _summary,
    emptyLabel: emptyLabel,
  ),
);

Finder get _barPaint => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is MmProportionBarPainter,
);

MmProportionBarPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_barPaint).painter! as MmProportionBarPainter;

List<MmChartMark> _swatches(WidgetTester tester) => [
  for (final swatch in tester.widgetList<MmChartSwatch>(
    find.byType(MmChartSwatch),
  ))
    swatch.mark,
];

void main() {
  group('MmProportionSegment', () {
    test('compares by label, amount and tone and describes itself', () {
      const same = MmProportionSegment(
        label: 'Paid',
        value: Money.fromRupees(75000),
        tone: MmSegmentTone.paid,
      );
      expect(_paid, same);
      expect(_paid.hashCode, same.hashCode);
      expect(
        _paid,
        isNot(
          const MmProportionSegment(
            label: 'Paid',
            value: Money.fromRupees(75000),
            tone: MmSegmentTone.primary,
          ),
        ),
      );
      expect(
        _paid,
        isNot(
          const MmProportionSegment(
            label: 'Paid',
            value: Money.fromRupees(7500),
            tone: MmSegmentTone.paid,
          ),
        ),
      );
      expect(_paid, isNot(_dueSoon));
      expect(_paid.toString(), startsWith('MmProportionSegment("Paid", '));
      expect(_paid.toString(), endsWith(', paid)'));
    });
  });

  group('MmProportionBar.percentagesOf', () {
    test('rounds shares to whole percentages that add up to 100', () {
      expect(
        MmProportionBar.percentagesOf(const [
          Money.fromRupees(1),
          Money.fromRupees(1),
          Money.fromRupees(1),
        ]),
        [34, 33, 33],
      );
      expect(
        MmProportionBar.percentagesOf([
          for (final segment in [_paid, _dueSoon, _overdue, _notDue])
            segment.value,
        ]),
        [60, 16, 12, 12],
      );
    });

    test('counts negatives as zero and gives zero for an empty whole', () {
      expect(
        MmProportionBar.percentagesOf(const [
          Money.fromRupees(-500),
          Money.fromRupees(500),
        ]),
        [0, 100],
      );
      expect(MmProportionBar.percentagesOf(const [Money.zero, Money.zero]), [
        0,
        0,
      ]);
      expect(MmProportionBar.percentagesOf(const []), isEmpty);
    });
  });

  group('MmProportionBarPainter.widthsFor', () {
    test('splits the width less the gaps in proportion', () {
      final widths = MmProportionBarPainter.widthsFor([3, 1], 102);
      expect(widths, [75, 25]);
      expect(MmProportionBarPainter.widthsFor([1], 50), [50]);
    });

    test("widens a sliver to the least width at the others' expense", () {
      final widths = MmProportionBarPainter.widthsFor([999, 1], 202);
      expect(widths.last, MmProportionBar.minPartWidth);
      expect(widths.first, 200 - MmProportionBar.minPartWidth);
    });

    test('keeps exact widths when every part cannot have the least', () {
      final widths = MmProportionBarPainter.widthsFor([1, 1, 98], 12);
      expect(widths.reduce((a, b) => a + b), closeTo(8, 1e-9));
      expect(widths.first, closeTo(0.08, 1e-9));
    });

    test('draws nothing in a bar too narrow for the gaps', () {
      expect(MmProportionBarPainter.widthsFor([1, 1], 1), [0, 0]);
    });
  });

  group('MmProportionBar', () {
    testEveryVariant('draws each tone so neighbours differ without colour', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: [
            for (final tone in MmSegmentTone.values)
              MmProportionSegment(
                label: tone.name,
                value: const Money.fromRupees(10000),
                tone: tone,
              ),
          ],
        ),
        variant: variant,
        size: const Size(360, 900),
      );
      final colors = colorsOf(variant);
      final marks = [for (final part in _painter(tester).parts) part.mark];
      expect(marks, [
        MmChartMark(fill: colors.surface, stroke: colors.outline),
        MmChartMark(fill: colors.paid),
        MmChartMark(
          fill: colors.dueSoon,
          hatch: MmHatch.falling,
          hatchColor: colors.surface,
        ),
        MmChartMark(
          fill: colors.overdue,
          hatch: MmHatch.rising,
          hatchColor: colors.surface,
        ),
        MmChartMark(fill: colors.onOverdueContainer),
        MmChartMark(
          fill: colors.credit,
          hatch: MmHatch.falling,
          hatchColor: colors.surface,
        ),
        MmChartMark(fill: colors.primary),
      ]);
      // Every legend key is drawn with the mark of its part.
      expect(_swatches(tester), marks);
      // Every mark that carries a tone stands out from the surface (3:1).
      for (final mark in marks.skip(1)) {
        expect(
          mmContrastRatio(mark.fill, colors.surface),
          greaterThanOrEqualTo(3),
          reason: '$mark',
        );
      }
      expect(
        mmContrastRatio(colors.outline, colors.surface),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('runs the parts from the start edge, each as long as its '
        'share, 2 dp apart', (tester) async {
      await pumpThemed(tester, _bar());
      final bar = tester.getRect(_barPaint);
      expect(bar.height, MmProportionBar.barHeight);
      expect(bar.width, 328);
      final rects = _painter(tester).rectsIn(bar.size);
      expect(rects, hasLength(4));
      const room = 328 - 3 * MmSpace.sHalf;
      expect(rects.first.left, 0);
      expect(rects.first.width, closeTo(room * 0.6, 1e-9));
      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left - rects[i - 1].right,
          closeTo(MmSpace.sHalf, 1e-9),
        );
      }
      expect(rects.last.right, closeTo(328, 1e-9));
    });

    testWidgets('runs the parts from the right in Urdu', (tester) async {
      await pumpThemed(tester, _bar(), variant: MmVariant.urdu);
      final bar = tester.getRect(_barPaint);
      final rects = _painter(tester).rectsIn(bar.size);
      expect(rects.first.right, bar.width);
      expect(rects.first.width, closeTo((328 - 3 * MmSpace.sHalf) * 0.6, 1e-9));
      expect(rects.last.left, closeTo(0, 1e-9));
      final legend = tester.getRect(find.text('Paid'));
      expect(legend.right, lessThan(bar.right));
      final swatch = tester.getRect(find.byType(MmChartSwatch).first);
      expect(swatch.right, bar.right);
    });

    testWidgets('paints each part with xs corners', (tester) async {
      await pumpThemed(tester, _bar(segments: const [_paid, _dueSoon]));
      final colors = colorsOf(MmVariant.light);
      final rects = _painter(tester).rectsIn(tester.getSize(_barPaint));
      expect(
        _barPaint,
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              rects.first,
              const Radius.circular(MmRadius.xs),
            ),
            color: colors.paid,
          )
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              rects.last,
              const Radius.circular(MmRadius.xs),
            ),
            color: colors.dueSoon,
          ),
      );
    });

    testWidgets('rounds a sliver no more than half its width', (tester) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            _paid,
            MmProportionSegment(
              label: 'Overdue',
              value: Money.fromRupees(1),
              tone: MmSegmentTone.paid,
            ),
          ],
        ),
      );
      final rects = _painter(tester).rectsIn(tester.getSize(_barPaint));
      expect(
        _barPaint,
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              rects.last,
              const Radius.circular(MmProportionBar.minPartWidth / 2),
            ),
          ),
      );
    });

    testWidgets('draws nothing for a part of zero but keeps its legend row', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            _paid,
            MmProportionSegment(
              label: 'Overdue',
              value: Money.zero,
              tone: MmSegmentTone.overdue,
            ),
            MmProportionSegment(
              label: 'Written off',
              value: Money.fromRupees(-500),
              tone: MmSegmentTone.neutral,
            ),
          ],
        ),
      );
      expect(_painter(tester).parts, hasLength(1));
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('0%'), findsNWidgets(2));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('never shows 0% for something or 100% for less than all', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            MmProportionSegment(
              label: 'Paid',
              value: Money.fromRupees(999000),
              tone: MmSegmentTone.paid,
            ),
            MmProportionSegment(
              label: 'Overdue',
              value: Money.fromRupees(500),
              tone: MmSegmentTone.overdue,
            ),
          ],
        ),
      );
      expect(find.text('>99%'), findsOneWidget);
      expect(find.text('<1%'), findsOneWidget);
      // The sliver still shows in the bar.
      final rects = _painter(tester).rectsIn(tester.getSize(_barPaint));
      expect(rects.last.width, MmProportionBar.minPartWidth);
    });

    testEveryVariant('lists each part: key, label, amount and share', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, lakhGrouping(_bar()), variant: variant);
      final colors = colorsOf(variant);
      expect(find.byType(MmChartSwatch), findsNWidgets(4));
      final amount = styleOf(tester, '75,000');
      expect(amount.color, colors.ink);
      expect(amount.fontWeight, FontWeight.w600);
      expect(amount.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(amount.fontFamily, contains(MmFontFamily.latin));
      final shareStyle = styleOf(tester, '60%');
      expect(shareStyle.color, colors.inkMuted);
      expect(shareStyle.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(styleOf(tester, 'Paid').color, colors.ink);
      // The amounts sit at the end edge, level with the label.
      final row = tester.getRect(find.byType(MmProportionBar));
      final share = tester.getRect(find.text('60%'));
      if (variant == MmVariant.urdu) {
        expect(share.left, row.left);
      } else {
        expect(share.right, row.right);
      }
      expect(
        tester.getRect(find.textContaining('75,000')).center.dy,
        closeTo(tester.getRect(find.text('Paid')).center.dy, 2),
      );
    });

    testWidgets("formats amounts with the app's money format", (tester) async {
      await pumpThemed(
        tester,
        lakhGrouping(
          _bar(
            segments: const [
              MmProportionSegment(
                label: 'Deposits',
                value: Money.fromRupees(150000),
                tone: MmSegmentTone.primary,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Rs 1,50,000'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows an empty track and the empty label for a zero whole', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            MmProportionSegment(
              label: 'Paid',
              value: Money.zero,
              tone: MmSegmentTone.paid,
            ),
          ],
          emptyLabel: 'No rent is due yet.',
        ),
      );
      final colors = colorsOf(MmVariant.light);
      expect(_barPaint, findsNothing);
      final track = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(MmProportionBar),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = track.decoration as BoxDecoration;
      expect(decoration.color, colors.surfaceSunken);
      expect(decoration.border, Border.all(color: colors.rule));
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.xs)),
      );
      expect(find.text('No rent is due yet.'), findsOneWidget);
      expect(styleOf(tester, 'No rent is due yet.').color, colors.inkMuted);
      expect(find.text('Paid'), findsNothing);
    });

    testWidgets('lists every part at 0% for a zero whole with no label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            MmProportionSegment(
              label: 'Paid',
              value: Money.zero,
              tone: MmSegmentTone.paid,
            ),
            MmProportionSegment(
              label: 'Overdue',
              value: Money.zero,
              tone: MmSegmentTone.overdue,
            ),
          ],
        ),
      );
      expect(find.text('0%'), findsNWidgets(2));
      expect(find.text('Rs 0'), findsNWidgets(2));
    });

    testWidgets('repaints only when the parts or direction change', (
      tester,
    ) async {
      final colors = colorsOf(MmVariant.light);
      final paid = (mark: MmChartMark(fill: colors.paid), weight: 3);
      final due = (mark: MmChartMark(fill: colors.dueSoon), weight: 1);
      final painter = MmProportionBarPainter(
        parts: [paid, due],
        textDirection: TextDirection.ltr,
      );
      expect(
        painter.shouldRepaint(
          MmProportionBarPainter(
            parts: [paid, due],
            textDirection: TextDirection.ltr,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          MmProportionBarPainter(
            parts: [paid, due],
            textDirection: TextDirection.rtl,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          MmProportionBarPainter(
            parts: [paid, (mark: due.mark, weight: 2)],
            textDirection: TextDirection.ltr,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('reads the summary, then one node per legend row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, lakhGrouping(_bar()));
      expect(tester.getSemantics(_barPaint), matchesSemantics(label: _summary));
      expect(
        tester.getSemantics(find.text('Paid')),
        matchesSemantics(label: 'Paid\n75000 rupees\n60%'),
      );
      final bar = tester.getSemantics(find.byType(MmProportionBar));
      expect(labelsIn(bar), [
        _summary,
        'Paid\n75000 rupees\n60%',
        'Due this week\n20000 rupees\n16%',
        'Overdue\n15000 rupees\n12%',
        'Not yet due\n15000 rupees\n12%',
      ]);
      handle.dispose();
    });

    testWidgets('moves an amount that does not fit under its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          width: 220,
          segments: const [
            MmProportionSegment(
              label: 'Security deposits held',
              value: Money.fromRupees(150000),
              tone: MmSegmentTone.primary,
            ),
          ],
        ),
      );
      final label = tester.getRect(find.text('Security deposits held'));
      final amount = tester.getRect(find.text('Rs 150,000'));
      expect(amount.top, greaterThanOrEqualTo(label.bottom));
      expect(amount.left, label.left);
    });

    testWidgets('sets Urdu amounts in the Latin face in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            MmProportionSegment(
              label: 'ادا شدہ',
              value: Money.fromRupees(75000),
              tone: MmSegmentTone.paid,
            ),
          ],
        ),
        variant: MmVariant.urdu,
      );
      final amount = styleOf(tester, '75,000');
      expect(amount.fontFamily, contains(MmFontFamily.latin));
      expect(find.text('75,000 روپے'), findsOneWidget);
      // The share keeps its order ("<1%", "100%") in Urdu.
      expect(paragraphOf(tester, '100%').textDirection, TextDirection.ltr);
    });

    testWidgets('at 200% on a 320 dp phone, wraps without overflowing', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmProportionBar(
          semanticSummary: _summary,
          segments: [_paid, _dueSoon, _overdue, _notDue],
        ),
      );
      expect(
        tester.getSize(find.byType(MmChartSwatch).first).width,
        MmChartSwatch.maxScale * 12,
      );
    });
  });
}
