import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _name = 'Raza Manzil';
const _address = 'House 12, Street 4, Gulberg III, Lahore';

/// The plate's outer brass frame.
BoxDecoration _plate(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(MmNameplate),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

/// The engraved hairline inside the frame.
BoxDecoration _engraving(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(MmNameplate),
                    matching: find.byType(DecoratedBox),
                  )
                  .at(1),
            )
            .decoration
        as BoxDecoration;

void main() {
  group('MmNameplate', () {
    testEveryVariant('engraves the name on a brass-framed plate', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: _name, subtitle: _address, icon: MmIcons.home),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final plate = _plate(tester);
      expect(plate.color, colors.brassContainer);
      expect(plate.border, Border.all(color: colors.brass, width: 2));
      expect(
        plate.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.xs)),
      );
      expect(plate.boxShadow, isNull);
      expect(_engraving(tester).border, Border.all(color: colors.brass));
      final name = styleOf(tester, _name);
      expect(name.color, colors.onBrassContainer);
      expect(name.fontSize, text.titleLarge!.fontSize);
      final subtitle = styleOf(tester, _address);
      expect(subtitle.color, colors.onBrassContainer);
      expect(subtitle.fontSize, text.bodyMedium!.fontSize);
      expect(
        tester.widget<Icon>(find.byIcon(MmIcons.home)).color,
        colors.onBrassContainer,
      );
    });

    testWidgets('sets the words 12 dp inside the plate, the icon at the '
        'start', (tester) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: _name, subtitle: 'Gulberg', icon: MmIcons.home),
      );
      final plate = tester.getRect(find.byType(MmNameplate));
      final icon = tester.getRect(find.byIcon(MmIcons.home));
      final name = tester.getRect(find.text(_name));
      expect(icon.left, plate.left + MmSpace.s3);
      expect(name.left, icon.right + MmSpace.s3);
      expect(name.top, plate.top + MmSpace.s3);
      expect(
        tester.getRect(find.text('Gulberg')).bottom,
        plate.bottom - MmSpace.s3,
      );
      // The plate is as wide as its words.
      expect(
        plate.right,
        moreOrLessEquals(
          tester.getRect(find.text(_name)).right + MmSpace.s3,
          epsilon: 0.01,
        ),
      );
    });

    testWidgets('centres the icon on the first line of the name', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: _name, subtitle: _address, icon: MmIcons.home),
      );
      final name = tester.getRect(find.text(_name));
      final icon = tester.getRect(find.byIcon(MmIcons.home));
      expect(icon.size, const Size.square(MmSize.iconLg));
      expect(icon.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.01));
    });

    testWidgets('mirrors right to left', (tester) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: 'رضا منزل', icon: MmIcons.home),
        variant: MmVariant.urdu,
      );
      final plate = tester.getRect(find.byType(MmNameplate));
      final icon = tester.getRect(find.byIcon(MmIcons.home));
      expect(icon.right, plate.right - MmSpace.s3);
      expect(
        tester.getRect(find.text('رضا منزل')).right,
        icon.left - MmSpace.s3,
      );
    });

    testWidgets('reads the name as a header, then the address; the icon is '
        'silent', (tester) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: _name, subtitle: _address, icon: MmIcons.home),
      );
      expect(
        tester.getSemantics(find.text(_name)),
        matchesSemantics(label: _name, isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(_address)),
        matchesSemantics(label: _address),
      );
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byIcon(MmIcons.home),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without an icon or an address, shows just the name', (
      tester,
    ) async {
      await pumpThemed(tester, const MmNameplate(name: _name));
      expect(find.byType(Icon), findsNothing);
      final plate = tester.getRect(find.byType(MmNameplate));
      final name = tester.getRect(find.text(_name));
      expect(name.left, plate.left + MmSpace.s3);
      expect(name.bottom, plate.bottom - MmSpace.s3);
    });

    testWidgets('at 200% on a 320 dp phone, wraps without overflowing and '
        'grows the icon by half', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmNameplate(
          name: 'Gulberg Heights, Block C',
          subtitle: _address,
          icon: MmIcons.property,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmNameplate)).width, 288);
      final icon = tester.getRect(find.byIcon(MmIcons.property));
      expect(icon.size, const Size.square(MmSize.iconLg * 1.5));
      final name = tester.getRect(find.text('Gulberg Heights, Block C'));
      final line = MmVariant.largeText.theme.textTheme.titleLarge!;
      expect(name.height, greaterThan(line.fontSize! * line.height! * 2));
      expect(
        icon.center.dy,
        moreOrLessEquals(
          name.top + line.fontSize! * line.height! * 2 / 2,
          epsilon: 0.01,
        ),
      );
    });

    testWidgets('sets a name written in English in the Latin face in the '
        'Urdu UI, and one written in Urdu with Nastaliq in the English UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmNameplate(name: 'Gulberg Heights', subtitle: 'گلبرگ، لاہور'),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Gulberg Heights').fontFamily,
        contains(MmFontFamily.latin),
      );
      expect(
        styleOf(tester, 'گلبرگ، لاہور').fontFamily,
        contains(MmFontFamily.urdu),
      );

      await pumpThemed(tester, const MmNameplate(name: 'رضا منزل'));
      expect(styleOf(tester, 'رضا منزل').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
    });
  });
}
