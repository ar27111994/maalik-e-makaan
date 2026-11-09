import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_wrap.dart';

import '../support/testing.dart';

/// Two boxes of 60 and 30 dp in a wrap with [spacing] between them.
MmWrap _pair({double spacing = 8, Key? key}) => MmWrap(
  key: key,
  spacing: spacing,
  children: const [
    SizedBox(width: 60, height: 20),
    SizedBox(width: 30, height: 20),
  ],
);

void main() {
  group('MmWrap', () {
    testWidgets('its widest intrinsic width counts its spacing', (
      tester,
    ) async {
      await pumpThemed(tester, Center(child: _pair()));
      final wrap = tester.renderObject<RenderBox>(find.byType(MmWrap));
      expect(wrap.getMaxIntrinsicWidth(double.infinity), 98);
      // Flutter's own wrap leaves the spacing out.
      expect(
        tester
            .renderObject<RenderWrap>(find.byType(Wrap))
            .getMaxIntrinsicWidth(double.infinity),
        90,
      );
      expect(tester.getSize(find.byType(MmWrap)), const Size(98, 20));

      // A rebuild with other spacing measures again; one child has none.
      await pumpThemed(tester, Center(child: _pair()));
      await pumpThemed(tester, Center(child: _pair(spacing: 16)));
      expect(wrap.getMaxIntrinsicWidth(double.infinity), 106);
      await pumpThemed(
        tester,
        const Center(
          child: MmWrap(
            spacing: 16,
            children: [SizedBox(width: 60, height: 20)],
          ),
        ),
      );
      expect(
        tester
            .renderObject<RenderBox>(find.byType(MmWrap))
            .getMaxIntrinsicWidth(double.infinity),
        60,
      );
    });

    testWidgets('passes its settings to the wrap', (tester) async {
      await pumpThemed(
        tester,
        const MmWrap(
          spacing: 4,
          runSpacing: 2,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          textDirection: TextDirection.rtl,
          children: [SizedBox.shrink()],
        ),
      );
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 4);
      expect(wrap.runSpacing, 2);
      expect(wrap.alignment, WrapAlignment.end);
      expect(wrap.crossAxisAlignment, WrapCrossAlignment.center);
      expect(wrap.textDirection, TextDirection.rtl);
    });

    testWidgets('beside a reflow text it keeps one line when it fits', (
      tester,
    ) async {
      // 100 dp of text, 16 dp of space and 98 dp of wrap: exactly 214 dp.
      // With the spacing left out, the reflow would put the wrap beside the
      // text with 8 dp too little, and the wrap would break in two.
      const key = Key('pair');
      await pumpThemed(
        tester,
        Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: 214,
            child: MmReflow(
              start: const SizedBox(width: 100, height: 20),
              end: _pair(key: key),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(key)), const Size(98, 20));
      expect(tester.getSize(find.byType(MmReflow)).height, 20);
    });
  });
}
