import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _boundary = ValueKey<String>('avatar');

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

    testWidgets('sets Urdu initials in Nastaliq a size smaller than Latin', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmAvatar(name: 'علی رضا'),
        variant: MmVariant.urdu,
      );
      final style = styleOf(tester, 'ع');
      expect(style.fontFamily, contains(MmFontFamily.urdu));
      expect(style.fontSize, 40 * 0.3);
      expect(style.height, 1);
    });

    testWidgets('scales wide initials down to fit across the circle', (
      tester,
    ) async {
      // ک and گ are each about one and a half ems wide.
      await pumpThemed(tester, const MmAvatar(name: 'کامران گل'));
      final style = styleOf(tester, 'ک');
      expect(style.fontSize, lessThan(40 * 0.3));
      final ink = tester.getSize(find.byType(Text));
      expect(ink.width, lessThanOrEqualTo(40 * 0.7 + 0.01));
    });

    testWidgets('places a letter it has no measure for as it places ع', (
      tester,
    ) async {
      // ڡ, a dotless Arabic letter no Pakistani name begins with.
      await pumpThemed(tester, const MmAvatar(name: 'ڡ'));
      final unknown = tester.getRect(find.byType(Text)).top;
      await pumpThemed(tester, const MmAvatar(name: 'ع'));
      expect(tester.getRect(find.byType(Text)).top, unknown);
    });

    for (final variant in [MmVariant.light, MmVariant.urdu]) {
      testWidgets('centres initials on their ink (${variant.name})', (
        tester,
      ) async {
        final fill = colorsOf(variant).primaryContainer;
        const names = [
          'Ali Raza',
          'Bilal',
          'علی رضا',
          'عائشہ خان',
          'محمد علی',
          'گل خان',
          'ریحانہ',
          // Sindhi and Pashto initials.
          'ٻاجھ ڪريم',
          'ښکلی ځلمی',
        ];
        for (final size in [24.0, 56.0]) {
          for (final name in names) {
            await pumpThemed(
              tester,
              RepaintBoundary(
                key: _boundary,
                child: MmAvatar(name: name, size: size),
              ),
              variant: variant,
            );
            final ink = await inkOnCircle(tester, find.byKey(_boundary), fill);
            // Within a pixel of the middle, as Latin capitals are. Before,
            // Urdu initials sat 9.5 dp low at 56 dp.
            expect(
              ink.center.dy,
              moreOrLessEquals(size / 2, epsilon: 1),
              reason: '$name at $size',
            );
          }
        }
      });
    }

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
