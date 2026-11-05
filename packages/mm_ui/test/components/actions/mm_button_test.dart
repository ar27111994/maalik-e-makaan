import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

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

/// The Material that paints the button found by [button].
Material _material(WidgetTester tester, Finder button) => tester.widget(
  find.descendant(of: button, matching: find.byType(Material)).first,
);

/// The colour [text] is painted in.
Color _textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

/// The colour [icon] is painted in.
Color _iconColor(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

MmColorTokens _colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

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
          MmButton(label: _record, variant: variant, onPressed: () {}),
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
        MmButton(label: _record, onPressed: () {}),
        variant: variant,
      );
      final colors = _colorsOf(variant);
      expect(
        _material(tester, find.byType(FilledButton)).color,
        colors.primary,
      );
      expect(_textColor(tester, _record), colors.onPrimary);
    });

    testEveryVariant(
      'the destructive fill is overdue, its text at 4.5:1 or better',
      (tester, variant) async {
        await pumpThemed(
          tester,
          MmButton(
            label: 'Remove tenant',
            icon: MmIcons.delete,
            variant: MmButtonVariant.destructive,
            onPressed: () {},
          ),
          variant: variant,
        );
        final colors = _colorsOf(variant);
        final fill = _material(tester, find.byType(FilledButton)).color!;
        final text = _textColor(tester, 'Remove tenant');
        expect(fill, colors.overdue);
        expect(text, MmButton.onOverdue(colors));
        expect(_contrast(fill, text), greaterThanOrEqualTo(4.5));
        expect(_iconColor(tester, MmIcons.delete), text);
      },
    );

    test('the destructive text takes whichever role contrasts more', () {
      const light = MmColorModes.light;
      // The surface wins in every shipped mode.
      expect(MmButton.onOverdue(light), light.surface);
      // With a dark surface and light ink, the ink wins.
      final inverted = MmColorTokens(
        bg: light.bg,
        surface: light.ink,
        surfaceSunken: light.surfaceSunken,
        ink: light.surface,
        inkMuted: light.inkMuted,
        outline: light.outline,
        rule: light.rule,
        primary: light.primary,
        onPrimary: light.onPrimary,
        primaryContainer: light.primaryContainer,
        onPrimaryContainer: light.onPrimaryContainer,
        brass: light.brass,
        brassText: light.brassText,
        brassContainer: light.brassContainer,
        onBrassContainer: light.onBrassContainer,
        paid: light.paid,
        paidContainer: light.paidContainer,
        onPaidContainer: light.onPaidContainer,
        overdue: light.overdue,
        overdueContainer: light.overdueContainer,
        onOverdueContainer: light.onOverdueContainer,
        dueSoon: light.dueSoon,
        dueSoonContainer: light.dueSoonContainer,
        onDueSoonContainer: light.onDueSoonContainer,
        credit: light.credit,
        creditContainer: light.creditContainer,
        onCreditContainer: light.onCreditContainer,
        focus: light.focus,
      );
      expect(MmButton.onOverdue(inverted), inverted.ink);
    });

    testWidgets('a disabled destructive button takes the disabled colours', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmButton(
          label: 'Remove tenant',
          variant: MmButtonVariant.destructive,
          onPressed: null,
        ),
      );
      expect(
        _material(tester, find.byType(FilledButton)).color,
        isNot(MmColorModes.light.overdue),
      );
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
      expect(
        Focus.of(tester.element(find.text(_record))).hasPrimaryFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(presses, 3);
    });

    testWidgets('reads as an enabled, focusable button named by its label', (
      tester,
    ) async {
      await pumpThemed(tester, MmButton(label: _record, onPressed: () {}));
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
      expect(Focus.of(tester.element(find.text(_record))).hasFocus, isFalse);
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
        expect(
          Focus.of(tester.element(find.text(_record))).hasPrimaryFocus,
          isTrue,
        );
      });

      testWidgets('keeps its enabled colours', (tester) async {
        for (final variant in MmButtonVariant.values) {
          await pumpThemed(
            tester,
            MmButton(label: _record, variant: variant, onPressed: () {}),
          );
          final button = find.byType(MmButton);
          final idle = _material(tester, button).color;
          final idleText = _textColor(tester, _record);
          await _pumpSpinning(
            tester,
            MmButton(
              label: _record,
              variant: variant,
              busy: true,
              onPressed: () {},
            ),
          );
          expect(_material(tester, button).color, idle, reason: variant.name);
          expect(_textColor(tester, _record), idleText, reason: variant.name);
        }
      });

      testWidgets('shows a spinning ring in place of the icon', (tester) async {
        await _pumpSpinning(
          tester,
          MmButton(
            label: _record,
            icon: MmIcons.payment,
            busy: true,
            onPressed: () {},
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
                onPressed: () {},
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
                onPressed: () {},
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
          MmButton(label: _record, busy: true, onPressed: () {}),
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
        await _pumpSpinning(
          tester,
          MmButton(
            label: label,
            icon: MmIcons.payment,
            busy: true,
            onPressed: () {},
          ),
          variant: variant,
        );
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          matchesSemantics(
            label: '$label, $loading',
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
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: MmButton(label: _record, busy: true, onPressed: () {}),
            ),
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
          MmButton(label: _record, busy: true, onPressed: () {}),
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
        MmButton(label: _record, expand: true, onPressed: () {}),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, 328);
      await pumpThemed(tester, MmButton(label: _record, onPressed: () {}));
      expect(tester.getSize(find.byType(FilledButton)).width, lessThan(328));
    });

    testWidgets('is 48 dp tall', (tester) async {
      for (final variant in MmButtonVariant.values) {
        await pumpThemed(
          tester,
          MmButton(label: _record, variant: variant, onPressed: () {}),
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
            onPressed: () {},
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

    testWidgets('the icon leads the label, on the right in Urdu', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          MmButton(label: _record, icon: MmIcons.payment, onPressed: () {}),
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
      final colors = _colorsOf(variant);
      final rings = {
        // On a filled button, the ring takes the text colour.
        MmButtonVariant.primary: colors.onPrimary,
        MmButtonVariant.destructive: MmButton.onOverdue(colors),
        // The theme draws the others in the focus colour.
        MmButtonVariant.secondary: colors.focus,
        MmButtonVariant.tertiary: colors.focus,
      };
      for (final MapEntry(key: kind, value: ring) in rings.entries) {
        await pumpThemed(
          tester,
          MmButton(label: _record, variant: kind, onPressed: () {}),
          variant: variant,
        );
        final button = find.byType(MmButton);
        final resting =
            (_material(tester, button).shape! as OutlinedBorder).side;
        expect(resting.width, lessThan(MmSize.focusRing), reason: kind.name);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused =
            (_material(tester, button).shape! as OutlinedBorder).side;
        expect(focused.color, ring, reason: kind.name);
        expect(focused.width, MmSize.focusRing, reason: kind.name);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmButton(
              label: 'Record payment from Ali Raza',
              icon: MmIcons.payment,
              expand: true,
              onPressed: () {},
            ),
            MmButton(
              label: 'View the ledger',
              variant: MmButtonVariant.tertiary,
              onPressed: () {},
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
