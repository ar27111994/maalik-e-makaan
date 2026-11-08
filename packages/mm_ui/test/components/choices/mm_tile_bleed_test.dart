import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_tile_bleed.dart';

import '../../support/testing.dart';

const _child = ValueKey<String>('child');

void main() {
  group('MmTileBleed', () {
    testWidgets('lays its child out 16 dp past each side of its place', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 200,
          child: MmTileBleed(child: SizedBox(key: _child, height: 40)),
        ),
      );
      final place = tester.getRect(find.byType(MmTileBleed));
      final child = tester.getRect(find.byKey(_child));
      expect(place.size, const Size(200, 40));
      expect(child.left, place.left - MmSpace.s4);
      expect(child.right, place.right + MmSpace.s4);
    });

    testWidgets('measures as its child less the bleed', (tester) async {
      await pumpThemed(
        tester,
        const MmTileBleed(
          bleed: MmSpace.s2,
          child: Text('Send rent reminders'),
        ),
      );
      final bleed = tester.renderObject<RenderMmTileBleed>(
        find.byType(MmTileBleed),
      );
      final text = tester.renderObject<RenderBox>(find.byType(Text));
      expect(
        bleed.getMaxIntrinsicWidth(double.infinity),
        text.getMaxIntrinsicWidth(double.infinity) - 2 * MmSpace.s2,
      );
      expect(
        bleed.getMinIntrinsicWidth(double.infinity),
        text.getMinIntrinsicWidth(double.infinity) - 2 * MmSpace.s2,
      );
      // At a width, as tall as the child at that width plus the bleed.
      expect(
        bleed.getMinIntrinsicHeight(60),
        text.getMinIntrinsicHeight(60 + 2 * MmSpace.s2),
      );
      expect(
        bleed.getMaxIntrinsicHeight(60),
        text.getMaxIntrinsicHeight(60 + 2 * MmSpace.s2),
      );
      const constraints = BoxConstraints(maxWidth: 60);
      final wider = constraints.copyWith(maxWidth: 60 + 2 * MmSpace.s2);
      expect(
        bleed.getDryLayout(constraints),
        Size(
          text.getDryLayout(wider).width - 2 * MmSpace.s2,
          text.getDryLayout(wider).height,
        ),
      );
      expect(
        bleed.getDryBaseline(constraints, TextBaseline.alphabetic),
        text.getDryBaseline(wider, TextBaseline.alphabetic),
      );
      // Never narrower than nothing.
      final empty = RenderMmTileBleed(MmSpace.s4)
        ..child = RenderConstrainedBox(
          additionalConstraints: const BoxConstraints.tightFor(width: 10),
        );
      expect(empty.getMaxIntrinsicWidth(double.infinity), 0);
    });

    testWidgets('takes a new bleed', (tester) async {
      Future<void> pumpWith(double bleed) => pumpThemed(
        tester,
        SizedBox(
          width: 200,
          child: MmTileBleed(
            bleed: bleed,
            child: const SizedBox(key: _child, height: 40),
          ),
        ),
      );
      await pumpWith(MmSpace.s4);
      await pumpWith(MmSpace.s2);
      expect(tester.getSize(find.byKey(_child)).width, 200 + 2 * MmSpace.s2);
      // The same bleed again changes nothing.
      tester.renderObject<RenderMmTileBleed>(find.byType(MmTileBleed)).bleed =
          MmSpace.s2;
      expect(
        tester
            .renderObject<RenderMmTileBleed>(find.byType(MmTileBleed))
            .debugNeedsLayout,
        isFalse,
      );
    });
  });
}
