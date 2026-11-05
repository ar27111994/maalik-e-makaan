import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// The circle of the avatar.
BoxDecoration _circle(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(MmAvatar),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  group('MmAvatar.initialsOf', () {
    test('takes the first letter of the first two words', () {
      expect(MmAvatar.initialsOf('Ali Raza'), 'AR');
      expect(MmAvatar.initialsOf('ayesha khan'), 'AK');
      expect(MmAvatar.initialsOf('Muhammad Ali Raza'), 'MA');
      expect(MmAvatar.initialsOf('  Bilal  '), 'B');
      expect(MmAvatar.initialsOf('Ali\t\nRaza'), 'AR');
    });

    test('keeps Urdu initials apart as separate letters', () {
      expect(MmAvatar.initialsOf('علی رضا'), 'ع\u200Cر');
      expect(MmAvatar.initialsOf('عائشہ'), 'ع');
    });

    test('takes whole graphemes and ignores spoofing characters', () {
      expect(MmAvatar.initialsOf('\u202EAli Raza'), 'AR');
      expect(MmAvatar.initialsOf('👩🏽 Khan'), '👩🏽K');
    });

    test('is empty for a name without words', () {
      expect(MmAvatar.initialsOf(''), '');
      expect(MmAvatar.initialsOf('   '), '');
    });
  });

  group('MmAvatar', () {
    testEveryVariant('is a circle of the cobalt tone with the initials', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmAvatar(name: 'Ali Raza'),
        variant: variant,
      );
      final colors = colorsOf(variant);
      expect(tester.getSize(find.byType(MmAvatar)), const Size.square(40));
      final circle = _circle(tester);
      expect(circle.shape, BoxShape.circle);
      expect(circle.color, colors.primaryContainer);
      expect(find.text('AR'), findsOneWidget);
      final style = styleOf(tester, 'AR');
      expect(style.color, colors.onPrimaryContainer);
      expect(style.fontSize, 16);
      // Latin initials are set in the Latin face in both languages.
      expect(style.fontFamily, contains(MmFontFamily.latin));
    });

    testWidgets('takes its size, and keeps it at 200% text', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmAvatar(name: 'Ayesha Khan', size: 24),
      );
      expect(tester.getSize(find.byType(MmAvatar)), const Size.square(24));
      final text = tester.widget<Text>(find.text('AK'));
      expect(text.textScaler, TextScaler.noScaling);
      final initials = tester.getRect(find.text('AK'));
      final avatar = tester.getRect(find.byType(MmAvatar));
      expect(avatar.contains(initials.topLeft), isTrue);
      expect(avatar.contains(initials.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scales tall Nastaliq initials down to fit the circle', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmAvatar(name: 'علی رضا'),
        variant: MmVariant.urdu,
      );
      final style = styleOf(tester, 'ع');
      expect(style.fontFamily, contains(MmFontFamily.urdu));
      final initials = tester.getRect(find.byType(Text));
      expect(initials.height, lessThanOrEqualTo(40 * 0.7 + 0.01));
    });

    testWidgets('sets Urdu initials in Nastaliq in the English UI', (
      tester,
    ) async {
      await pumpThemed(tester, const MmAvatar(name: 'علی رضا'));
      expect(styleOf(tester, 'ع').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
    });

    testWidgets('shows an icon in place of the initials', (tester) async {
      await pumpThemed(
        tester,
        const MmAvatar(
          name: 'Gulberg Heights',
          icon: MmIcons.property,
          size: 56,
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MmIcons.property);
      expect(icon.size, 28);
      expect(icon.color, MmColorModes.light.onPrimaryContainer);
      expect(find.text('GH'), findsNothing);
    });

    testWidgets('a name without letters shows the person icon', (tester) async {
      await pumpThemed(tester, const MmAvatar(name: ' '));
      expect(tester.widget<Icon>(find.byType(Icon)).icon, MmIcons.person);
    });

    testWidgets('is hidden from screen readers', (tester) async {
      await pumpThemed(tester, const MmAvatar(name: 'Ali Raza'));
      expect(find.bySemanticsLabel('AR'), findsNothing);
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('outside a tinted surface it keeps the tonal fill', (
      tester,
    ) async {
      await pumpThemed(tester, const MmCard(child: MmAvatar(name: 'Ali Raza')));
      expect(_circle(tester).color, MmColorModes.light.primaryContainer);
    });
  });
}
