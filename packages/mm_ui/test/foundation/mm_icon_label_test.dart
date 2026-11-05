import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../support/testing.dart';

const _label = 'Overdue by 12 days since the 5th of October';

Widget _iconLabel({
  IconData icon = MmIcons.warning,
  double iconSize = MmSize.iconSm,
  TextAlign textAlign = TextAlign.start,
}) => SizedBox(
  width: 200,
  child: Builder(
    builder: (context) => MmIconLabel(
      icon: icon,
      label: _label,
      style: Theme.of(context).textTheme.bodyMedium!,
      iconColor: context.mm.colors.overdue,
      iconSize: iconSize,
      textAlign: textAlign,
    ),
  ),
);

void main() {
  group('MmIconLabel', () {
    testWidgets('sets the icon before the words, in its colour', (
      tester,
    ) async {
      await pumpThemed(tester, _iconLabel());
      final icon = tester.widget<Icon>(find.byIcon(MmIcons.warning));
      expect(icon.color, MmColorModes.light.overdue);
      expect(tester.getSize(find.byIcon(MmIcons.warning)).width, MmSize.iconSm);
      final paragraph = paragraphOf(tester, _label);
      // One paragraph: the words wrap under the icon.
      final style = paragraph.text.style!;
      expect(
        paragraph.size.height,
        moreOrLessEquals(2 * style.fontSize! * style.height!, epsilon: 0.5),
      );
      expect(
        tester.getCenter(find.byIcon(MmIcons.warning)).dx,
        lessThan(
          paragraph.localToGlobal(paragraph.size.center(Offset.zero)).dx,
        ),
      );
    });

    testWidgets('mirrors right to left, the icon at the start edge', (
      tester,
    ) async {
      await pumpThemed(tester, _iconLabel(), variant: MmVariant.urdu);
      final box = tester.getRect(find.byType(MmIconLabel));
      expect(
        tester.getRect(find.byIcon(MmIcons.warning)).right,
        moreOrLessEquals(box.right, epsilon: MmSpace.s1),
      );
    });

    testWidgets('grows the icon with the text, at most one and a half times', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _iconLabel(iconSize: MmSize.iconMd),
        variant: MmVariant.largeText,
      );
      // At 200% text the icon stops at 150%.
      expect(
        tester.getRect(find.byIcon(MmIcons.warning)).width,
        moreOrLessEquals(MmSize.iconMd * MmIconLabel.maxIconScale),
      );
      await pumpThemed(
        tester,
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.25,
          child: _iconLabel(iconSize: MmSize.iconMd),
        ),
        variant: MmVariant.largeText,
      );
      // Below the cap it grows with the text.
      expect(
        tester.getRect(find.byIcon(MmIcons.warning)).width,
        moreOrLessEquals(MmSize.iconMd * 1.25),
      );
    });

    testWidgets('aligns its lines as asked', (tester) async {
      await pumpThemed(tester, _iconLabel(textAlign: TextAlign.center));
      expect(paragraphOf(tester, _label).textAlign, TextAlign.center);
    });

    testWidgets('is read as its words alone', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, Semantics(container: true, child: _iconLabel()));
      expect(
        tester.getSemantics(find.byType(MmIconLabel)),
        isSemantics(label: _label),
      );
      handle.dispose();
    });
  });
}
