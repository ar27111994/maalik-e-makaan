import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../support/testing.dart';

const _label = 'Overdue since 5 October';

Widget _iconLabel(TextWidthBasis? basis) => SizedBox(
  width: 150,
  child: Align(
    alignment: AlignmentDirectional.centerStart,
    child: Builder(
      builder: (context) {
        final style = Theme.of(context).textTheme.bodyMedium!;
        final color = context.mm.colors.overdue;
        return basis == null
            ? MmIconLabel(
                icon: MmIcons.warning,
                label: _label,
                style: style,
                iconColor: color,
              )
            : MmIconLabel(
                icon: MmIcons.warning,
                label: _label,
                style: style,
                iconColor: color,
                textWidthBasis: basis,
              );
      },
    ),
  ),
);

void main() {
  group('MmIconLabel.textWidthBasis', () {
    testWidgets('takes the width it is given by default', (tester) async {
      await pumpThemed(tester, _iconLabel(null));
      final paragraph = paragraphOf(tester, _label);
      expect(paragraph.textWidthBasis, TextWidthBasis.parent);
      expect(paragraph.size.width, 150);
    });

    testWidgets('can be as wide as its longest line', (tester) async {
      await pumpThemed(tester, _iconLabel(TextWidthBasis.longestLine));
      final paragraph = paragraphOf(tester, _label);
      expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
      // Two lines, neither of them the whole width.
      expect(paragraph.size.height, greaterThan(30));
      expect(paragraph.size.width, lessThan(150));
    });
  });
}
