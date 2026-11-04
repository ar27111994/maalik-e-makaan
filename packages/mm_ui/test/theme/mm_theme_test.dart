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

    test('buttons draw a focus ring and keep 48 dp targets', () {
      final theme = MmTheme.data(brightness: Brightness.light);
      final side = theme.filledButtonTheme.style!.side!;
      expect(side.resolve({WidgetState.focused})!.width, MmSize.focusRing);
      expect(
        side.resolve({WidgetState.focused})!.color,
        MmColorModes.light.focus,
      );
      expect(side.resolve(<WidgetState>{}), BorderSide.none);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        MmSize.buttonHeight,
      );
      final outlined = theme.outlinedButtonTheme.style!;
      expect(
        outlined.side!.resolve({WidgetState.disabled})!.color,
        MmColorModes.light.rule,
      );
      expect(
        outlined.foregroundColor!.resolve({WidgetState.disabled}),
        MmColorModes.light.inkMuted,
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
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
      expect(MmIcons.home.matchTextDirection, isFalse);
      expect(
        MmIcons.all.values.every((icon) => icon.fontPackage == 'mm_ui'),
        isTrue,
      );
      expect(MmIcons.all.length, greaterThan(50));
    });
  });
}
