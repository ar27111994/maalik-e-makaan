import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../support/testing.dart';

void main() {
  group('MmIconLabel.scaledSize', () {
    for (final (scale, expected) in [(1.0, 24.0), (1.3, 31.2), (2.0, 36.0)]) {
      testWidgets('grows with $scale× text up to half again', (tester) async {
        late double size;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                size = MmIconLabel.scaledSize(context, MmSize.iconLg);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(size, closeTo(expected, 1e-9));
      });
    }

    testWidgets('fields use it for their icons at 200% text', (tester) async {
      await pumpLargeNarrow(tester, const MmSearchField());
      final glyph = tester.widget<RichText>(
        find.descendant(
          of: find.byIcon(MmIcons.search),
          matching: find.byType(RichText),
        ),
      );
      expect(
        glyph.text.style!.fontSize,
        MmSize.iconLg * MmIconLabel.maxIconScale,
      );
    });
  });
}
