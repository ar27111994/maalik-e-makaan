import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

const _rounded = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(MmRadius.sm)),
);
const _cobalt = Color(0xFF1D3F8F);
const _rect = Rect.fromLTWH(10, 20, 120, 48);

/// The `drawPath` calls [border] makes painting [rect].
List<(Path, Paint)> _paths(ShapeBorder border, Rect rect) {
  final canvas = TestRecordingCanvas();
  border.paint(canvas, rect, textDirection: TextDirection.ltr);
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawPath)
        (
          call.invocation.positionalArguments[0] as Path,
          call.invocation.positionalArguments[1] as Paint,
        ),
  ];
}

/// Whether [a] and [b] agree to a hundredth of a pixel.
bool _near(Rect a, Rect b) =>
    (a.left - b.left).abs() < 0.01 &&
    (a.top - b.top).abs() < 0.01 &&
    (a.right - b.right).abs() < 0.01 &&
    (a.bottom - b.bottom).abs() < 0.01;

double _length(Path path) =>
    path.computeMetrics().fold(0, (sum, metric) => sum + metric.length);

/// The length of a rounded rectangle's outline with circular corners.
double _perimeter(Rect rect, double radius) => _length(
  Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
);

/// A shape whose scaled form is no longer an outlined border.
final class _Unscalable extends RoundedRectangleBorder {
  const new();

  @override
  ShapeBorder scale(double t) => const Border();
}

Material _materialOf(WidgetTester tester, Finder button) => tester.widget(
  find.descendant(of: button, matching: find.byType(Material)).first,
);

void main() {
  group('MmFocusRingBorder', () {
    const ring = MmFocusRingBorder(_rounded, color: _cobalt);

    test('keeps the shape of the control and draws outside it', () {
      final edged = ring.copyWith(side: const BorderSide(color: _cobalt));
      expect(edged, isA<MmFocusRingBorder>());
      expect(edged.side, const BorderSide(color: _cobalt));
      expect(ring.side, BorderSide.none);
      expect(ring.copyWith(), ring);
      expect(ring.dimensions, _rounded.dimensions);
      expect(
        ring.getOuterPath(_rect).getBounds(),
        _rounded.getOuterPath(_rect).getBounds(),
      );
      expect(
        ring.getInnerPath(_rect).getBounds(),
        _rounded.getInnerPath(_rect).getBounds(),
      );
      expect(ring.preferPaintInterior, _rounded.preferPaintInterior);
      final canvas = TestRecordingCanvas();
      ring.paintInterior(canvas, _rect, Paint());
      expect(canvas.invocations, isNotEmpty);
    });

    test('paints a concentric ring past the gap', () {
      final paths = _paths(ring, _rect);
      expect(paths, hasLength(1));
      final (path, paint) = paths.single;
      // The centre line lies the gap and half the ring outside the edge.
      const offset = MmSize.focusGap + MmSize.focusRing / 2;
      expect(path.getBounds(), _rect.inflate(offset));
      expect(
        _length(path),
        closeTo(_perimeter(_rect.inflate(offset), MmRadius.sm + offset), 0.01),
      );
      expect(paint.style, PaintingStyle.stroke);
      expect(paint.strokeWidth, MmSize.focusRing);
      // Paint keeps colours as 32-bit values.
      expect(paint.color.toARGB32(), _cobalt.toARGB32());
    });

    test('follows stadiums and paints the control border too', () {
      const stadium = MmFocusRingBorder(
        StadiumBorder(side: BorderSide(color: _cobalt)),
        color: _cobalt,
      );
      final canvas = TestRecordingCanvas();
      stadium.paint(canvas, _rect);
      // The stadium's own border, then the ring.
      expect(canvas.invocations, hasLength(2));
      final (path, _) = _paths(stadium, _rect).single;
      expect(path.getBounds(), _rect.inflate(3));
    });

    test('scales with its shape', () {
      final half = ring.scale(0.5) as MmFocusRingBorder;
      expect(half.width, MmSize.focusRing / 2);
      expect(half.gap, MmSize.focusGap / 2);
      expect(half.shape, _rounded.scale(0.5));
      const odd = MmFocusRingBorder(_Unscalable(), color: _cobalt);
      expect(odd.scale(0.5), const Border());
    });

    test('fades in as focus arrives and out as it leaves', () {
      final arriving = ShapeBorder.lerp(_rounded, ring, 0.25)!;
      arriving as MmFocusRingBorder;
      expect(arriving.color.a, closeTo(0.25, 0.001));
      expect(arriving.shape, _rounded);
      final leaving = ShapeBorder.lerp(ring, _rounded, 0.25)!;
      leaving as MmFocusRingBorder;
      expect(leaving.color.a, closeTo(0.75, 0.001));
      expect(ShapeBorder.lerp(_rounded, ring, 1), ring);

      const wide = MmFocusRingBorder(
        _rounded,
        color: Color(0xFFFFFFFF),
        width: 4,
        gap: 4,
      );
      final between = ShapeBorder.lerp(ring, wide, 0.5)! as MmFocusRingBorder;
      expect(between.width, 3);
      expect(between.gap, 3);
      expect(ring.lerpTo(wide, 0.5), between);
    });

    test('leaves other borders to the default interpolation', () {
      expect(ring.lerpFrom(const Border(), 0.5), isNull);
      expect(ring.lerpTo(const Border(), 0.5), isNull);
      expect(ring.lerpFrom(null, 0.5), ring.scale(0.5));
      expect(ring.lerpTo(null, 0.5), ring.scale(0.5));
    });

    test('has value equality and describes itself', () {
      expect(ring, const MmFocusRingBorder(_rounded, color: _cobalt));
      expect(
        ring.hashCode,
        const MmFocusRingBorder(_rounded, color: _cobalt).hashCode,
      );
      expect(
        ring,
        isNot(const MmFocusRingBorder(_rounded, color: _cobalt, gap: 3)),
      );
      expect(ring.toString(), startsWith('MmFocusRingBorder('));
      expect(ring.toString(), contains('gap: 2.0'));
    });

    test('whenFocused rings the shape only while focused', () {
      final shape = MmFocusRingBorder.whenFocused(_rounded, color: _cobalt);
      expect(shape.resolve({}), _rounded);
      expect(shape.resolve({WidgetState.hovered}), _rounded);
      expect(shape.resolve({WidgetState.focused}), ring);
    });
  });

  group('filled controls in the theme', () {
    Future<void> focusFirst(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    testEveryVariant('a focused filled button is ringed outside its fill', (
      tester,
      variant,
    ) async {
      final colors = variant.theme.extension<MmSemantics>()!.colors;
      await pumpThemed(
        tester,
        FilledButton(onPressed: () {}, child: const Text('Record payment')),
        variant: variant,
      );
      final button = find.byType(FilledButton);
      expect(
        _materialOf(tester, button).shape,
        isNot(isA<MmFocusRingBorder>()),
      );
      await focusFirst(tester);
      final shape = _materialOf(tester, button).shape!;
      expect(shape, isA<MmFocusRingBorder>());
      shape as MmFocusRingBorder;
      expect(shape.color, colors.focus);
      expect(shape.side, BorderSide.none);
      // The fill stays the control's own colour, edge to edge.
      expect(_materialOf(tester, button).color, colors.primary);
      // The ring is painted around the button, outside its bounds.
      final border = find
          .descendant(of: button, matching: find.byType(CustomPaint))
          .first;
      final ringBounds = (Offset.zero & tester.getSize(border)).inflate(
        MmSize.focusGap + MmSize.focusRing / 2,
      );
      expect(
        tester.renderObject(border),
        paints..something((method, arguments) {
          if (method != #drawPath) return false;
          final paint = arguments[1] as Paint;
          return paint.style == PaintingStyle.stroke &&
              paint.strokeWidth == MmSize.focusRing &&
              paint.color.toARGB32() == colors.focus.toARGB32() &&
              _near((arguments[0] as Path).getBounds(), ringBounds);
        }),
      );
    });

    testWidgets('a disabled filled button sits on sunken paper', (
      tester,
    ) async {
      const colors = MmColorModes.light;
      await pumpThemed(
        tester,
        const FilledButton(onPressed: null, child: Text('Record payment')),
      );
      final material = _materialOf(tester, find.byType(FilledButton));
      expect(material.color, colors.surfaceSunken);
      expect(material.textStyle!.color, colors.inkMuted);
      expect((material.shape! as OutlinedBorder).side.color, colors.rule);
    });

    testEveryVariant(
      'icon buttons ring focus; outlined ones keep the outline',
      (tester, variant) async {
        final colors = variant.theme.extension<MmSemantics>()!.colors;
        for (final (outlined, button) in [
          (
            false,
            IconButton.filled(
              onPressed: () {},
              tooltip: 'Edit',
              icon: const Icon(MmIcons.edit),
            ),
          ),
          (
            true,
            IconButton.outlined(
              onPressed: () {},
              tooltip: 'Edit',
              icon: const Icon(MmIcons.edit),
            ),
          ),
          (
            false,
            IconButton(
              onPressed: () {},
              tooltip: 'Edit',
              icon: const Icon(MmIcons.edit),
            ),
          ),
        ]) {
          await pumpThemed(
            tester,
            KeyedSubtree(key: UniqueKey(), child: button),
            variant: variant,
          );
          final found = find.byType(IconButton);
          final resting = _materialOf(tester, found).shape! as OutlinedBorder;
          await focusFirst(tester);
          final focused = _materialOf(tester, found).shape!;
          expect(focused, isA<MmFocusRingBorder>());
          focused as MmFocusRingBorder;
          expect(focused.color, colors.focus);
          expect(focused.side, resting.side);
          expect(
            resting.side.style,
            outlined ? BorderStyle.solid : BorderStyle.none,
          );
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
    );

    testWidgets('an outlined icon button has its outline in the theme', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        IconButton.outlined(
          onPressed: () {},
          tooltip: 'Edit',
          icon: const Icon(MmIcons.edit),
        ),
      );
      final shape =
          _materialOf(tester, find.byType(IconButton)).shape! as OutlinedBorder;
      expect(shape.side.color, MmColorModes.light.outline);
      expect(shape.side.style, BorderStyle.solid);
    });

    testEveryVariant('a focused floating action button is ringed', (
      tester,
      variant,
    ) async {
      final colors = variant.theme.extension<MmSemantics>()!.colors;
      await pumpThemed(
        tester,
        FloatingActionButton(
          onPressed: () {},
          tooltip: 'Add tenant',
          child: const Icon(MmIcons.add),
        ),
        variant: variant,
      );
      final fab = find.byType(FloatingActionButton);
      expect(_materialOf(tester, fab).shape, isNot(isA<MmFocusRingBorder>()));
      await focusFirst(tester);
      final shape = _materialOf(tester, fab).shape!;
      expect(shape, isA<MmFocusRingBorder>());
      expect((shape as MmFocusRingBorder).color, colors.focus);
      expect(shape.side.color, colors.primary);
    });
  });
}
