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

/// The layout that puts the leading widget beside the text.
Finder _layout() => find.descendant(
  of: find.byType(MmListTile),
  matching: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_TileLayout',
  ),
);

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
      final title = tester.getRect(find.textContaining(_name));
      final amount = tester.getRect(find.byType(MmAmount));
      expect(leading.right, tile.right - MmSpace.s4);
      expect(title.right, leading.left - MmSpace.s4);
      expect(amount.left, tile.left + MmSpace.s4);
    });

    testWidgets('moves the trailing widget under the text when the title '
        'would be squeezed, keeping it at the end edge', (tester) async {
      const tile = MmListTile(
        title: _long,
        subtitle: _unit,
        leading: Icon(MmIcons.property),
        trailing: _amount,
      );
      await pumpThemed(tester, tile);
      var row = tester.getRect(find.byType(MmListTile));
      var subtitle = tester.getRect(find.text(_unit));
      var amount = tester.getRect(find.byType(MmAmount));
      expect(amount.top, subtitle.bottom + MmSpace.s1);
      // Lists of money keep their amounts at the end edge.
      expect(amount.right, row.right - MmSpace.s4);

      await pumpThemed(tester, tile, variant: MmVariant.urdu);
      row = tester.getRect(find.byType(MmListTile));
      subtitle = tester.getRect(find.textContaining(_unit));
      amount = tester.getRect(find.byType(MmAmount));
      expect(amount.top, subtitle.bottom + MmSpace.s1);
      expect(amount.left, row.left + MmSpace.s4);
    });

    testWidgets('at 200% on a 320 dp phone, wraps the title in whole words '
        'and moves the trailing widget below', (tester) async {
      await expectWholeAtLargeText(
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
        then: (locale) {
          final title = paragraphOf(tester, _long);
          expect(title.maxLines, isNull);
          expect(title.didExceedMaxLines, isFalse);
          expect(
            tester.getSize(find.textContaining(_long)).height,
            greaterThan(56 * 2),
          );
          final row = tester.getRect(find.byType(MmListTile));
          final badge = tester.getRect(find.byType(MmStatusBadge));
          expect(
            badge.top,
            greaterThan(tester.getRect(find.textContaining(_unit)).bottom),
          );
          if (locale.languageCode == 'ur') {
            expect(badge.left, row.left + MmSpace.s4);
          } else {
            expect(badge.right, row.right - MmSpace.s4);
          }
          expect(row.width, 288);
        },
      );
    });

    testWidgets('centres the leading widget on a short row', (tester) async {
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          subtitle: _unit,
          leading: MmAvatar(name: _name),
        ),
      );
      final avatar = tester.getRect(find.byType(MmAvatar));
      final title = tester.getRect(find.text(_name));
      final subtitle = tester.getRect(find.text(_unit));
      expect(
        avatar.center.dy,
        moreOrLessEquals((title.top + subtitle.bottom) / 2, epsilon: 0.01),
      );
      // A leading widget taller than one line of text puts the line in its
      // middle.
      await pumpThemed(
        tester,
        const MmListTile(
          title: _name,
          leading: MmAvatar(name: _name, size: 64),
        ),
      );
      expect(
        tester.getRect(find.text(_name)).center.dy,
        moreOrLessEquals(
          tester.getRect(find.byType(MmAvatar)).center.dy,
          epsilon: 0.01,
        ),
      );
      expect(tester.getSize(find.byType(MmListTile)).height, 64 + 24);
    });

    testWidgets("lines the leading widget up with a tall row's first line", (
      tester,
    ) async {
      const longer = '$_long, near Liberty Market, Punjab';
      for (final variant in [MmVariant.largeText, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          const MmListTile(
            title: longer,
            subtitle: _unit,
            leading: Icon(MmIcons.property),
            trailing: _amount,
          ),
          variant: variant,
          size: const Size(320, 740),
        );
        final title = tester.getRect(find.textContaining(longer));
        final icon = tester.getRect(find.byIcon(MmIcons.property));
        final style = variant.theme.textTheme.bodyLarge!;
        final firstLine = style.fontSize! * variant.textScale * style.height!;
        expect(title.height, greaterThan(2 * firstLine), reason: variant.name);
        expect(
          icon.center.dy,
          moreOrLessEquals(title.top + firstLine / 2, epsilon: 0.01),
          reason: variant.name,
        );
      }
    });

    testWidgets('sizes itself without a width limit', (tester) async {
      await pumpThemed(
        tester,
        const UnconstrainedBox(
          child: MmListTile(title: _name, leading: Icon(MmIcons.person)),
        ),
      );
      final row = tester.getRect(find.byType(MmListTile));
      final icon = tester.getRect(find.byIcon(MmIcons.person));
      final title = tester.getRect(find.text(_name));
      expect(icon.left, row.left + MmSpace.s4);
      expect(title.left, icon.right + MmSpace.s4);
      expect(row.right, title.right + MmSpace.s4);
    });

    testWidgets('reports its intrinsic sizes and baseline', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmListTile(title: _name, leading: Icon(MmIcons.person)),
            MmListTile(title: _unit),
          ],
        ),
      );
      final withLeading = tester.renderObject<RenderBox>(_layout().first);
      final plain = tester.renderObject<RenderBox>(_layout().last);
      final title = tester.getSize(find.text(_name));
      const icon = MmSize.iconLg + MmSpace.s4;
      expect(
        withLeading.getMaxIntrinsicWidth(double.infinity),
        icon + title.width,
      );
      expect(
        withLeading.getMinIntrinsicWidth(double.infinity),
        lessThan(icon + title.width),
      );
      expect(
        plain.getMaxIntrinsicWidth(double.infinity),
        tester.getSize(find.text(_unit)).width,
      );
      // One line of text beside a 24 dp icon; the row's least height comes
      // from outside, not from its content.
      expect(withLeading.getMinIntrinsicHeight(300), title.height);
      expect(withLeading.getMaxIntrinsicHeight(300), title.height);
      expect(withLeading.size.height, greaterThan(title.height));
      final baseline = withLeading.getDryBaseline(
        withLeading.constraints,
        TextBaseline.alphabetic,
      );
      final paragraph = paragraphOf(tester, _name);
      expect(
        baseline,
        moreOrLessEquals(
          paragraph.localToGlobal(Offset.zero).dy -
              withLeading.localToGlobal(Offset.zero).dy +
              paragraph.getDryBaseline(
                paragraph.constraints,
                TextBaseline.alphabetic,
              )!,
          epsilon: 0.01,
        ),
      );

      // Laid out on a baseline, its text sits on it.
      await pumpThemed(
        tester,
        const Baseline(
          baseline: 40,
          baselineType: TextBaseline.alphabetic,
          child: MmListTile(title: _name, leading: Icon(MmIcons.person)),
        ),
      );
      final box = tester.getRect(find.byType(Baseline));
      final text = paragraphOf(tester, _name);
      expect(
        text.localToGlobal(Offset.zero).dy -
            box.top +
            text.getDryBaseline(text.constraints, TextBaseline.alphabetic)!,
        moreOrLessEquals(40, epsilon: 0.01),
      );
    });

    testWidgets('lays out again when its direction or text size changes', (
      tester,
    ) async {
      var direction = TextDirection.ltr;
      var scale = 1.0;
      late StateSetter update;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: direction,
                child: const MmListTile(
                  title: _long,
                  subtitle: _unit,
                  leading: Icon(MmIcons.property),
                ),
              ),
            );
          },
        ),
      );
      final row = tester.getRect(find.byType(MmListTile));
      expect(tester.getRect(find.byIcon(MmIcons.property)).left, row.left + 16);

      update(() => direction = TextDirection.rtl);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byIcon(MmIcons.property)).right,
        row.right - 16,
      );

      final short = tester.getRect(find.byIcon(MmIcons.property)).top;
      update(() => scale = 2);
      await tester.pumpAndSettle();
      // Now a tall row: the icon moves up to the title's first line.
      expect(
        tester.getRect(find.byIcon(MmIcons.property)).top,
        isNot(moreOrLessEquals(short)),
      );
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
      // An unselected row has no selected state at all: on the web it
      // would add aria-current="false" to every row.
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        matchesSemantics(
          label: '$_name\n$_unit\n45000 rupees',
          isButton: true,
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
        matchesSemantics(label: _name),
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
        isSemantics(hasSelectedState: true, isSelected: true, isButton: true),
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

    testWidgets('sets Latin user data in the Latin face, left to right, in '
        'the Urdu UI', (tester) async {
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
      // The English name keeps its own direction; the Urdu subtitle already
      // runs with the UI.
      expect(find.text('\u2066$_name\u2069'), findsOneWidget);
      expect(find.text('گلبرگ، لاہور'), findsOneWidget);
      // Screen readers get the name as written.
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        matchesSemantics(label: '$_name\nگلبرگ، لاہور'),
      );
    });

    testWidgets('sets Urdu user data in Nastaliq, right to left, in the '
        'English UI', (tester) async {
      const address = 'فلیٹ 3، گلبرگ III، لاہور';
      await pumpThemed(
        tester,
        const MmListTile(title: 'علی رضا', subtitle: address),
      );
      final style = styleOf(tester, 'علی رضا');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFamilyFallback, ['packages/mm_ui/${MmFontFamily.urdu}']);
      expect(find.text('\u2067$address\u2069'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(MmListTile)),
        matchesSemantics(label: 'علی رضا\n$address'),
      );
    });

    testWidgets('an Urdu address in the English UI wraps in its own order', (
      tester,
    ) async {
      const address = 'فلیٹ 3، گلبرگ III، لاہور';
      await pumpThemed(
        tester,
        const SizedBox(
          width: 150,
          child: MmListTile(title: _name, subtitle: address),
        ),
      );
      final paragraph = paragraphOf(tester, address);
      final text = paragraph.text.toPlainText();
      // Each word's line (the top of its caret) and its middle.
      (double, double) placeOf(String word) {
        final start = text.indexOf(word);
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: start,
                extentOffset: start + word.length,
              ),
            )
            .first
            .toRect();
        final line = paragraph
            .getOffsetForCaret(TextPosition(offset: start), Rect.zero)
            .dy;
        return (line, box.center.dx);
      }

      // The address wraps, and each line reads right to left: of two words
      // on one line, the later one is to the left of the earlier one.
      final words = [
        'فلیٹ',
        '3',
        'گلبرگ',
        'III',
        'لاہور',
      ].map(placeOf).toList();
      // Runs in the Latin face and in Nastaliq start a few pixels apart on
      // one line; lines are a whole line height apart.
      bool sameLine(double a, double b) => (a - b).abs() < 10;
      expect(sameLine(words.last.$1, words.first.$1), isFalse);
      var pairs = 0;
      for (var i = 1; i < words.length; i++) {
        if (!sameLine(words[i].$1, words[i - 1].$1)) continue;
        pairs++;
        expect(words[i].$2, lessThan(words[i - 1].$2));
      }
      expect(pairs, greaterThan(1));
    });

    testWidgets('a tappable row holding a control is reported', (tester) async {
      await pumpThemed(
        tester,
        MmListTile(
          title: _name,
          trailing: IconButton(
            tooltip: 'Call',
            onPressed: () {},
            icon: const Icon(MmIcons.phone),
          ),
          onTap: () {},
        ),
      );
      expect(
        (tester.takeException()! as FlutterError).toStringDeep(),
        contains('A tappable MmListTile holds a control.'),
      );
    });
  });
}

void _noop() {}
