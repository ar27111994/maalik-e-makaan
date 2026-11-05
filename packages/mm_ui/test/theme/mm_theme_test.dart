import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

void main() {
  group('MmTheme.data', () {
    for (final variant in MmVariant.values) {
      test('maps the token roles for ${variant.name}', () {
        final theme = variant.theme;
        final colors = MmTheme.tokensFor(
          variant.brightness,
          highContrast: variant.highContrast,
        );
        final scheme = theme.colorScheme;
        expect(theme.brightness, variant.brightness);
        expect(scheme.primary, colors.primary);
        expect(scheme.onPrimary, colors.onPrimary);
        expect(scheme.surface, colors.surface);
        expect(scheme.onSurface, colors.ink);
        expect(scheme.onSurfaceVariant, colors.inkMuted);
        expect(scheme.error, colors.overdue);
        expect(scheme.outline, colors.outline);
        expect(scheme.outlineVariant, colors.rule);
        expect(theme.scaffoldBackgroundColor, colors.bg);
        // Brass stays out of the Material scheme on purpose.
        expect(scheme.secondaryContainer, colors.primaryContainer);
        expect(scheme.surfaceTint, Colors.transparent);
        expect(theme.extension<MmSemantics>()!.colors, colors);
        expect(
          theme.extension<MmSemantics>()!.highContrast,
          variant.highContrast,
        );
      });
    }

    test('the inverse roles come from the opposite mode', () {
      final light = MmTheme.data(brightness: Brightness.light).colorScheme;
      expect(light.inverseSurface, MmColorModes.dark.surface);
      expect(light.onInverseSurface, MmColorModes.dark.ink);
      expect(light.inversePrimary, MmColorModes.dark.primary);
      final dark = MmTheme.data(brightness: Brightness.dark).colorScheme;
      expect(dark.inverseSurface, MmColorModes.light.surface);
    });

    test('text is set in the script of the language', () {
      final latin = MmTheme.data(brightness: Brightness.light).textTheme;
      final urdu = MmTheme.data(
        brightness: Brightness.light,
        script: MmScript.urdu,
      ).textTheme;
      expect(latin.bodyLarge!.fontFamily, contains('AtkinsonHyperlegibleNext'));
      expect(urdu.bodyLarge!.fontFamily, contains('NotoNastaliqUrdu'));
      // Nastaliq needs about twice the line height of Latin.
      expect(urdu.bodyLarge!.height, greaterThanOrEqualTo(1.9));
      expect(latin.bodyLarge!.height, closeTo(1.5, 0.01));
      // Amounts stay Latin with tabular figures in both languages.
      final semantics = MmTheme.data(
        brightness: Brightness.light,
        script: MmScript.urdu,
      ).extension<MmSemantics>()!;
      expect(semantics.amount.fontFamily, contains('AtkinsonHyperlegibleNext'));
      expect(
        semantics.amountLarge.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('the Latin face falls back to Nastaliq for Urdu letters', () {
      const nastaliq = ['packages/mm_ui/NotoNastaliqUrdu'];
      for (final script in MmScript.values) {
        final theme = MmTheme.data(
          brightness: Brightness.light,
          script: script,
        );
        final semantics = theme.extension<MmSemantics>()!;
        // Amounts are Latin in both languages, and the Urdu currency word
        // follows them.
        for (final amount in [semantics.amount, semantics.amountLarge]) {
          expect(amount.fontFamilyFallback, nastaliq);
          expect(amount.fontFamily, 'packages/mm_ui/AtkinsonHyperlegibleNext');
        }
        expect(theme.textTheme.displayLarge!.fontFamilyFallback, nastaliq);
      }
      final english = MmTheme.data(brightness: Brightness.light).textTheme;
      for (final style in [
        english.headlineLarge,
        english.titleLarge,
        english.bodyLarge,
        english.bodyMedium,
        english.labelLarge,
        english.labelSmall,
      ]) {
        expect(style!.fontFamilyFallback, nastaliq);
      }
      final urdu = MmTheme.data(
        brightness: Brightness.light,
        script: MmScript.urdu,
      ).textTheme;
      expect(urdu.bodyLarge!.fontFamilyFallback, isNull);
    });

    test('withUrduFallback needs one of the package faces', () {
      expect(
        MmSemantics.withUrduFallback(MmTypeScale.latinBody).fontFamilyFallback,
        ['packages/mm_ui/NotoNastaliqUrdu'],
      );
      expect(
        () => MmSemantics.withUrduFallback(const TextStyle()),
        throwsAssertionError,
      );
    });

    test('no text style is smaller than 12 px', () {
      for (final script in MmScript.values) {
        final text = MmTheme.textTheme(script, MmColorModes.light);
        for (final style in [
          text.displayLarge,
          text.headlineLarge,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
          text.bodyLarge,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          text.labelSmall,
        ]) {
          expect(style!.fontSize, greaterThanOrEqualTo(12));
        }
      }
    });

    test('outlined and text buttons draw the focus ring on their edge', () {
      const colors = MmColorModes.light;
      final theme = MmTheme.data(brightness: Brightness.light);
      final ring = BorderSide(color: colors.focus, width: MmSize.focusRing);
      final outlined = theme.outlinedButtonTheme.style!;
      expect(outlined.side!.resolve({WidgetState.focused}), ring);
      expect(outlined.side!.resolve({})!.color, colors.outline);
      expect(
        outlined.side!.resolve({WidgetState.disabled})!.color,
        colors.rule,
      );
      final text = theme.textButtonTheme.style!;
      expect(text.side!.resolve({WidgetState.focused}), ring);
      expect(text.side!.resolve({}), BorderSide.none);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        MmSize.buttonHeight,
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    for (final variant in MmVariant.values) {
      test('filled styles ring focus outside the fill (${variant.name})', () {
        final theme = variant.theme;
        final colors = theme.extension<MmSemantics>()!.colors;
        for (final (name, style) in [
          ('filled', theme.filledButtonTheme.style!),
          ('elevated', theme.elevatedButtonTheme.style!),
          ('icon', theme.iconButtonTheme.style!),
        ]) {
          final resting = style.shape!.resolve({})!;
          expect(resting, isNot(isA<MmFocusRingBorder>()), reason: name);
          final focused = style.shape!.resolve({WidgetState.focused})!;
          expect(focused, isA<MmFocusRingBorder>(), reason: name);
          focused as MmFocusRingBorder;
          expect(focused.shape, resting, reason: name);
          expect(focused.color, colors.focus, reason: name);
          expect(focused.width, MmSize.focusRing, reason: name);
          expect(focused.gap, MmSize.focusGap, reason: name);
        }
        // No edge ring on a filled button: it would be the fill's colour.
        final side = theme.filledButtonTheme.style!.side!;
        expect(side.resolve({WidgetState.focused}), BorderSide.none);
        expect(side.resolve({}), BorderSide.none);
        // Icon buttons leave the side to their variant (outlined keeps its
        // outline).
        expect(theme.iconButtonTheme.style!.side, isNull);
        final fab = theme.floatingActionButtonTheme.shape!;
        fab as WidgetStateOutlinedBorder;
        final fabFocused = fab.resolve({WidgetState.focused})!;
        expect(fabFocused, isA<MmFocusRingBorder>());
        expect((fabFocused as MmFocusRingBorder).color, colors.focus);
        expect(fab.resolve({})!.side.color, colors.primary);
      });
    }

    test('disabled buttons are muted ink; filled ones on sunken paper', () {
      const colors = MmColorModes.light;
      final theme = MmTheme.data(brightness: Brightness.light);
      const disabled = {WidgetState.disabled};
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
      ]) {
        expect(style.backgroundColor!.resolve(disabled), colors.surfaceSunken);
        expect(style.foregroundColor!.resolve(disabled), colors.inkMuted);
        expect(style.iconColor!.resolve(disabled), colors.inkMuted);
        expect(style.side!.resolve(disabled), BorderSide(color: colors.rule));
      }
      for (final style in [
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(style.foregroundColor!.resolve(disabled), colors.inkMuted);
        expect(style.iconColor!.resolve(disabled), colors.inkMuted);
      }
    });

    test('button colours follow their state', () {
      const colors = MmColorModes.light;
      final theme = MmTheme.data(brightness: Brightness.light);
      final elevated = theme.elevatedButtonTheme.style!;
      expect(elevated.backgroundColor!.resolve({}), colors.primary);
      expect(elevated.foregroundColor!.resolve({}), colors.onPrimary);
      expect(elevated.iconColor!.resolve({}), colors.onPrimary);
      // Enabled filled and text buttons keep their kind's own colours.
      final filled = theme.filledButtonTheme.style!;
      expect(filled.backgroundColor!.resolve({}), isNull);
      expect(filled.foregroundColor!.resolve({}), isNull);
      expect(theme.textButtonTheme.style!.foregroundColor!.resolve({}), isNull);
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        colors.primary,
      );
      final fab = theme.floatingActionButtonTheme;
      expect(fab.focusColor, colors.onPrimary.withValues(alpha: 0.1));
      expect(fab.hoverColor, colors.onPrimary.withValues(alpha: 0.08));
      expect(fab.splashColor, colors.onPrimary.withValues(alpha: 0.1));
    });

    test('segmented buttons look like MmSegmentedControl', () {
      const colors = MmColorModes.light;
      final theme = MmTheme.data(brightness: Brightness.light);
      final segmented = theme.segmentedButtonTheme;
      expect((segmented.selectedIcon! as Icon).icon, MmIcons.check);
      final style = segmented.style!;
      const selected = {WidgetState.selected};
      expect(style.backgroundColor!.resolve(selected), colors.primaryContainer);
      expect(style.backgroundColor!.resolve({}), colors.surface);
      expect(
        style.backgroundColor!.resolve({...selected, WidgetState.disabled}),
        colors.surfaceSunken,
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        colors.surface,
      );
      expect(
        style.foregroundColor!.resolve(selected),
        colors.onPrimaryContainer,
      );
      expect(style.foregroundColor!.resolve({}), colors.ink);
      expect(style.iconColor!.resolve({WidgetState.disabled}), colors.inkMuted);
      expect(style.side!.resolve({})!.color, colors.outline);
      expect(
        style.side!.resolve({WidgetState.focused}),
        BorderSide(color: colors.focus, width: MmSize.focusRing),
      );
      expect(style.side!.resolve({WidgetState.disabled})!.color, colors.rule);
      expect(style.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(style.iconSize!.resolve({}), MmSize.iconMd);
    });

    test('chips are framed in muted ink, cobalt when selected', () {
      const colors = MmColorModes.light;
      final side =
          MmTheme.data(brightness: Brightness.light).chipTheme.side!
              as WidgetStateBorderSide;
      expect(side.resolve({})!.color, colors.inkMuted);
      expect(side.resolve({WidgetState.selected})!.color, colors.primary);
      expect(
        side.resolve({WidgetState.focused}),
        BorderSide(color: colors.focus, width: MmSize.focusRing),
      );
      expect(side.resolve({WidgetState.disabled})!.color, colors.rule);
    });

    test('badges count in the Latin face with tabular figures', () {
      for (final script in MmScript.values) {
        final theme = MmTheme.data(
          brightness: Brightness.light,
          script: script,
        );
        final badge = theme.badgeTheme;
        expect(badge.textStyle!.fontFamily, contains('AtkinsonHyperlegible'));
        expect(badge.textStyle!.fontSize, MmTypeScale.latinCaption.fontSize);
        expect(badge.textStyle!.fontWeight, FontWeight.w600);
        expect(
          badge.textStyle!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(badge.backgroundColor, MmColorModes.light.overdue);
        expect(badge.textColor, theme.colorScheme.onError);
      }
    });

    test('tabs mark the selected one in cobalt over a hairline rule', () {
      const colors = MmColorModes.light;
      final theme = MmTheme.data(brightness: Brightness.light);
      final tabs = theme.tabBarTheme;
      expect(tabs.labelColor, colors.primary);
      expect(tabs.unselectedLabelColor, colors.inkMuted);
      final label = MmTheme.textTheme(MmScript.latin, colors).labelLarge;
      expect(tabs.labelStyle, label);
      expect(tabs.unselectedLabelStyle, label);
      final indicator = tabs.indicator! as UnderlineTabIndicator;
      expect(
        indicator.borderSide,
        BorderSide(color: colors.primary, width: MmSize.tabIndicator),
      );
      expect(tabs.indicatorSize, TabBarIndicatorSize.label);
      expect(tabs.dividerColor, colors.rule);
      expect(tabs.dividerHeight, MmSize.hairline);
    });

    test('the navigation bar marks the selected destination', () {
      const colors = MmColorModes.light;
      final bar = MmTheme.data(brightness: Brightness.light).navigationBarTheme;
      expect(
        bar.labelTextStyle!.resolve({WidgetState.selected})!.color,
        colors.ink,
      );
      expect(bar.labelTextStyle!.resolve({})!.color, colors.inkMuted);
      final selected = bar.iconTheme!.resolve({WidgetState.selected})!;
      expect(selected.color, colors.onPrimaryContainer);
      expect(selected.size, MmSize.iconLg);
      expect(bar.iconTheme!.resolve({})!.color, colors.inkMuted);
    });
  });

  group('MmScript', () {
    test('follows the language', () {
      expect(MmScript.of(const Locale('ur')), MmScript.urdu);
      expect(MmScript.of(const Locale('ur', 'PK')), MmScript.urdu);
      expect(MmScript.of(const Locale('en')), MmScript.latin);
    });
  });

  group('MmSemantics', () {
    test('copyWith and lerp', () {
      final light = MmTheme.data(brightness: Brightness.light)
          .extension<MmSemantics>()!;
      final dark = MmTheme.data(
        brightness: Brightness.dark,
        script: MmScript.urdu,
        highContrast: true,
      ).extension<MmSemantics>()!;
      expect(light.copyWith(highContrast: true).highContrast, isTrue);
      expect(light.copyWith().colors, light.colors);
      expect(light.lerp(null, 0.5), light);
      expect(light.lerp(dark, 0).colors.bg, light.colors.bg);
      expect(light.lerp(dark, 1).colors.bg, dark.colors.bg);
      expect(light.lerp(dark, 0.4).script, MmScript.latin);
      expect(light.lerp(dark, 0.6).script, MmScript.urdu);
      expect(light.lerp(dark, 0.6).highContrast, isTrue);
    });

    testWidgets('context.mm reads the theme and fails loudly without it', (
      tester,
    ) async {
      late MmSemantics semantics;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            semantics = context.mm;
            return const SizedBox();
          },
        ),
      );
      expect(semantics.script, MmScript.latin);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(() => context.mm, throwsFlutterError);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('styleFor', () {
    final urdu = MmTheme.data(
      brightness: Brightness.light,
      script: MmScript.urdu,
    );
    final latin = MmTheme.data(brightness: Brightness.light);

    test('sets Latin-only user text in Atkinson in the Urdu UI', () {
      final body = urdu.textTheme.bodyLarge!;
      final semantics = urdu.extension<MmSemantics>()!;
      final styled = semantics.styleFor('Ali Raza', body);
      expect(styled.fontFamily, 'packages/mm_ui/AtkinsonHyperlegibleNext');
      expect(styled.height, body.height);
      expect(styled.fontSize, body.fontSize);
      final urduName = String.fromCharCodes([0x0639, 0x0644, 0x06CC]);
      expect(semantics.styleFor(urduName, body), body);
      expect(semantics.styleFor('Rs 500 $urduName', body), body);
    });

    test('changes nothing in the English UI', () {
      final body = latin.textTheme.bodyLarge!;
      expect(latin.extension<MmSemantics>()!.styleFor('Ali', body), body);
    });

    test('recognises every Arabic-script block', () {
      for (final rune in [0x0627, 0x0750, 0x08A0, 0xFB50, 0xFE70]) {
        expect(
          MmSemantics.hasArabicScript(String.fromCharCode(rune)),
          isTrue,
          reason: rune.toRadixString(16),
        );
      }
      expect(MmSemantics.hasArabicScript('CNIC 123'), isFalse);
    });
  });

  group('MmMotion', () {
    testWidgets('honours reduced motion', (tester) async {
      late Duration normal;
      late Duration reduced;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            normal = MmMotion.of(context, MmDuration.standard);
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (inner) {
                  reduced = MmMotion.of(inner, MmDuration.standard);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      expect(normal, MmDuration.standard);
      expect(reduced, Duration.zero);
    });
  });

  group('MmIcons', () {
    test('pointing icons mirror in right-to-left layouts', () {
      expect(MmIcons.back.matchTextDirection, isTrue);
      expect(MmIcons.chevronEnd.matchTextDirection, isTrue);
      // Trends run along time, which runs from the start edge.
      expect(MmIcons.trendUp.matchTextDirection, isTrue);
      expect(MmIcons.trendDown.matchTextDirection, isTrue);
      expect(MmIcons.trendFlat.matchTextDirection, isTrue);
      expect(MmIcons.minus.matchTextDirection, isFalse);
      expect(MmIcons.home.matchTextDirection, isFalse);
      expect(
        MmIcons.all.values.every((icon) => icon.fontPackage == 'mm_ui'),
        isTrue,
      );
      expect(MmIcons.all.length, greaterThan(50));
    });
  });
}
