import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _add = 'Add tenant';

/// The floating action button under test.
final Finder _fab = find.byType(MmFab);

void main() {
  group('MmFab', () {
    testWidgets('is extended by default, with the shared hero tag', (
      tester,
    ) async {
      const fab = MmFab(label: _add, icon: MmIcons.invite, onPressed: null);
      expect(fab.extended, isTrue);
      const other = MmFab(
        label: 'Add property',
        icon: MmIcons.add,
        onPressed: null,
      );
      expect(fab.heroTag, isNotNull);
      expect(fab.heroTag, other.heroTag);
      expect(fab.heroTag.toString(), '<MmFab hero tag>');
    });

    testWidgets('passes its hero tag to the button, or none', (tester) async {
      for (final tag in ['add tenant', null]) {
        await pumpThemed(
          tester,
          MmFab(
            label: _add,
            icon: MmIcons.invite,
            heroTag: tag,
            onPressed: tapped,
          ),
        );
        expect(
          tester
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .heroTag,
          tag,
        );
        expect(find.byType(Hero), tag == null ? findsNothing : findsOneWidget);
      }
    });

    testWidgets('two on one route move to the next screen with their own '
        'tags', (tester) async {
      Widget screen(String title, {required bool ownTags}) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (ownTags) ...[
                const MmFab(
                  label: _add,
                  icon: MmIcons.invite,
                  heroTag: 'tenant',
                  onPressed: tapped,
                ),
                const MmFab(
                  label: 'Add property',
                  icon: MmIcons.add,
                  extended: false,
                  heroTag: 'property',
                  onPressed: tapped,
                ),
              ] else ...[
                const MmFab(
                  label: _add,
                  icon: MmIcons.invite,
                  onPressed: tapped,
                ),
                const MmFab(
                  label: 'Add property',
                  icon: MmIcons.add,
                  extended: false,
                  onPressed: tapped,
                ),
              ],
            ],
          ),
        ),
      );
      for (final ownTags in [true, false]) {
        await tester.pumpWidget(themedApp(screen('Tenants', ownTags: ownTags)));
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => screen('Gulberg', ownTags: ownTags),
              ),
            );
        await tester.pumpAndSettle();
        // Sharing the default tag, the two heroes collide.
        expect(
          tester.takeException(),
          ownTags ? isNull : isFlutterError,
          reason: 'own tags: $ownTags',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('extended, shows its icon and label, read as one button', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(label: _add, icon: MmIcons.invite, onPressed: tapped),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(MmIcons.invite), findsOneWidget);
      expect(find.text(_add), findsOneWidget);
      final node = tester.getSemantics(find.text(_add));
      expect(
        node,
        matchesSemantics(
          label: _add,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      final size = tester.getSize(find.byType(MmFab));
      expect(size.height, 56);
      expect(size.width, greaterThan(56));
    });

    testWidgets('compact, shows the icon; the label is tooltip and label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(
          label: _add,
          icon: MmIcons.invite,
          extended: false,
          onPressed: tapped,
        ),
      );
      expect(find.text(_add), findsNothing);
      expect(tester.getSize(find.byType(MmFab)), const Size(56, 56));
      final node = tester.getSemantics(find.byIcon(MmIcons.invite));
      expect(
        node,
        matchesSemantics(
          label: _add,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(node.getSemanticsData().tooltip, isEmpty);

      await tester.longPress(find.byType(MmFab));
      await tester.pumpAndSettle();
      expect(find.text(_add), findsOneWidget);
    });

    testWidgets('calls onPressed on tap and from the keyboard', (tester) async {
      for (final extended in [true, false]) {
        var presses = 0;
        await pumpThemed(
          tester,
          MmFab(
            label: _add,
            icon: MmIcons.invite,
            extended: extended,
            onPressed: () => presses++,
          ),
        );
        await tester.tap(find.byType(MmFab));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(presses, 3, reason: 'extended: $extended');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testEveryVariant('enabled, it is cobalt and floats', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(label: _add, icon: MmIcons.invite, onPressed: tapped),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final material = materialOf(tester, _fab);
      expect(material.color, colors.primary);
      expect(material.elevation, greaterThan(0));
      expect(sideOf(tester, _fab), BorderSide(color: colors.primary));
    });

    testWidgets('disabled, it keeps the theme corners with a rule border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(label: _add, icon: MmIcons.invite, onPressed: null),
      );
      final theme =
          WidgetStateProperty.resolveAs<ShapeBorder?>(
                FloatingActionButtonTheme.of(tester.element(_fab)).shape,
                const {WidgetState.disabled},
              )!
              as OutlinedBorder;
      expect(
        materialOf(tester, _fab).shape,
        theme.copyWith(side: BorderSide(color: MmColorModes.light.rule)),
      );

      // Under a theme without a shape of its own, Material's stays.
      await pumpThemed(
        tester,
        const FloatingActionButtonTheme(
          data: FloatingActionButtonThemeData(),
          child: MmFab(label: _add, icon: MmIcons.invite, onPressed: null),
        ),
      );
      final material = materialOf(tester, _fab).shape! as OutlinedBorder;
      expect(material.side, BorderSide.none);
    });

    testEveryVariant('disabled, it is flat, muted and out of reach', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(label: _add, icon: MmIcons.invite, onPressed: null),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final material = materialOf(tester, _fab);
      expect(material.color, colors.surfaceSunken);
      expect(material.elevation, 0);
      expect(sideOf(tester, _fab), BorderSide(color: colors.rule));
      expect(
        tester.getSemantics(find.text(_add)),
        matchesSemantics(label: _add, isButton: true, hasEnabledState: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(sideOf(tester, _fab), BorderSide(color: colors.rule));
    });

    testEveryVariant('a focused button draws the ring outside its fill', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      for (final extended in [true, false]) {
        await pumpThemed(
          tester,
          MmFab(
            label: _add,
            icon: MmIcons.invite,
            extended: extended,
            onPressed: tapped,
          ),
          variant: variant,
        );
        expect(materialOf(tester, _fab).shape, isNot(isA<MmFocusRingBorder>()));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        // The theme's ring, in the focus colour past a gap, so it shows on
        // the cobalt fill; the button keeps its own edge.
        final ring = materialOf(tester, _fab).shape! as MmFocusRingBorder;
        expect(ring.color, colors.focus);
        expect(ring.width, MmSize.focusRing);
        expect(ring.gap, MmSize.focusGap);
        expect(ring.side, BorderSide(color: colors.primary));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(sideOf(tester, _fab), BorderSide(color: colors.primary));
      }
    });

    testWidgets('a long label wraps at 200% text on a 320 dp surface', (
      tester,
    ) async {
      const label = 'Record the October payment for the Gulberg, Lahore flat';
      await pumpThemed(
        tester,
        const MmFab(label: label, icon: MmIcons.payment, onPressed: tapped),
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(MmFab));
      expect(size.width, lessThanOrEqualTo(288));
      expect(size.height, greaterThan(56));
      final text = tester.getRect(find.text(label));
      final fab = tester.getRect(find.byType(MmFab));
      expect(
        fab.contains(text.topLeft) && fab.contains(text.bottomRight),
        true,
      );
    });

    testWidgets('extended, its icon grows with the text, at most 150%', (
      tester,
    ) async {
      for (final (scale, size) in [(1.0, 24.0), (1.25, 30.0), (2.0, 36.0)]) {
        for (final extended in [true, false]) {
          await pumpThemed(
            tester,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: MmFab(
                  label: _add,
                  icon: MmIcons.invite,
                  extended: extended,
                  onPressed: tapped,
                ),
              ),
            ),
          );
          // Compact, it has no words to keep up with.
          expect(
            tester.getSize(find.byIcon(MmIcons.invite)).width,
            extended ? size : MmSize.iconLg,
            reason: 'scale $scale extended $extended',
          );
        }
      }
    });

    testWidgets('a wrapped label stays beside its icon', (tester) async {
      const label = 'Record payment for the Gulberg, Lahore flat';
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          const MmFab(label: label, icon: MmIcons.payment, onPressed: tapped),
          variant: variant,
        );
        final text = paragraphOf(tester, label);
        expect(text.size.height, greaterThan(2 * 19), reason: variant.name);
        final ink = inkOfWords(text).shift(tester.getTopLeft(find.text(label)));
        final icon = tester.getRect(find.byIcon(MmIcons.payment));
        final gap = variant == MmVariant.urdu
            ? icon.left - ink.right
            : ink.left - icon.right;
        // The row's gap, give or take a line's trailing space or a stroke
        // that overhangs its advance.
        expect(
          gap,
          inInclusiveRange(MmSpace.s2, MmSpace.s3 + 6),
          reason: variant.name,
        );
      }
    });

    testWidgets('the icon leads the label, on the right in Urdu', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        final label = variant == MmVariant.urdu ? 'کرایہ دار شامل کریں' : _add;
        await pumpThemed(
          tester,
          MmFab(label: label, icon: MmIcons.invite, onPressed: tapped),
          variant: variant,
        );
        final icon = tester.getCenter(find.byIcon(MmIcons.invite)).dx;
        final text = tester.getCenter(find.text(label)).dx;
        expect(
          variant == MmVariant.urdu ? icon > text : icon < text,
          isTrue,
          reason: variant.name,
        );
      }
    });

    testWidgets('fits 200% text on 320 dp in English and Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: MmSpace.s4,
          children: [
            MmFab(
              label: 'گلبرگ، لاہور والے فلیٹ کی ادائیگی درج کریں',
              icon: MmIcons.payment,
              heroTag: 'payment',
              onPressed: tapped,
            ),
            MmFab(
              label: 'Add a tenant to Gulberg House',
              icon: MmIcons.invite,
              heroTag: 'tenant',
              onPressed: tapped,
            ),
            MmFab(
              label: 'Add property',
              icon: MmIcons.add,
              extended: false,
              heroTag: null,
              onPressed: null,
            ),
          ],
        ),
      );
    });

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          spacing: MmSpace.s4,
          children: [
            MmFab(
              label: 'Add a tenant to Gulberg House',
              icon: MmIcons.invite,
              onPressed: tapped,
            ),
            MmFab(
              label: 'Add property',
              icon: MmIcons.add,
              extended: false,
              onPressed: tapped,
            ),
          ],
        ),
        variant: variant,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      await expectAccessible(tester);
    });
  });
}
