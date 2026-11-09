import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/layout/mm_focus_ring.dart';

void main() {
  group('MmFocusRingPainter', () {
    const ring = MmFocusRingPainter(
      color: Color(0xFF1D3F8F),
      radius: MmRadius.sm,
      height: 40,
      widthOutset: MmSpace.s3,
    );

    test('rings a box of a fixed size, or one grown from the widget', () {
      const fixed = MmFocusRingPainter(
        color: Color(0xFF1D3F8F),
        radius: 16,
        size: Size(64, 32),
      );
      expect(
        fixed.outerEdge(const Size(24, 24)),
        Rect.fromCenter(center: const Offset(12, 12), width: 64, height: 32),
      );
      expect(
        ring.outerEdge(const Size(60, 20)),
        Rect.fromCenter(center: const Offset(30, 10), width: 84, height: 40),
      );
    });

    test('repaints only when what it draws changes', () {
      expect(ring.shouldRepaint(ring), isFalse);
      for (final other in const [
        MmFocusRingPainter(
          color: Color(0xFF000000),
          radius: MmRadius.sm,
          height: 40,
          widthOutset: MmSpace.s3,
        ),
        MmFocusRingPainter(
          color: Color(0xFF1D3F8F),
          radius: MmRadius.xs,
          height: 40,
          widthOutset: MmSpace.s3,
        ),
        MmFocusRingPainter(
          color: Color(0xFF1D3F8F),
          radius: MmRadius.sm,
          size: Size(64, 32),
          height: 40,
          widthOutset: MmSpace.s3,
        ),
        MmFocusRingPainter(
          color: Color(0xFF1D3F8F),
          radius: MmRadius.sm,
          height: 48,
          widthOutset: MmSpace.s3,
        ),
        MmFocusRingPainter(
          color: Color(0xFF1D3F8F),
          radius: MmRadius.sm,
          height: 40,
        ),
      ]) {
        expect(ring.shouldRepaint(other), isTrue);
      }
    });

    test('needs a size or a height', () {
      expect(
        () => MmFocusRingPainter(
          color: const Color(0xFF1D3F8F),
          radius: double.parse('8'),
        ),
        throwsAssertionError,
      );
    });
  });
}
