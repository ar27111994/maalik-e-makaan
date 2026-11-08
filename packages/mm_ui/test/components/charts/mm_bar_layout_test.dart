import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
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
  int? outer = 1,
  List<String>? labels,
  double tickHeight = 16,
  double labelWidth = 6,
  TextDirection textDirection = TextDirection.ltr,
  bool wrapLabels = false,
}) => MmBarLayout.compute(
  width: width,
  plotHeight: 100,
  seriesCount: seriesCount ?? values.first.length,
  outer: outer,
  values: values,
  groupLabels: labels ?? [for (var i = 0; i < values.length; i++) 'G$i'],
  tickLabel: (rupees) => '$rupees',
  measureTick: _measure(lineHeight: tickHeight),
  measureLabel: _measure(charWidth: labelWidth),
  wrapLabels: wrapLabels,
  measureWidestWord: (text) =>
      text.split(' ').map((word) => word.length * labelWidth).reduce(math.max),
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

    test('centres the bars in their band, at most 24 dp wide', () {
      final layout = _layout();
      for (final (index, bars) in layout.bars.indexed) {
        expect(bars.single.width, MmBarLayout.maxBarWidth);
        expect(
          bars.single.center.dx,
          closeTo(layout.bands[index].center.dx, 1e-9),
        );
      }
      expect(layout.outer, isNull);
    });

    test('stands the inner series inside the wide outer one', () {
      for (final direction in TextDirection.values) {
        final layout = _layout(
          textDirection: direction,
          values: const [
            [100, 200],
            [300, 250],
          ],
        );
        expect(layout.outer, 1);
        for (final (index, bars) in layout.bars.indexed) {
          final [inner, outer] = bars;
          expect(outer.width, MmBarLayout.maxBarWidth);
          expect(
            inner.width,
            MmBarLayout.maxBarWidth - 2 * MmBarLayout.innerInset,
          );
          final centre = layout.bands[index].center.dx;
          expect(inner.center.dx, closeTo(centre, 1e-9));
          expect(outer.center.dx, closeTo(centre, 1e-9));
          // Inside the outline and a gap of the pale fill on each side.
          expect(
            inner.left - outer.left,
            closeTo(MmSize.stroke + MmSpace.sHalf, 1e-9),
          );
        }
      }
      // Either series can be the outer one.
      final first = _layout(
        outer: 0,
        values: const [
          [100, 200],
        ],
      );
      expect(first.outer, 0);
      expect(
        first.bars.single[0].width,
        greaterThan(first.bars.single[1].width),
      );
    });

    test('narrows the bars to leave air between groups', () {
      final layout = _layout(
        width: 140,
        values: const [
          [1, 1],
          [1, 1],
          [1, 1],
          [1, 1],
        ],
      );
      final band = layout.bands.first.width;
      expect(
        layout.bars.first[1].width,
        closeTo(band * MmBarLayout.bandFill, 1e-9),
      );
    });

    test('keeps bars wide enough to tell the series apart in a year', () {
      // Twelve months in the plot of a 320 dp phone's card.
      final layout = _layout(
        width: 230,
        values: [
          for (var month = 0; month < 12; month++) [month * 10.0, 120],
        ],
      );
      final [inner, outer] = layout.bars.first;
      expect(outer.width, greaterThanOrEqualTo(MmBarLayout.minBarWidth));
      expect(inner.width, greaterThanOrEqualTo(4));
      expect(layout.bands.first.width - outer.width, greaterThan(2));
    });

    test('leaves a sliver of air when the band is narrower than a bar', () {
      final layout = _layout(
        width: 130,
        values: [
          for (var month = 0; month < 12; month++) [1, 1],
        ],
      );
      final band = layout.bands.first.width;
      expect(band, lessThan(MmBarLayout.minBarWidth + MmSpace.sHalf));
      expect(layout.bars.first[1].width, closeTo(band - MmSpace.sHalf, 1e-9));
      expect(layout.bars.first[0].width, 1);
    });

    test('needs the outer series of two', () {
      expect(
        () => _layout(
          outer: null,
          values: const [
            [1, 2],
          ],
        ),
        throwsAssertionError,
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

    test('says whether it labels every group', () {
      expect(_layout().labelsEveryGroup, isTrue);
      expect(
        _layout(
          values: [
            for (var i = 0; i < 6; i++) [100.0],
          ],
          labels: [for (var i = 0; i < 6; i++) 'Month $i'],
        ).labelsEveryGroup,
        isFalse,
      );
    });

    test('labels every named group, wrapping each within its band', () {
      // Six names that would be thinned out as periods: wrapped between
      // their words, each fits its own band.
      final names = [for (var i = 1; i <= 6; i++) 'Flat ${i}B'];
      final layout = _layout(
        values: [
          for (var i = 0; i < 6; i++) [100.0],
        ],
        labels: names,
        wrapLabels: true,
      );
      expect(
        [for (final label in layout.labels) label.index],
        [for (var i = 0; i < 6; i++) i],
      );
      expect(layout.labelsEveryGroup, isTrue);
      for (final label in layout.labels) {
        final band = layout.bands[label.index];
        expect(label.rect.width, lessThanOrEqualTo(band.width - MmSpace.s2));
        expect(label.rect.center.dx, closeTo(band.center.dx, 1e-9));
        // "Flat" and "1B" on two lines.
        expect(label.rect.height, 32);
      }
      for (var i = 1; i < layout.labels.length; i++) {
        expect(
          layout.labels[i].rect.left - layout.labels[i - 1].rect.right,
          greaterThanOrEqualTo(MmSpace.s2 - 1e-9),
        );
      }
      expect(layout.size.height, layout.plot.bottom + MmSpace.s2 + 32);
    });

    test('says when a named group has a word too wide for its band', () {
      final layout = _layout(
        values: [
          for (var i = 0; i < 6; i++) [100.0],
        ],
        labels: [for (var i = 0; i < 6; i++) 'Apartment $i'],
        wrapLabels: true,
      );
      expect(layout.labels, hasLength(6));
      expect(layout.labelsEveryGroup, isFalse);
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
}
