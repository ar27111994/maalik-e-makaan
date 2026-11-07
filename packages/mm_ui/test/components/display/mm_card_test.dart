import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _name = 'Ali Raza';
const _unit = 'Flat 3, Gulberg III';

Widget _content() => const Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Text(_name), Text(_unit)],
);

void main() {
  group('MmCard', () {
    testEveryVariant('is flat paper with the rule border and md corners', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, MmCard(child: _content()), variant: variant);
      final colors = colorsOf(variant);
      final material = surfaceOf(tester, find.byType(MmCard));
      expect(material.color, colors.surface);
      expect(material.elevation, 0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide(color: colors.rule));
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.md)),
      );
      expect(find.text(_name), findsOneWidget);
    });

    testWidgets('pads its child by 16 dp by default', (tester) async {
      await pumpThemed(
        tester,
        const MmCard(child: SizedBox.square(dimension: 10)),
      );
      const card = MmCard(child: SizedBox());
      expect(card.padding, const EdgeInsetsDirectional.all(MmSpace.s4));
      final outer = tester.getRect(find.byType(MmCard));
      final inner = tester.getRect(find.byType(SizedBox).last);
      expect(inner.left - outer.left, MmSpace.s4);
      expect(inner.top - outer.top, MmSpace.s4);
      expect(outer.size, const Size.square(10 + 2 * MmSpace.s4));
    });

    testWidgets('pads from the start edge, mirrored right to left', (
      tester,
    ) async {
      const card = MmCard(
        padding: EdgeInsetsDirectional.only(start: 24),
        child: SizedBox.square(dimension: 10),
      );
      await pumpThemed(tester, card);
      var outer = tester.getRect(find.byType(MmCard));
      var inner = tester.getRect(find.byType(SizedBox).last);
      expect(inner.left - outer.left, 24);

      await pumpThemed(tester, card, variant: MmVariant.urdu);
      outer = tester.getRect(find.byType(MmCard));
      inner = tester.getRect(find.byType(SizedBox).last);
      expect(outer.right - inner.right, 24);
    });

    testWidgets('a static card is not a button and takes no focus', (
      tester,
    ) async {
      await pumpThemed(tester, MmCard(child: _content()));
      expect(
        tester.getSemantics(find.text(_name)),
        isNot(isSemantics(isButton: true)),
      );
      expect(
        tester.getSemantics(find.text(_name)),
        isNot(isSemantics(hasTapAction: true)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _name), isFalse);
      // Its text is read together, as one group.
      expect(
        tester.getSemantics(find.byType(MmCard)),
        matchesSemantics(label: '$_name\n$_unit'),
      );
    });

    testWidgets("a static card's controls stay separate", (tester) async {
      await pumpThemed(
        tester,
        MmCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(_name),
              TextButton(onPressed: () {}, child: const Text('Call')),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmCard)),
        isSemantics(label: _name, isButton: false),
      );
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: 'Call', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('a tappable card is one button reading its contents', (
      tester,
    ) async {
      await pumpThemed(tester, MmCard(onTap: () {}, child: _content()));
      expect(
        tester.getSemantics(find.byType(MmCard)),
        matchesSemantics(
          label: '$_name\n$_unit',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('calls onTap on tap and from the keyboard', (tester) async {
      var taps = 0;
      await pumpThemed(tester, MmCard(onTap: () => taps++, child: _content()));
      await tester.tap(find.byType(MmCard));
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _name), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 3);
    });

    testEveryVariant('draws the focus ring only for keyboard focus', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      final card = find.byType(MmCard);
      await pumpThemed(
        tester,
        MmCard(onTap: () {}, child: _content()),
        variant: variant,
      );
      expect(sideOf(tester, card), BorderSide(color: colors.outline));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        sideOf(tester, card),
        BorderSide(color: colors.focus, width: MmSize.focusRing),
      );

      // A touch switches to touch highlights: the card keeps its focus but
      // the ring goes.
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _name), isTrue);
      expect(sideOf(tester, card), BorderSide(color: colors.outline));

      // Back to the keyboard, the ring returns.
      await tester.sendKeyEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(sideOf(tester, card).color, colors.focus);
    });

    testWidgets('loses the ring when it stops being tappable', (tester) async {
      useKeyboardHighlights();
      final card = find.byType(MmCard);
      var tappable = true;
      late StateSetter update;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MmCard(onTap: tappable ? () {} : null, child: _content());
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(sideOf(tester, card).width, MmSize.focusRing);

      update(() => tappable = false);
      await tester.pumpAndSettle();
      expect(sideOf(tester, card), BorderSide(color: MmColorModes.light.rule));
      expect(focusedAt(tester, _name), isFalse);
    });

    testWidgets('animates the ring quickly, or not at all in reduced motion', (
      tester,
    ) async {
      await pumpThemed(tester, MmCard(onTap: () {}, child: _content()));
      expect(
        surfaceOf(tester, find.byType(MmCard)).animationDuration,
        MmDuration.quick,
      );
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: MmCard(onTap: () {}, child: _content()),
          ),
        ),
      );
      expect(
        surfaceOf(tester, find.byType(MmCard)).animationDuration,
        Duration.zero,
      );
    });

    testWidgets('a semantic label replaces the contents', (tester) async {
      const label = 'Ali Raza, Flat 3, Rs 45,000 due';
      await pumpThemed(
        tester,
        MmCard(onTap: () {}, semanticLabel: label, child: _content()),
      );
      expect(
        tester.getSemantics(find.byType(MmCard)),
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      await pumpThemed(tester, MmCard(semanticLabel: label, child: _content()));
      expect(
        tester.getSemantics(find.byType(MmCard)),
        matchesSemantics(label: label),
      );
      expect(find.bySemanticsLabel(_name), findsNothing);
    });

    testWidgets('throws when nested in another card', (tester) async {
      await pumpThemed(tester, const MmCard(child: MmCard(child: Text(_name))));
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      final message = (error as FlutterError).toStringDeep();
      expect(message, contains('An MmCard was placed inside another MmCard.'));
      expect(message, contains('Cards never nest'));
      expect(message, contains('The nested MmCard was'));
    });

    testWidgets('allows cards one after the other, and stat tiles inside', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmCard(child: Text(_name)),
            MmCard(
              child: MmStatTile(label: 'Collected', value: Text('Rs 95,000')),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MmCard), findsNWidgets(2));
      // Inside the card the tile is a region of it, without a border of its
      // own, so it does not read as a card inside a card.
      expect(sideOf(tester, find.byType(MmStatTile)), BorderSide.none);
    });

    testWidgets('a tappable card holding a control is reported', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmCard(
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(_name),
              TextButton(onPressed: () {}, child: const Text('Remind')),
            ],
          ),
        ),
      );
      expect(
        (tester.takeException()! as FlutterError).toStringDeep(),
        contains('A tappable MmCard holds a control.'),
      );
    });

    testWidgets('rebuilds with new content', (tester) async {
      await pumpThemed(tester, const MmCard(child: Text(_name)));
      await pumpThemed(tester, const MmCard(child: Text(_unit)));
      expect(find.text(_unit), findsOneWidget);
      expect(find.text(_name), findsNothing);
    });

    testWidgets('fits 200% text on a 320 dp phone, in whole words', (
      tester,
    ) async {
      await expectWholeAtLargeText(
        tester,
        MmCard(
          onTap: () {},
          child: const Text(
            'Ayesha Khan, House 12, DHA Phase 5, Lahore: rent of Rs 1,25,000 '
            'due on 5 November',
          ),
        ),
        then: (_) => expect(tester.getSize(find.byType(MmCard)).width, 288),
      );
    });
  });
}
