import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_bar_chart.dart';
import 'package:mm_ui/src/components/charts/mm_bar_layout.dart';

/// Text measured as [charWidth] per character and [lineHeight] per line.
MmTextMeasure _measure({double charWidth = 6, double lineHeight = 16}) =>
    (text, {maxWidth = double.infinity}) {
      final width = text.length * charWidth;
      final lines = width > maxWidth ? (width / maxWidth).ceil() : 1;
      return Size(math.min(width, maxWidth), lines * lineHeight);
    };

MmBarLayout _layout({
  double width = 300,
  List<List<double>> values = const [
    [100],
    [200],
    [300],
  ],
  int? seriesCount,
  List<String>? labels,
  double tickHeight = 16,
  double labelWidth = 6,
  TextDirection textDirection = TextDirection.ltr,
}) => MmBarLayout.compute(
  width: width,
  plotHeight: 100,
  seriesCount: seriesCount ?? values.first.length,
  values: values,
  groupLabels: labels ?? [for (var i = 0; i < values.length; i++) 'G$i'],
  tickLabel: (rupees) => '$rupees',
  measureTick: _measure(lineHeight: tickHeight),
  measureLabel: _measure(charWidth: labelWidth),
  textDirection: textDirection,
);

void main() {
  group('mmNiceTicks', () {
    test('steps by 1, 2, 2.5 or 5 times a power of ten from zero', () {
      expect(mmNiceTicks(0, 125000, 6), [
        0,
        25000,
        50000,
        75000,
        100000,
        125000,
      ]);
      expect(mmNiceTicks(0, 45000, 6), [0, 10000, 20000, 30000, 40000, 50000]);
      expect(mmNiceTicks(0, 7, 6), [0, 2, 4, 6, 8]);
      expect(mmNiceTicks(0, 0.5, 6), [0, 1]);
      expect(mmNiceTicks(0, 125000, 4), [0, 50000, 100000, 150000]);
      expect(mmNiceTicks(0, 125000, 2), [0, 200000]);
    });

    test('brackets values on both sides of zero', () {
      expect(mmNiceTicks(-30000, 105000, 6), [
        -50000,
        0,
        50000,
        100000,
        150000,
      ]);
      expect(mmNiceTicks(-30000, 105000, 2), [-200000, 0, 200000]);
      expect(mmNiceTicks(-30000, 0, 6), [-30000, -20000, -10000, 0]);
    });

    test('is just zero when there is nothing to show', () {
      expect(mmNiceTicks(0, 0, 6), [0]);
    });

    test('uses whole rupees for a step of 2.5', () {
      expect(mmNiceTicks(0, 12, 6), [0, 5, 10, 15]);
      expect(mmNiceTicks(0, 120, 6), [0, 25, 50, 75, 100, 125]);
    });
  });

  group('MmBarLayout', () {
    test('puts the ticks in a gutter at the start edge', () {
      final layout = _layout();
      // Ticks 0..300 by 100 (by 50 would take seven); the widest label,
      // "300", is 18 wide.
      expect([for (final tick in layout.ticks) tick.value], [0, 100, 200, 300]);
      expect(layout.plot.left, 18 + MmSpace.s2);
      expect(layout.plot.right, 300);
      expect(layout.plot.top, 8);
      expect(layout.plot.height, 100);
      for (final tick in layout.ticks) {
        expect(tick.rect.left, 0);
        expect(tick.rect.center.dy, closeTo(tick.y, 1e-9));
        expect(tick.label, '${tick.value}');
      }
      expect(layout.ticks.first.y, layout.plot.bottom);
      expect(layout.ticks.last.y, layout.plot.top);
    });

    test('puts the ticks at the right in right-to-left text', () {
      final layout = _layout(textDirection: TextDirection.rtl);
      expect(layout.plot.left, 0);
      expect(layout.plot.right, 300 - 18 - MmSpace.s2);
      for (final tick in layout.ticks) {
        expect(tick.rect.left, layout.plot.right + MmSpace.s2);
      }
    });

    test('takes fewer ticks when their labels are too tall for every one', () {
      // Steps of 100 / 3 are under the 30 + 4 a label needs, so the axis
      // takes the next nicer step.
      final layout = _layout(tickHeight: 30);
      expect([for (final tick in layout.ticks) tick.value], [0, 200, 400]);
      for (var i = 1; i < layout.ticks.length; i++) {
        expect(
          layout.ticks[i - 1].rect.top,
          greaterThanOrEqualTo(layout.ticks[i].rect.bottom),
        );
      }
    });

    test('keeps two ticks however tall their labels', () {
      final layout = _layout(tickHeight: 200);
      expect([for (final tick in layout.ticks) tick.value], [0, 500]);
    });

    test('runs the groups in equal bands from the start edge', () {
      final layout = _layout();
      final band = layout.plot.width / 3;
      for (final (index, rect) in layout.bands.indexed) {
        expect(rect.left, closeTo(layout.plot.left + index * band, 1e-9));
        expect(rect.width, closeTo(band, 1e-9));
        expect(rect.top, layout.plot.top);
        expect(rect.bottom, layout.plot.bottom);
      }
      final rtl = _layout(textDirection: TextDirection.rtl);
      expect(rtl.bands.first.right, closeTo(rtl.plot.right, 1e-9));
      expect(rtl.bands.last.left, closeTo(rtl.plot.left, 1e-9));
    });

    test('centres the bars in their band, at most 24 dp, 2 dp apart', () {
      final layout = _layout(
        values: const [
          [100, 200],
          [300, 250],
        ],
      );
      for (final (index, bars) in layout.bars.indexed) {
        final band = layout.bands[index];
        expect(bars[0].width, MmBarLayout.maxBarWidth);
        expect(bars[1].left - bars[0].right, closeTo(MmSpace.sHalf, 1e-9));
        expect(
          (bars[0].left + bars[1].right) / 2,
          closeTo(band.center.dx, 1e-9),
        );
      }
      // The first series is nearest the start edge: the right in Urdu.
      final rtl = _layout(
        textDirection: TextDirection.rtl,
        values: const [
          [100, 200],
        ],
      );
      expect(rtl.bars.single[0].left, greaterThan(rtl.bars.single[1].right));
    });

    test('narrows the bars to leave air between groups', () {
      final layout = _layout(
        width: 120,
        values: const [
          [1, 1],
          [1, 1],
          [1, 1],
          [1, 1],
        ],
      );
      final band = layout.bands.first.width;
      final bars = layout.bars.first;
      expect(
        bars[0].width * 2 + MmSpace.sHalf,
        closeTo(band * MmBarLayout.bandFill, 1e-9),
      );
    });

    test('draws bars from the zero line, negatives below it', () {
      final layout = _layout(
        values: const [
          [100],
          [-50],
          [0],
        ],
      );
      expect(layout.bars[0].single.bottom, closeTo(layout.baseline, 1e-9));
      expect(layout.bars[0].single.top, lessThan(layout.baseline));
      expect(layout.bars[1].single.top, closeTo(layout.baseline, 1e-9));
      expect(layout.bars[1].single.bottom, greaterThan(layout.baseline));
      expect(layout.bars[2].single.height, 0);
      final zero = layout.ticks.firstWhere((tick) => tick.value == 0);
      expect(zero.y, closeTo(layout.baseline, 1e-9));
      // The bar's height is its share of the axis.
      final top = layout.ticks.last;
      expect(
        layout.bars[0].single.height,
        closeTo((layout.baseline - top.y) * 100 / top.value, 1e-9),
      );
    });

    test('puts the zero line at the floor when there is nothing to show', () {
      final layout = _layout(
        values: const [
          [0],
          [0],
        ],
      );
      expect(layout.ticks.single.value, 0);
      expect(layout.baseline, layout.plot.bottom);
      expect(layout.ticks.single.y, layout.plot.bottom);
    });

    test('lays out no groups as an empty plot', () {
      final layout = MmBarLayout.compute(
        width: 300,
        plotHeight: 100,
        seriesCount: 1,
        values: const [],
        groupLabels: const [],
        tickLabel: (rupees) => '$rupees',
        measureTick: _measure(),
        measureLabel: _measure(),
        textDirection: TextDirection.ltr,
      );
      expect(layout.bands, isEmpty);
      expect(layout.bars, isEmpty);
      expect(layout.labels, isEmpty);
      expect(layout.size.height, layout.plot.bottom + 8);
    });

    test('labels every group under its band when the labels fit', () {
      final layout = _layout();
      expect([for (final label in layout.labels) label.index], [0, 1, 2]);
      for (final label in layout.labels) {
        expect(label.rect.top, layout.plot.bottom + MmSpace.s2);
        expect(
          label.rect.center.dx,
          closeTo(layout.bands[label.index].center.dx, 1e-9),
        );
        expect(label.text, 'G${label.index}');
      }
      expect(layout.size, Size(300, layout.plot.bottom + MmSpace.s2 + 16));
    });

    test('labels every second, third … group when they would touch', () {
      final layout = _layout(
        values: [
          for (var i = 0; i < 6; i++) [100.0],
        ],
        labels: [for (var i = 0; i < 6; i++) 'Month $i'],
      );
      final shown = [for (final label in layout.labels) label.index];
      expect(shown.first, 0);
      expect(shown.length, lessThan(6));
      final every = shown[1] - shown[0];
      expect(every, greaterThan(1));
      for (var i = 1; i < layout.labels.length; i++) {
        expect(shown[i] - shown[i - 1], every);
        expect(
          layout.labels[i].rect.left - layout.labels[i - 1].rect.right,
          greaterThanOrEqualTo(MmSpace.s2),
        );
      }
    });

    test('keeps a label as wide as the plot inside it', () {
      final layout = _layout(
        values: const [
          [100],
        ],
        labels: const ['A very long group label indeed'],
        labelWidth: 20,
      );
      final label = layout.labels.single;
      expect(label.rect.left, greaterThanOrEqualTo(layout.plot.left));
      expect(label.rect.right, lessThanOrEqualTo(layout.plot.right + 1e-9));
      expect(label.rect.height, greaterThan(16));
    });

    test('finds the group under a position', () {
      final layout = _layout();
      expect(layout.groupAt(layout.bands[1].center), 1);
      expect(layout.groupAt(Offset(layout.bands[2].right - 0.5, 0)), 2);
      expect(layout.groupAt(const Offset(1, 50)), isNull);
      expect(layout.groupAt(Offset(layout.bands[2].right, 50)), isNull);
    });
  });

  group('MmReadoutPlacement.place', () {
    const plot = Rect.fromLTWH(60, 8, 240, 176);
    const gap = MmReadoutPlacement.gap;

    MmReadoutSpot place(
      Rect band, {
      double natural = 120,
      double least = 80,
      TextDirection direction = TextDirection.ltr,
    }) => MmReadoutPlacement.place(
      band: band,
      plot: plot,
      chartWidth: 300,
      natural: natural,
      least: least,
      textDirection: direction,
    );

    test('goes after the band, at its natural width, when it fits', () {
      const band = Rect.fromLTWH(60, 8, 40, 176);
      expect(place(band), (left: 100 + gap, width: 120));
      // After is to the left in right-to-left text.
      expect(
        place(band.shift(const Offset(160, 0)), direction: TextDirection.rtl),
        (left: 220 - gap - 120, width: 120),
      );
    });

    test('goes before the band when it does not fit after', () {
      const band = Rect.fromLTWH(260, 8, 40, 176);
      expect(place(band), (left: 260 - gap - 120, width: 120));
      expect(
        place(
          const Rect.fromLTWH(60, 8, 40, 176),
          direction: TextDirection.rtl,
        ),
        (left: 100 + gap, width: 120),
      );
    });

    test('wraps over the plot before it covers the axis labels', () {
      // 92 after the band and 92 before it: too little for 120 either side
      // over the plot, so the names wrap (80), after the band.
      const band = Rect.fromLTWH(160, 8, 40, 176);
      expect(place(band), (left: 200 + gap, width: 80));
      expect(place(band, direction: TextDirection.rtl), (
        left: 160 - gap - 80,
        width: 80,
      ));
    });

    test('keeps its natural width before the band rather than wrap after', () {
      // In right-to-left text, after is the 32 on the left; before, on the
      // right, has 152.
      expect(
        place(
          const Rect.fromLTWH(100, 8, 40, 176),
          direction: TextDirection.rtl,
        ),
        (left: 140 + gap, width: 120),
      );
    });

    test('spreads over the axis labels rather than its own bars', () {
      // Neither side of the plot has room even wrapped; before the band
      // over the whole chart has 152.
      const band = Rect.fromLTWH(160, 8, 40, 176);
      expect(place(band, natural: 140, least: 100), (
        left: 160 - gap - 140,
        width: 140,
      ));
      expect(place(band, natural: 180, least: 150), (
        left: 160 - gap - 150,
        width: 150,
      ));
    });

    test('is centred over the band, inside the chart, when nothing fits', () {
      const band = Rect.fromLTWH(140, 8, 40, 176);
      expect(place(band, natural: 200, least: 180), (left: 60, width: 200));
      expect(
        place(const Rect.fromLTWH(60, 8, 40, 176), natural: 280, least: 250),
        (left: 0, width: 280),
      );
      expect(place(band, natural: 400, least: 350), (left: 0, width: 300));
    });
  });

  group('RenderMmReadoutPlacement', () {
    test('lays out again when the band, plot or direction change', () {
      final placement = RenderMmReadoutPlacement(
        band: Rect.zero,
        plot: Rect.zero,
        textDirection: TextDirection.ltr,
      );
      expect(placement.band, Rect.zero);
      expect(placement.plot, Rect.zero);
      expect(placement.textDirection, TextDirection.ltr);
      placement
        ..band = Rect.zero
        ..plot = Rect.zero
        ..textDirection = TextDirection.ltr;
      expect(placement.debugNeedsLayout, isTrue);
      placement
        ..band = const Rect.fromLTWH(1, 0, 1, 1)
        ..plot = const Rect.fromLTWH(0, 0, 10, 10)
        ..textDirection = TextDirection.rtl;
      expect(placement.band, const Rect.fromLTWH(1, 0, 1, 1));
      expect(placement.plot, const Rect.fromLTWH(0, 0, 10, 10));
      expect(placement.textDirection, TextDirection.rtl);
      expect(
        placement.computeDryLayout(BoxConstraints.tight(const Size(30, 20))),
        const Size(30, 20),
      );
    });
  });
}
