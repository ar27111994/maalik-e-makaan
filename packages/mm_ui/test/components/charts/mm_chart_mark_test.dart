import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';

import '../../support/testing.dart';

const _ink = Color(0xFF1D3F8F);
const _paper = Color(0xFFFFFFFF);
const _border = Color(0xFF79828D);

Widget _swatch(MmChartMark mark) => Center(child: MmChartSwatch(mark));

void main() {
  group('MmChartMark', () {
    test('compares by fill, stroke and hatch and describes itself', () {
      const hatched = MmChartMark(
        fill: _ink,
        hatch: MmHatch.rising,
        hatchColor: _paper,
      );
      expect(
        hatched,
        const MmChartMark(
          fill: _ink,
          hatch: MmHatch.rising,
          hatchColor: _paper,
        ),
      );
      expect(
        hatched.hashCode,
        const MmChartMark(
          fill: _ink,
          hatch: MmHatch.rising,
          hatchColor: _paper,
        ).hashCode,
      );
      expect(
        hatched,
        isNot(
          const MmChartMark(
            fill: _ink,
            hatch: MmHatch.falling,
            hatchColor: _paper,
          ),
        ),
      );
      expect(hatched, isNot(const MmChartMark(fill: _ink)));
      expect(
        const MmChartMark(fill: _ink),
        isNot(const MmChartMark(fill: _ink, stroke: _border)),
      );
      expect(
        hatched,
        isNot(
          const MmChartMark(
            fill: _ink,
            hatch: MmHatch.rising,
            hatchColor: _ink,
          ),
        ),
      );
      expect(hatched.toString(), contains('hatch: rising'));
      expect(const MmChartMark(fill: _ink).toString(), contains('hatch: null'));
    });

    test('needs both a hatch direction and its colour', () {
      expect(
        () => MmChartMark(fill: _ink, hatch: MmHatch.rising),
        throwsAssertionError,
      );
      expect(
        () => MmChartMark(fill: _ink, hatchColor: _paper),
        throwsAssertionError,
      );
    });

    testWidgets('paints a solid fill', (tester) async {
      await pumpThemed(tester, _swatch(const MmChartMark(fill: _ink)));
      expect(
        find.byType(MmChartSwatch),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 12, 12),
            const Radius.circular(MmChartSwatch.radius),
          ),
          color: _ink,
        ),
      );
    });

    testWidgets('paints an outline just inside the edge', (tester) async {
      await pumpThemed(
        tester,
        _swatch(const MmChartMark(fill: _paper, stroke: _border)),
      );
      final shape = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 12, 12),
        const Radius.circular(MmChartSwatch.radius),
      );
      expect(
        find.byType(MmChartSwatch),
        paints
          ..rrect(rrect: shape, color: _paper)
          ..rrect(
            rrect: shape.deflate(MmSize.stroke / 2),
            color: _border,
            style: PaintingStyle.stroke,
            strokeWidth: MmSize.stroke,
          ),
      );
    });

    testWidgets('paints crossed hatching both ways, clipped to the mark', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _swatch(
          const MmChartMark(
            fill: _ink,
            hatch: MmHatch.crossed,
            hatchColor: _paper,
          ),
        ),
      );
      expect(
        find.byType(MmChartSwatch),
        paints
          ..rrect(color: _ink)
          ..clipRRect()
          ..line(
            p1: const Offset(-12, 12),
            p2: Offset.zero,
            color: _paper,
            strokeWidth: MmChartMark.hatchWidth,
          )
          ..line(
            p1: const Offset(-12, 0),
            p2: const Offset(0, 12),
            color: _paper,
            strokeWidth: MmChartMark.hatchWidth,
          ),
      );
    });

    for (final hatch in [MmHatch.rising, MmHatch.falling]) {
      testWidgets('paints ${hatch.name} hatching clipped to the mark', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          _swatch(MmChartMark(fill: _ink, hatch: hatch, hatchColor: _paper)),
        );
        final rising = hatch == MmHatch.rising;
        expect(
          find.byType(MmChartSwatch),
          paints
            ..rrect(color: _ink)
            ..clipRRect()
            ..line(
              p1: Offset(-12, rising ? 12 : 0),
              p2: Offset(0, rising ? 0 : 12),
              color: _paper,
              strokeWidth: MmChartMark.hatchWidth,
            )
            ..line(
              p1: Offset(-12 + MmChartMark.hatchStep, rising ? 12 : 0),
              p2: Offset(MmChartMark.hatchStep, rising ? 0 : 12),
            ),
        );
      });
    }

    testWidgets('paints nothing in an empty shape', (tester) async {
      await pumpThemed(
        tester,
        const CustomPaint(
          size: Size(12, 0),
          painter: MmChartMarkPainter(MmChartMark(fill: _ink), radius: 2),
        ),
      );
      final mark = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is MmChartMarkPainter,
      );
      expect(mark, findsOneWidget);
      expect(mark, paintsNothing);
    });
  });

  group('MmChartMarkPainter', () {
    test('repaints when the mark or the radius changes', () {
      const painter = MmChartMarkPainter(MmChartMark(fill: _ink), radius: 2);
      expect(
        painter.shouldRepaint(
          const MmChartMarkPainter(MmChartMark(fill: _ink), radius: 2),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const MmChartMarkPainter(MmChartMark(fill: _paper), radius: 2),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const MmChartMarkPainter(MmChartMark(fill: _ink), radius: 4),
        ),
        isTrue,
      );
    });
  });

  group('MmChartSwatch', () {
    testWidgets('is a 12 dp square left out of semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, _swatch(const MmChartMark(fill: _ink)));
      expect(tester.getSize(find.byType(MmChartSwatch)), const Size(12, 12));
      expect(
        tester
            .widget<ExcludeSemantics>(
              find.descendant(
                of: find.byType(MmChartSwatch),
                matching: find.byType(ExcludeSemantics),
              ),
            )
            .excluding,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('grows with the text, up to one and a half times', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _swatch(const MmChartMark(fill: _ink)),
        variant: MmVariant.largeText,
      );
      expect(tester.getSize(find.byType(MmChartSwatch)), const Size(18, 18));
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.2)),
            child: _swatch(const MmChartMark(fill: _ink)),
          ),
        ),
      );
      final side = tester.getSize(find.byType(MmChartSwatch)).width;
      expect(side, closeTo(14.4, 1e-9));
    });
  });

  group('chart text helpers', () {
    test('ungroups the digits of figures for screen readers', () {
      expect(mmUngrouped('Rs 1,25,000'), 'Rs 125000');
      expect(mmUngrouped('1,250,000 روپے'), '1250000 روپے');
      expect(mmUngrouped('Ali, Raza'), 'Ali, Raza');
      expect(mmUngrouped('Rs 1,25,000, Rs 5,000'), 'Rs 125000, Rs 5000');
    });

    test('gives Urdu text its own direction and the rest left to right', () {
      expect(mmDirectionOf('فاطمہ نور'), TextDirection.rtl);
      expect(mmDirectionOf('فلیٹ 2B'), TextDirection.rtl);
      expect(mmDirectionOf('0300 1234567'), TextDirection.ltr);
      expect(mmDirectionOf('Shop 4'), TextDirection.ltr);
      expect(mmDirectionOf(''), TextDirection.ltr);
    });

    testWidgets('sets figures in the Latin face with tabular figures', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Text(
            '1,25,000 روپے',
            style: context.mm.figures(
              MmTypeScale.latinBodySmall,
              context.mm.colors.inkMuted,
            ),
          ),
        ),
        variant: MmVariant.urdu,
      );
      final style = styleOf(tester, '1,25,000');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFamilyFallback, isNotEmpty);
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(style.color, colorsOf(MmVariant.urdu).inkMuted);
    });
  });
}
