import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_sparkline.dart';

import '../../support/testing.dart';

Finder get _line => find.descendant(
  of: find.byType(MmSparkline),
  matching: find.byType(CustomPaint),
);

MmSparklinePainter _painter(WidgetTester tester) =>
    painterIn<MmSparklinePainter>(tester, find.byType(MmSparkline));

const double _inset = MmSparkline.dotRadius + MmSparkline.ringWidth;

void main() {
  group('MmSparkline', () {
    testEveryVariant('draws a 2 dp line and a ringed dot in cobalt', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmSparkline(values: [110, 125, 95, 145]),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final painter = _painter(tester);
      expect(painter.color, colors.primary);
      expect(painter.ringColor, colors.surface);
      final points = painter.pointsIn(const Size(64, 24));
      expect(
        _line,
        paints
          ..path(
            color: colors.primary,
            style: PaintingStyle.stroke,
            strokeWidth: MmSize.stroke,
          )
          ..circle(
            x: points.last.dx,
            y: points.last.dy,
            radius: MmSparkline.dotRadius + MmSparkline.ringWidth,
            color: colors.surface,
          )
          ..circle(
            x: points.last.dx,
            y: points.last.dy,
            radius: MmSparkline.dotRadius,
            color: colors.primary,
          ),
      );
      // An 8 dp dot with a 2 dp ring, as the chart marks specify.
      expect(MmSparkline.dotRadius * 2, 8);
      expect(MmSparkline.ringWidth, MmSpace.sHalf);
    });

    testWidgets('is 64 by 24 dp unless told otherwise', (tester) async {
      await pumpThemed(tester, const MmSparkline(values: [1, 2]));
      expect(tester.getSize(_line), const Size(64, 24));
      await pumpThemed(
        tester,
        const MmSparkline(values: [1, 2], width: 120, height: 40),
      );
      expect(tester.getSize(_line), const Size(120, 40));
    });

    testWidgets('runs from the start edge, highest value at the top', (
      tester,
    ) async {
      await pumpThemed(tester, const MmSparkline(values: [10, 30, 20]));
      final points = _painter(tester).pointsIn(const Size(64, 24));
      expect(points, [
        const Offset(_inset, 24 - _inset),
        const Offset(32, _inset),
        const Offset(64 - _inset, 12),
      ]);
    });

    testWidgets('runs from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        const MmSparkline(values: [10, 30, 20]),
        variant: MmVariant.urdu,
      );
      final points = _painter(tester).pointsIn(const Size(64, 24));
      expect(points.first.dx, 64 - _inset);
      expect(points.last.dx, _inset);
    });

    testWidgets('draws a level line through the middle for a flat series', (
      tester,
    ) async {
      await pumpThemed(tester, const MmSparkline(values: [8, 8, 8]));
      final points = _painter(tester).pointsIn(const Size(64, 24));
      expect(points.map((point) => point.dy), everyElement(12));
      expect(
        _line,
        paints
          ..path()
          ..circle()
          ..circle(),
      );
    });

    testWidgets('draws only the dot, at the end edge, for one value', (
      tester,
    ) async {
      await pumpThemed(tester, const MmSparkline(values: [45]));
      final points = _painter(tester).pointsIn(const Size(64, 24));
      expect(points, [const Offset(64 - _inset, 12)]);
      expect(_line, isNot(paints..path()));
      expect(
        _line,
        paints
          ..circle()
          ..circle(),
      );
    });

    testWidgets('draws nothing for no values', (tester) async {
      await pumpThemed(tester, const MmSparkline(values: []));
      expect(_painter(tester).pointsIn(const Size(64, 24)), isEmpty);
      expect(_line, paintsNothing);
      expect(tester.getSize(_line), const Size(64, 24));
    });

    testWidgets('leaves out values that are not finite numbers', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmSparkline(
          values: [1, double.nan, 3, double.infinity, double.negativeInfinity],
        ),
      );
      expect(_painter(tester).values, [1, 3]);
    });

    testWidgets('draws figures computed at run time, such as rupees', (
      tester,
    ) async {
      final paisa = [4500000, 4000000, 1500000];
      await pumpThemed(
        tester,
        MmSparkline(values: [for (final amount in paisa) amount / 100]),
      );
      expect(_painter(tester).values, [45000, 40000, 15000]);
    });

    testWidgets('keeps the dot inside a canvas smaller than it', (
      tester,
    ) async {
      const painter = MmSparklinePainter(
        values: [1, 2],
        color: Color(0xFF000000),
        ringColor: Color(0xFFFFFFFF),
        textDirection: TextDirection.ltr,
      );
      final points = painter.pointsIn(const Size(4, 4));
      expect(points, everyElement(const Offset(_inset, _inset)));
    });

    testWidgets('is left out of semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const MmSparkline(values: [110, 125, 145]));
      final exclusion = tester.widget<ExcludeSemantics>(
        find.descendant(
          of: find.byType(MmSparkline),
          matching: find.byType(ExcludeSemantics),
        ),
      );
      expect(exclusion.excluding, isTrue);
      final node = tester.getSemantics(_line);
      expect(node.label, isEmpty);
      expect(node.hasChildren, isFalse);
      handle.dispose();
    });

    test('repaints only when what it draws changes', () {
      const painter = MmSparklinePainter(
        values: [1, 2],
        color: Color(0xFF000001),
        ringColor: Color(0xFFFFFFFF),
        textDirection: TextDirection.ltr,
      );
      expect(
        painter.shouldRepaint(
          const MmSparklinePainter(
            values: [1, 2],
            color: Color(0xFF000001),
            ringColor: Color(0xFFFFFFFF),
            textDirection: TextDirection.ltr,
          ),
        ),
        isFalse,
      );
      for (final other in const [
        MmSparklinePainter(
          values: [1, 3],
          color: Color(0xFF000001),
          ringColor: Color(0xFFFFFFFF),
          textDirection: TextDirection.ltr,
        ),
        MmSparklinePainter(
          values: [1, 2],
          color: Color(0xFF000002),
          ringColor: Color(0xFFFFFFFF),
          textDirection: TextDirection.ltr,
        ),
        MmSparklinePainter(
          values: [1, 2],
          color: Color(0xFF000001),
          ringColor: Color(0xFFFFFFFE),
          textDirection: TextDirection.ltr,
        ),
        MmSparklinePainter(
          values: [1, 2],
          color: Color(0xFF000001),
          ringColor: Color(0xFFFFFFFF),
          textDirection: TextDirection.rtl,
        ),
      ]) {
        expect(painter.shouldRepaint(other), isTrue);
      }
    });

    testWidgets('at 200% on a 320 dp phone, keeps its size', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const Row(
          children: [
            Expanded(child: Text('Collected: up 14% since June')),
            MmSparkline(values: [110, 125, 125, 95, 125, 145]),
          ],
        ),
      );
      expect(tester.getSize(_line), const Size(64, 24));
    });
  });
}
