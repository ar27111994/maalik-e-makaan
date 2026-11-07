import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _record = 'Record payment';

/// Pumps [child] without waiting for animations to settle: a busy button's
/// ring spins for as long as it is shown.
Future<void> _pumpSpinning(
  WidgetTester tester,
  Widget child, {
  MmVariant variant = MmVariant.light,
}) async {
  tester.view
    ..physicalSize = const Size(360, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themed(child, variant: variant));
  await tester.pump();
}

void main() {
  group('MmButton', () {
    testWidgets('each variant is the matching Material button', (tester) async {
      final expected = {
        MmButtonVariant.primary: FilledButton,
        MmButtonVariant.secondary: OutlinedButton,
        MmButtonVariant.tertiary: TextButton,
        MmButtonVariant.destructive: FilledButton,
      };
      for (final MapEntry(key: variant, value: type) in expected.entries) {
        await pumpThemed(
          tester,
          MmButton(label: _record, variant: variant, onPressed: tapped),
        );
        expect(find.byType(type), findsOneWidget, reason: variant.name);
        expect(find.text(_record), findsOneWidget);
      }
    });

    testWidgets('defaults to the primary variant, without icon or busy', (
      tester,
    ) async {
      const button = MmButton(label: _record, onPressed: null);
      expect(button.variant, MmButtonVariant.primary);
      expect(button.icon, isNull);
      expect(button.busy, isFalse);
      expect(button.expand, isFalse);
    });

    testEveryVariant('the primary fill is cobalt with its on-colour text', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmButton(label: _record, onPressed: tapped),
        variant: variant,
      );
      final colors = colorsOf(variant);
      expect(
        materialOf(tester, find.byType(FilledButton)).color,
        colors.primary,
      );
      expect(textColorOf(tester, _record), colors.onPrimary);
    });

    testEveryVariant(
      'the destructive fill is overdue, its text at 4.5:1 or better',
      (tester, variant) async {
        await pumpThemed(
          tester,
          const MmButton(
            label: 'Remove tenant',
            icon: MmIcons.delete,
            variant: MmButtonVariant.destructive,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final colors = colorsOf(variant);
        final fill = materialOf(tester, find.byType(FilledButton)).color!;
        final text = textColorOf(tester, 'Remove tenant');
        expect(fill, colors.overdue);
        // The theme's on-error colour: the surface role.
        expect(text, colors.surface);
        expect(mmContrastRatio(fill, text), greaterThanOrEqualTo(4.5));
        expect(iconColorOf(tester, MmIcons.delete), text);
      },
    );

    testEveryVariant('disabled, it is muted ink; filled ones on sunken paper', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      // (fill, edge) of each variant while disabled; a null fill is none.
      final expected = <MmButtonVariant, (Color?, BorderSide)>{
        MmButtonVariant.primary: (
          colors.surfaceSunken,
          BorderSide(color: colors.rule),
        ),
        MmButtonVariant.destructive: (
          colors.surfaceSunken,
          BorderSide(color: colors.rule),
        ),
        MmButtonVariant.secondary: (null, BorderSide(color: colors.rule)),
        // No edge: the theme's none, in the rule colour.
        MmButtonVariant.tertiary: (
          null,
          BorderSide.none.copyWith(color: colors.rule),
        ),
      };
      for (final MapEntry(key: kind, value: (fill, edge)) in expected.entries) {
        await pumpThemed(
          tester,
          MmButton(
            label: 'Remove tenant',
            icon: MmIcons.delete,
            variant: kind,
            onPressed: null,
          ),
          variant: variant,
        );
        final button = find.byType(MmButton);
        final material = materialOf(tester, button);
        if (fill == null) {
          expect(material.color?.a ?? 0, 0, reason: kind.name);
        } else {
          expect(material.color, fill, reason: kind.name);
        }
        expect(sideOf(tester, button), edge, reason: kind.name);
        expect(textColorOf(tester, 'Remove tenant'), colors.inkMuted);
        expect(iconColorOf(tester, MmIcons.delete), colors.inkMuted);
      }
    });

    testWidgets('calls onPressed on tap and from the keyboard', (tester) async {
      var presses = 0;
      await pumpThemed(
        tester,
        MmButton(label: _record, onPressed: () => presses++),
      );
      await tester.tap(find.byType(MmButton));
      expect(presses, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _record), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(presses, 3);
    });

    testWidgets('reads as an enabled, focusable button named by its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmButton(label: _record, onPressed: tapped),
      );
      expect(
        tester.getSemantics(find.text(_record)),
        matchesSemantics(
          label: _record,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('a null onPressed disables it', (tester) async {
      await pumpThemed(
        tester,
        const MmButton(
          label: _record,
          variant: MmButtonVariant.secondary,
          onPressed: null,
        ),
      );
      expect(
        tester.getSemantics(find.text(_record)),
        matchesSemantics(label: _record, isButton: true, hasEnabledState: true),
      );
      // Not focusable: Tab finds nothing to focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _record), isFalse);
    });

    group('busy', () {
      testWidgets('ignores presses and keyboard activation, keeping focus', (
        tester,
      ) async {
        var presses = 0;
        var busy = false;
        await _pumpSpinning(
          tester,
          StatefulBuilder(
            builder: (context, setState) => MmButton(
              label: _record,
              icon: MmIcons.payment,
              busy: busy,
              onPressed: () => setState(() {
                presses++;
                busy = true;
              }),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(presses, 1);
        expect(busy, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.tap(find.byType(MmButton));
        await tester.pump();
        expect(presses, 1);
        expect(focusedAt(tester, _record), isTrue);
      });

      testWidgets('keeps its enabled colours', (tester) async {
        for (final variant in MmButtonVariant.values) {
          await pumpThemed(
            tester,
            MmButton(label: _record, variant: variant, onPressed: tapped),
          );
          final button = find.byType(MmButton);
          final idle = materialOf(tester, button).color;
          final idleText = textColorOf(tester, _record);
          await _pumpSpinning(
            tester,
            MmButton(
              label: _record,
              variant: variant,
              busy: true,
              onPressed: tapped,
            ),
          );
          expect(materialOf(tester, button).color, idle, reason: variant.name);
          expect(textColorOf(tester, _record), idleText, reason: variant.name);
        }
      });

      testWidgets('shows a spinning ring in place of the icon', (tester) async {
        await _pumpSpinning(
          tester,
          const MmButton(
            label: _record,
            icon: MmIcons.payment,
            busy: true,
            onPressed: tapped,
          ),
        );
        expect(find.byIcon(MmIcons.payment), findsNothing);
        final ring = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(ring.value, isNull);
        expect(ring.color, MmColorModes.light.onPrimary);
        expect(find.text(_record), findsOneWidget);
        final ringBox = tester.getRect(find.byType(CircularProgressIndicator));
        expect(
          ringBox.right,
          lessThan(tester.getRect(find.text(_record)).left),
        );
      });

      testWidgets('keeps its width, with and without an icon', (tester) async {
        for (final icon in [MmIcons.payment, null]) {
          for (final variant in MmButtonVariant.values) {
            await pumpThemed(
              tester,
              MmButton(
                label: _record,
                icon: icon,
                variant: variant,
                onPressed: tapped,
              ),
            );
            final idle = tester.getSize(find.byType(MmButton));
            await _pumpSpinning(
              tester,
              MmButton(
                label: _record,
                icon: icon,
                variant: variant,
                busy: true,
                onPressed: tapped,
              ),
            );
            expect(
              tester.getSize(find.byType(MmButton)),
              idle,
              reason: '${variant.name} icon: ${icon != null}',
            );
          }
        }
      });

      testWidgets("without an icon, the ring takes the label's place", (
        tester,
      ) async {
        await _pumpSpinning(
          tester,
          const MmButton(label: _record, busy: true, onPressed: tapped),
        );
        final ring = tester.getCenter(find.byType(CircularProgressIndicator));
        expect(ring, tester.getCenter(find.byType(MmButton)));
        final hidden = tester.widget<Visibility>(
          find.ancestor(
            of: find.text(_record),
            matching: find.byType(Visibility),
          ),
        );
        expect(hidden.visible, isFalse);
        expect(hidden.maintainSize, isTrue);
      });

      testEveryVariant('is announced as loading', (tester, variant) async {
        final urdu = variant == MmVariant.urdu;
        final label = urdu ? 'ادائیگی درج کریں' : _record;
        final loading = urdu
            ? MmLocalizations.urdu.loading
            : MmLocalizations.english.loading;
        // Joined by the comma of the language: "،" in Urdu.
        final comma = urdu ? '،' : ',';
        await _pumpSpinning(
          tester,
          MmButton(
            label: label,
            icon: MmIcons.payment,
            busy: true,
            onPressed: tapped,
          ),
          variant: variant,
        );
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          matchesSemantics(
            label: '$label$comma $loading',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      });

      testWidgets('stands still when the platform reduces motion', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          withoutAnimations(
            const MmButton(label: _record, busy: true, onPressed: tapped),
          ),
        );
        final ring = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(ring.value, isNotNull);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('and disabled, shows the ring in the disabled colours', (
        tester,
      ) async {
        await _pumpSpinning(
          tester,
          const MmButton(label: _record, busy: true, onPressed: null),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          matchesSemantics(
            label: '$_record, ${MmLocalizations.english.loading}',
            isButton: true,
            hasEnabledState: true,
          ),
        );
      });

      testWidgets('shows the progress cursor and no press feedback', (
        tester,
      ) async {
        await _pumpSpinning(
          tester,
          const MmButton(label: _record, busy: true, onPressed: tapped),
        );
        final style = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!;
        expect(style.mouseCursor!.resolve({}), SystemMouseCursors.progress);
        expect(
          style.overlayColor!.resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        expect(style.splashFactory, NoSplash.splashFactory);
        expect(style.enableFeedback, isFalse);
      });
    });

    testWidgets('expand fills the width; otherwise it hugs its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmButton(label: _record, expand: true, onPressed: tapped),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, 328);
      await pumpThemed(
        tester,
        const MmButton(label: _record, onPressed: tapped),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, lessThan(328));
    });

    testWidgets('is 48 dp tall', (tester) async {
      for (final variant in MmButtonVariant.values) {
        await pumpThemed(
          tester,
          MmButton(label: _record, variant: variant, onPressed: tapped),
        );
        expect(tester.getSize(find.byType(MmButton)).height, 48);
      }
    });

    testWidgets('wraps a long label at 200% text on a 320 dp surface', (
      tester,
    ) async {
      const label = 'Send the October rent reminder to Ayesha Khan in Gulberg';
      for (final variant in MmButtonVariant.values) {
        await pumpThemed(
          tester,
          MmButton(
            label: label,
            icon: MmIcons.reminder,
            variant: variant,
            onPressed: tapped,
          ),
          variant: MmVariant.largeText,
          size: const Size(320, 740),
        );
        expect(tester.takeException(), isNull);
        final button = tester.getSize(find.byType(MmButton));
        expect(button.width, lessThanOrEqualTo(288));
        expect(button.height, greaterThan(96), reason: variant.name);
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        expect(text.didExceedMaxLines, isFalse);
        expect(text.size.height, greaterThan(2 * 28));
      }
    });

    testWidgets('its icon and busy ring grow with the text, at most 150%', (
      tester,
    ) async {
      for (final (scale, size) in [(1.0, 20.0), (1.25, 25.0), (2.0, 30.0)]) {
        Widget scaled(Widget child) => Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        );
        await pumpThemed(
          tester,
          scaled(
            const MmButton(
              label: _record,
              icon: MmIcons.payment,
              onPressed: tapped,
            ),
          ),
        );
        expect(tester.getSize(find.byIcon(MmIcons.payment)).width, size);
        await _pumpSpinning(
          tester,
          scaled(
            const MmButton(
              label: _record,
              icon: MmIcons.payment,
              busy: true,
              onPressed: tapped,
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(CircularProgressIndicator)).width,
          size - 2 * MmSpace.sHalf,
        );
      }
    });

    testWidgets('a wrapped label stays beside its icon', (tester) async {
      const label = 'Send the October rent reminder to Ayesha Khan';
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          const MmButton(
            label: label,
            icon: MmIcons.reminder,
            variant: MmButtonVariant.secondary,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final text = paragraphOf(tester, label);
        expect(text.size.height, greaterThan(2 * 19), reason: variant.name);
        // As wide as its longest line, so the words start (or, in Urdu,
        // end) the row's gap away from the icon: not the half of the spare
        // width that centring the lines across the whole button would add.
        final ink = text
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: label.length),
            )
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b))
            .shift(tester.getTopLeft(find.text(label)));
        final icon = tester.getRect(find.byIcon(MmIcons.reminder));
        final gap = variant == MmVariant.urdu
            ? icon.left - ink.right
            : ink.left - icon.right;
        // The row's gap, give or take a line's trailing space or a
        // Nastaliq stroke that overhangs its advance (centred across the
        // whole button instead, the lines started 30 dp from the icon).
        expect(
          gap,
          inInclusiveRange(MmSpace.s1, MmSpace.s2 + 6),
          reason: variant.name,
        );
      }
    });

    testWidgets('the icon leads the label, on the right in Urdu', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          const MmButton(
            label: _record,
            icon: MmIcons.payment,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final icon = tester.getCenter(find.byIcon(MmIcons.payment)).dx;
        final text = tester.getCenter(find.text(_record)).dx;
        expect(
          variant == MmVariant.urdu ? icon > text : icon < text,
          isTrue,
          reason: variant.name,
        );
      }
    });

    testEveryVariant('a focused button shows a ring', (tester, variant) async {
      final colors = colorsOf(variant);
      for (final kind in MmButtonVariant.values) {
        await pumpThemed(
          tester,
          MmButton(label: _record, variant: kind, onPressed: tapped),
          variant: variant,
        );
        final button = find.byType(MmButton);
        final resting = materialOf(tester, button).shape! as OutlinedBorder;
        expect(resting, isNot(isA<MmFocusRingBorder>()), reason: kind.name);
        expect(resting.side.width, lessThan(MmSize.focusRing));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = materialOf(tester, button).shape!;
        switch (kind) {
          // A filled button keeps its fill and edge; the theme draws the
          // ring outside it, past a gap, so it shows on any fill.
          case MmButtonVariant.primary || MmButtonVariant.destructive:
            expect(focused, isA<MmFocusRingBorder>(), reason: kind.name);
            final ring = focused as MmFocusRingBorder;
            expect(ring.color, colors.focus);
            expect(ring.width, MmSize.focusRing);
            expect(ring.gap, MmSize.focusGap);
          // The others draw the ring on their edge.
          case MmButtonVariant.secondary || MmButtonVariant.tertiary:
            final side = (focused as OutlinedBorder).side;
            expect(side.color, colors.focus, reason: kind.name);
            expect(side.width, MmSize.focusRing, reason: kind.name);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('fits 200% text on 320 dp in English and Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Column(
          children: [
            for (final kind in MmButtonVariant.values)
              MmButton(
                label: 'عائشہ خان کو اکتوبر کے کرایے کی یاد دہانی بھیجیں',
                icon: MmIcons.reminder,
                variant: kind,
                expand: kind == MmButtonVariant.primary,
                onPressed: tapped,
              ),
            const MmButton(
              label: 'Record payment from Ali Raza',
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
          children: [
            MmButton(
              label: 'Record payment from Ali Raza',
              icon: MmIcons.payment,
              expand: true,
              onPressed: tapped,
            ),
            MmButton(
              label: 'View the ledger',
              variant: MmButtonVariant.tertiary,
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
