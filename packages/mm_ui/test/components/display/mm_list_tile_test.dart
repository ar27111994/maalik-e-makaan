import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _name = 'Ali Raza';
const _unit = 'Flat 3, Gulberg III';
const _long = 'Gulberg Heights, Block C, Main Boulevard, Lahore';

const _amount = MmAmount(amount: Money.fromRupees(45000));

void main() {
  group('MmListTile', () {
    testWidgets('shows its title, subtitle, leading and trailing widgets', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          subtitle: _unit,
          leading: MmAvatar(name: _name),
          trailing: _amount,
        ),
      );
      expect(find.text(_name), findsOneWidget);
      expect(find.text(_unit), findsOneWidget);
      expect(find.byType(MmAvatar), findsOneWidget);
      expect(find.byType(MmAmount), findsOneWidget);
      const tile = MmListTile(title: _name);
      expect(tile.subtitleMaxLines, 2);
      expect(tile.selected, isFalse);
    });

    testEveryVariant('sets its text in the list styles of the theme', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(title: _name, subtitle: _unit),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final title = styleOf(tester, _name);
      expect(title.fontSize, text.bodyLarge!.fontSize);
      expect(title.color, colors.ink);
      final subtitle = styleOf(tester, _unit);
      expect(subtitle.fontSize, text.bodyMedium!.fontSize);
      expect(subtitle.color, colors.inkMuted);
    });

    testWidgets('is at least 56 dp tall', (tester) async {
      await pumpThemed(tester, const MmListTile(title: _name));
      expect(
        tester.getSize(find.byType(MmListTile)).height,
        MmSize.fieldHeight,
      );
    });

    testWidgets('icons take the muted ink at 24 dp', (tester) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          leading: Icon(MmIcons.person),
          trailing: Icon(MmIcons.chevronEnd),
        ),
      );
      for (final icon in [MmIcons.person, MmIcons.chevronEnd]) {
        final theme = IconTheme.of(tester.element(find.byIcon(icon)));
        expect(theme.color, MmColorModes.light.inkMuted);
        expect(theme.size, MmSize.iconLg);
      }
      // Plain trailing text takes the muted body-small style.
      await pumpThemed(
        tester,
        const MmListTile(title: _name, trailing: Text('5 Nov')),
      );
      expect(styleOf(tester, '5 Nov').color, MmColorModes.light.inkMuted);
    });

    testWidgets('the trailing widget sits at the end when it fits', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(title: _name, subtitle: _unit, trailing: _amount),
      );
      final tile = tester.getRect(find.byType(MmListTile));
      final title = tester.getRect(find.text(_name));
      final subtitle = tester.getRect(find.text(_unit));
      final amount = tester.getRect(find.byType(MmAmount));
      expect(amount.right, tile.right - MmSpace.s4);
      expect(amount.left, greaterThan(title.right));
      // Centred against the text.
      expect(
        amount.center.dy,
        moreOrLessEquals((title.top + subtitle.bottom) / 2, epsilon: 0.5),
      );
    });

    testWidgets('mirrors right to left', (tester) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          leading: Icon(MmIcons.person),
          trailing: _amount,
        ),
        variant: MmVariant.urdu,
      );
      final tile = tester.getRect(find.byType(MmListTile));
      final leading = tester.getRect(find.byIcon(MmIcons.person));
      final title = tester.getRect(find.text(_name));
      final amount = tester.getRect(find.byType(MmAmount));
      expect(leading.right, tile.right - MmSpace.s4);
      expect(title.right, leading.left - MmSpace.s4);
      expect(amount.left, tile.left + MmSpace.s4);
    });

    testWidgets('moves the trailing widget under the text when the title '
        'would be squeezed', (tester) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _long,
          subtitle: _unit,
          leading: Icon(MmIcons.property),
          trailing: _amount,
        ),
      );
      final title = tester.getRect(find.text(_long));
      final subtitle = tester.getRect(find.text(_unit));
      final amount = tester.getRect(find.byType(MmAmount));
      expect(amount.top, subtitle.bottom + MmSpace.s1);
      expect(amount.left, title.left);
    });

    testWidgets('at 200% on a 320 dp phone, wraps the title and moves the '
        'trailing widget below', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmListTile(
          title: _long,
          subtitle: _unit,
          leading: MmAvatar(name: _name),
          trailing: MmStatusBadge(
            status: MmStatus.overdue,
            label: 'Overdue 12 days',
          ),
          onTap: _noop,
        ),
      );
      expect(tester.takeException(), isNull);
      final title = paragraphOf(tester, _long);
      expect(title.maxLines, isNull);
      expect(title.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(_long)).height, greaterThan(56 * 2));
      final badge = tester.getRect(find.byType(MmStatusBadge));
      expect(badge.top, greaterThan(tester.getRect(find.text(_unit)).bottom));
      expect(tester.getSize(find.byType(MmListTile)).width, 288);
    });

    testWidgets('ends the subtitle with an ellipsis after its lines', (
      tester,
    ) async {
      const subtitle =
          'WASA Lahore, consumer 0412 3345 6789, paid by the tenant with the '
          'rent every month since March';
      await pumpThemed(
        tester,
        const MmListTile(title: _name, subtitle: subtitle),
      );
      var paragraph = paragraphOf(tester, subtitle);
      expect(paragraph.maxLines, 2);
      expect(paragraph.overflow, TextOverflow.ellipsis);

      await pumpThemed(
        tester,
        const MmListTile(title: _name, subtitle: subtitle, subtitleMaxLines: 1),
      );
      paragraph = paragraphOf(tester, subtitle);
      expect(paragraph.maxLines, 1);
      expect(paragraph.didExceedMaxLines, isTrue);
    });

    testWidgets('is one node reading title, subtitle and trailing', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          subtitle: _unit,
          leading: MmAvatar(name: _name),
          trailing: _amount,
          onTap: _noop,
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        matchesSemantics(
          label: '$_name\n$_unit\n45000 rupees',
          isButton: true,
          hasSelectedState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('without onTap it only shows information', (tester) async {
      await pumpThemed(tester, const MmListTile(title: _name));
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        matchesSemantics(label: _name, hasSelectedState: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _name), isFalse);
    });

    testWidgets('calls onTap on tap and from the keyboard, with a ring', (
      tester,
    ) async {
      var taps = 0;
      final tile = find.byType(MmListTile);
      await pumpThemed(tester, MmListTile(title: _name, onTap: () => taps++));
      await tester.tap(tile);
      expect(taps, 1);
      expect(sideOf(tester, tile), BorderSide.none);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _name), isTrue);
      expect(
        sideOf(tester, tile),
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 3);
    });

    testEveryVariant('selected, it is tinted, heavier and announced', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          subtitle: _unit,
          leading: MmAvatar(name: _name),
          selected: true,
          onTap: _noop,
        ),
        variant: variant,
      );
      final colors = colorsOf(variant);
      expect(
        surfaceOf(tester, find.byType(MmListTile)).color,
        colors.primaryContainer,
      );
      final title = styleOf(tester, _name);
      expect(title.fontWeight, FontWeight.w600);
      expect(title.color, colors.onPrimaryContainer);
      expect(styleOf(tester, _unit).color, colors.onPrimaryContainer);
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        isSemantics(isSelected: true, isButton: true),
      );
      // The avatar takes the strong cobalt so its circle stays visible.
      final circle = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(MmAvatar),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((circle.decoration as BoxDecoration).color, colors.primary);
    });

    testWidgets('unselected, it has no fill', (tester) async {
      await pumpThemed(tester, const MmListTile(title: _name));
      expect(
        surfaceOf(tester, find.byType(MmListTile)).color,
        Colors.transparent,
      );
      expect(styleOf(tester, _name).fontWeight, FontWeight.w400);
    });

    testWidgets('sets Latin user data in the Latin face in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmListTile(title: _name, subtitle: 'گلبرگ، لاہور'),
        variant: MmVariant.urdu,
      );
      expect(styleOf(tester, _name).fontFamily, contains(MmFontFamily.latin));
      expect(
        styleOf(tester, 'گلبرگ، لاہور').fontFamily,
        contains(MmFontFamily.urdu),
      );
    });

    testWidgets('sets Urdu user data in Nastaliq in the English UI', (
      tester,
    ) async {
      await pumpThemed(tester, const MmListTile(title: 'علی رضا'));
      final style = styleOf(tester, 'علی رضا');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFamilyFallback, ['packages/mm_ui/${MmFontFamily.urdu}']);
    });
  });
}

void _noop() {}
