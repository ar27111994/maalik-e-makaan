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
    testEveryVariant('draws the tones of each bar the app draws apart', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      final hatch = colors.surface;
      Future<List<MmChartMark>> marksOf(List<MmSegmentTone> tones) async {
        await pumpThemed(
          tester,
          _bar(
            segments: [
              for (final tone in tones)
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
        expect(tester.takeException(), isNull);
        final marks = [for (final part in _painter(tester).parts) part.mark];
        // Every legend key is drawn with the mark of its part.
        expect(_swatches(tester), marks);
        return marks;
      }

      // Rent by status.
      expect(
        await marksOf(const [
          MmSegmentTone.paid,
          MmSegmentTone.dueSoon,
          MmSegmentTone.overdue,
          MmSegmentTone.neutral,
        ]),
        [
          MmChartMark(fill: colors.paid),
          MmChartMark(
            fill: colors.dueSoon,
            hatch: MmHatch.falling,
            hatchColor: hatch,
          ),
          MmChartMark(
            fill: colors.overdue,
            hatch: MmHatch.rising,
            hatchColor: hatch,
          ),
          MmChartMark(fill: colors.surface, stroke: colors.outline),
        ],
      );
      // Overdue rent by age: the oldest is solid red, in every mode.
      expect(
        await marksOf(const [
          MmSegmentTone.dueSoon,
          MmSegmentTone.overdue,
          MmSegmentTone.overdueSevere,
        ]),
        [
          MmChartMark(
            fill: colors.dueSoon,
            hatch: MmHatch.falling,
            hatchColor: hatch,
          ),
          MmChartMark(
            fill: colors.overdue,
            hatch: MmHatch.rising,
            hatchColor: hatch,
          ),
          MmChartMark(fill: colors.overdue),
        ],
      );
      // Overdue rent by age in four buckets: rising lines, then crossed
      // lines, then solid red, ever heavier.
      expect(
        await marksOf(const [
          MmSegmentTone.neutral,
          MmSegmentTone.dueSoon,
          MmSegmentTone.overdue,
          MmSegmentTone.overdueOlder,
          MmSegmentTone.overdueSevere,
        ]),
        [
          MmChartMark(fill: colors.surface, stroke: colors.outline),
          MmChartMark(
            fill: colors.dueSoon,
            hatch: MmHatch.falling,
            hatchColor: hatch,
          ),
          MmChartMark(
            fill: colors.overdue,
            hatch: MmHatch.rising,
            hatchColor: hatch,
          ),
          MmChartMark(
            fill: colors.overdue,
            hatch: MmHatch.crossed,
            hatchColor: hatch,
          ),
          MmChartMark(fill: colors.overdue),
        ],
      );
      // Money held for tenants.
      expect(
        await marksOf(const [MmSegmentTone.primary, MmSegmentTone.credit]),
        [
          MmChartMark(fill: colors.primary),
          MmChartMark(
            fill: colors.credit,
            hatch: MmHatch.falling,
            hatchColor: hatch,
          ),
        ],
      );
      // Every tone's colour stands out from the surface (3:1), as does the
      // neutral outline.
      for (final color in [
        colors.paid,
        colors.dueSoon,
        colors.overdue,
        colors.credit,
        colors.primary,
        colors.outline,
      ]) {
        expect(
          mmContrastRatio(color, colors.surface),
          greaterThanOrEqualTo(3),
          reason: '$color',
        );
      }
    });

    for (final (first, second) in const [
      (MmSegmentTone.paid, MmSegmentTone.primary),
      (MmSegmentTone.paid, MmSegmentTone.overdueSevere),
      (MmSegmentTone.dueSoon, MmSegmentTone.credit),
    ]) {
      testWidgets(
        'refuses ${first.name} beside ${second.name}, apart by colour alone',
        (tester) async {
          await pumpThemed(
            tester,
            _bar(
              segments: [
                MmProportionSegment(
                  label: 'A',
                  value: const Money.fromRupees(1),
                  tone: first,
                ),
                MmProportionSegment(
                  label: 'B',
                  value: const Money.fromRupees(1),
                  tone: second,
                ),
              ],
            ),
          );
          expect(
            tester.takeException(),
            isA<FlutterError>().having(
              (error) => error.message,
              'message',
              contains('differ by colour alone'),
            ),
          );
        },
      );
    }

    testWidgets('takes a tone twice', (tester) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            _paid,
            MmProportionSegment(
              label: 'Paid late',
              value: Money.fromRupees(5000),
              tone: MmSegmentTone.paid,
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('refuses a negative part', (tester) async {
      await pumpThemed(
        tester,
        _bar(
          segments: const [
            _paid,
            MmProportionSegment(
              label: 'Written off',
              value: Money.fromRupees(-500),
              tone: MmSegmentTone.neutral,
            ),
          ],
        ),
      );
      expect(
        tester.takeException(),
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('never negative'),
        ),
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
              value: Money.zero,
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

    for (final variant in const [
      MmVariant.light,
      MmVariant.urdu,
      MmVariant.largeText,
    ]) {
      testWidgets('lines the figures of every row up on their last digit '
          '(${variant.name})', (tester) async {
        // At 200% text some amounts fit beside their labels and some move
        // under them; the figures still line up.
        final large = variant == MmVariant.largeText;
        await pumpThemed(
          tester,
          lakhGrouping(
            _bar(
              segments: const [
                MmProportionSegment(
                  label: 'Security deposits held',
                  value: Money.fromRupees(150000),
                  tone: MmSegmentTone.primary,
                ),
                MmProportionSegment(
                  label: 'Advance',
                  value: Money.fromRupees(30000),
                  tone: MmSegmentTone.credit,
                ),
                MmProportionSegment(
                  label: 'Fee',
                  value: Money.fromRupees(500),
                  tone: MmSegmentTone.neutral,
                ),
              ],
            ),
          ),
          variant: variant,
        );

        /// The right edge of the last character of [text] matching [last].
        double rightOf(String text, Pattern last) {
          final paragraph = paragraphOf(tester, text);
          final end = text.lastIndexOf(last) + 1;
          final box = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: end - 1, extentOffset: end),
              )
              .single;
          return paragraph.localToGlobal(Offset(box.right, 0)).dx;
        }

        final urdu = variant == MmVariant.urdu;
        final amounts = urdu
            ? ['1,50,000\u00A0روپے', '30,000\u00A0روپے', '500\u00A0روپے']
            : ['Rs\u00A01,50,000', 'Rs\u00A030,000', 'Rs\u00A0500'];
        final digits = [for (final text in amounts) rightOf(text, '0')];
        expect(digits[1], closeTo(digits[0], 0.5));
        expect(digits[2], closeTo(digits[0], 0.5));
        // The shares ("83%", "17%", "<1%") end on one line too.
        final shares = [
          for (final text in ['83%', '17%', '<1%']) rightOf(text, '%'),
        ];
        expect(shares[1], closeTo(shares[0], 0.5));
        expect(shares[2], closeTo(shares[0], 0.5));
        if (large) {
          final moved = [
            for (final (label, amount) in [
              ('Security deposits held', amounts[0]),
              ('Fee', amounts[2]),
            ])
              tester.getRect(find.textContaining(amount)).top >=
                  tester.getRect(find.text(label)).bottom,
          ];
          expect(moved, [true, false]);
        }
      });
    }

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
      expect(find.text('Rs\u00A01,50,000'), findsOneWidget);
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
      // The track's edge stands out from the surface (3:1).
      expect(decoration.border, Border.all(color: colors.outline));
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
      expect(find.text('Rs\u00A00'), findsNWidgets(2));
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
      final amount = tester.getRect(find.text('Rs\u00A0150,000'));
      final share = tester.getRect(find.text('100%'));
      expect(amount.top, greaterThanOrEqualTo(label.bottom));
      // The amount and its share keep to the end edge, on one line.
      expect(share.right, tester.getRect(find.byType(MmProportionBar)).right);
      expect(share.top, closeTo(amount.top, 4));
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
      expect(find.text('75,000\u00A0روپے'), findsOneWidget);
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

    group(
      'fits its legend in every width, text scale, script and grouping',
      () {
        /// Pumps the deposits bar the gallery shows, [barWidth] wide, at
        /// [scale] text in [locale], grouped by [grouping], and fails on any
        /// overflow.
        Future<void> pumpDeposits(
          WidgetTester tester, {
          required double barWidth,
          required double scale,
          required Locale locale,
          required DigitGrouping grouping,
        }) async {
          tester.view
            ..physicalSize = Size(barWidth + 2 * MmSpace.s4, 800)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final urdu = locale.languageCode == 'ur';
          await tester.pumpWidget(
            themedApp(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: MmFormats(
                    money: MmFormats.defaultFor(locale)
                        .copyWith(grouping: grouping),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(MmSpace.s4),
                        child: MmProportionBar(
                          semanticSummary: _summary,
                          segments: [
                            MmProportionSegment(
                              label: urdu
                                  ? 'سیکیورٹی ڈپازٹ'
                                  : 'Security deposit',
                              value: const Money.fromRupees(125000),
                              tone: MmSegmentTone.primary,
                            ),
                            MmProportionSegment(
                              label: urdu ? 'ایڈوانس کرایہ' : 'Advance rent',
                              value: const Money.fromRupees(15000),
                              tone: MmSegmentTone.credit,
                            ),
                            MmProportionSegment(
                              label: urdu
                                  ? 'ابھی تاریخ نہیں آئی'
                                  : 'Not yet due',
                              value: const Money.fromRupees(38000),
                              tone: MmSegmentTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pump();
        }

        testWidgets('in Urdu with lakh grouping at 200% on a 320 dp window', (
          tester,
        ) async {
          await pumpDeposits(
            tester,
            barWidth: 288,
            scale: 2,
            locale: const Locale('ur'),
            grouping: DigitGrouping.southAsian,
          );
          expect(tester.takeException(), isNull);
          // Every figure is whole on the screen: nothing is clipped or
          // pushed past the bar's edges.
          final bar = tester.getRect(find.byType(MmProportionBar));
          for (final amount in ['1,25,000', '15,000', '38,000', '70%']) {
            final rect = tester.getRect(find.textContaining(amount).first);
            expect(rect.left, greaterThanOrEqualTo(bar.left), reason: amount);
            expect(rect.right, lessThanOrEqualTo(bar.right), reason: amount);
          }
          // Too narrow for both side by side, each share moves under its
          // amount, ending on the same right edge, where figures end.
          for (final (amount, share) in const [
            ('1,25,000', '70%'),
            ('15,000', '9%'),
            ('38,000', '21%'),
          ]) {
            final figures = tester.getRect(find.textContaining(amount));
            final percent = tester.getRect(find.text(share));
            expect(percent.top, greaterThanOrEqualTo(figures.bottom));
            expect(percent.right, closeTo(figures.right, 0.5), reason: share);
          }
        });

        testWidgets('shows a crore at 200% on the narrowest phone smaller, '
            'never cut off or broken', (tester) async {
          for (final locale in const [Locale('en'), Locale('ur')]) {
            tester.view
              ..physicalSize = const Size(240, 600)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              themedApp(
                lakhGrouping(
                  const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(MmSpace.s4),
                      child: MmProportionBar(
                        semanticSummary: _summary,
                        segments: [
                          MmProportionSegment(
                            label: 'Rent roll',
                            value: Money.fromRupees(125000000),
                            tone: MmSegmentTone.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                variant: MmVariant.largeText,
                locale: locale,
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(find.byType(MmProportionBar));
            final amount = find.textContaining('12,50,00,000');
            final rect = tester.getRect(amount);
            expect(rect.left, greaterThanOrEqualTo(bar.left));
            expect(rect.right, lessThanOrEqualTo(bar.right));
            // Shown whole on one line (it never wraps), at the size the room
            // allows.
            expect(rect.width, lessThan(tester.getSize(amount).width));
            expect(brokenWords(tester), isEmpty);
          }
        });

        testWidgets('across 208 to 400 dp, 100% to 200% text, both scripts '
            'and both groupings', (tester) async {
          final failures = <String>[];
          for (var barWidth = 208.0; barWidth <= 400; barWidth += 4) {
            for (final scale in const [1.0, 1.25, 1.5, 1.75, 2.0]) {
              for (final locale in const [Locale('en'), Locale('ur')]) {
                for (final grouping in DigitGrouping.values) {
                  await pumpDeposits(
                    tester,
                    barWidth: barWidth,
                    scale: scale,
                    locale: locale,
                    grouping: grouping,
                  );
                  final error = tester.takeException();
                  final bar = tester.getRect(find.byType(MmProportionBar));
                  final outside = [
                    for (final element
                        in find
                            .descendant(
                              of: find.byType(MmProportionBar),
                              matching: find.byType(RichText),
                            )
                            .evaluate())
                      if (!_within(
                        tester.getRect(find.byWidget(element.widget)),
                        bar,
                      ))
                        (element.widget as RichText).text.toPlainText(),
                  ];
                  if (error != null || outside.isNotEmpty) {
                    failures.add(
                      '${barWidth.toStringAsFixed(0)} dp, ${scale}x, '
                      '${locale.languageCode}, ${grouping.name}: '
                      '${error ?? 'outside the bar: $outside'}',
                    );
                  }
                }
              }
            }
          }
          expect(failures, isEmpty);
        });
      },
    );
  });
}

/// Whether [rect] lies within [bounds], to a hundredth of a pixel.
bool _within(Rect rect, Rect bounds) =>
    rect.left >= bounds.left - 0.01 &&
    rect.right <= bounds.right + 0.01 &&
    rect.top >= bounds.top - 0.01;
