import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/testing.dart';

void main() {
  group('MmTheme shared settings', () {
    for (final variant in MmVariant.values) {
      test('scrollbar thumbs are the outline, muted ink while dragged or '
          'hovered (${variant.name})', () {
        final colors = variant.colors;
        final thumb = variant.theme.scrollbarTheme.thumbColor!;
        expect(thumb.resolve({}), colors.outline);
        expect(thumb.resolve({WidgetState.dragged}), colors.inkMuted);
        expect(thumb.resolve({WidgetState.hovered}), colors.inkMuted);
      });

      test('disabled icon buttons are muted ink, enabled ones keep their '
          'own colours (${variant.name})', () {
        final style = variant.theme.iconButtonTheme.style!;
        final colors = variant.colors;
        for (final property in [style.foregroundColor!, style.iconColor!]) {
          expect(property.resolve({WidgetState.disabled}), colors.inkMuted);
          expect(property.resolve({}), isNull);
          expect(property.resolve({WidgetState.selected}), isNull);
        }
      });

      test('count badges are ink with paper figures, not a status colour '
          '(${variant.name})', () {
        final badge = variant.theme.badgeTheme;
        expect(badge.backgroundColor, variant.colors.ink);
        expect(badge.textColor, variant.colors.surface);
        expect(
          badge.textStyle!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      });

      test('dialogs and sheets carry the edge of overlays '
          '(${variant.name})', () {
        final theme = variant.theme;
        final edge = MmTheme.overlayEdge(
          variant.colors,
          brightness: variant.brightness,
          highContrast: variant.highContrast,
        );
        final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
        final sheet = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
        expect(dialog.side, edge);
        expect(sheet.side, edge);
        expect(
          edge,
          variant.brightness == Brightness.dark || variant.highContrast
              ? BorderSide(color: variant.colors.outline)
              : BorderSide.none,
        );
      });

      test('field outlines keep no gap for a floating label '
          '(${variant.name})', () {
        final fields = variant.theme.inputDecorationTheme;
        for (final border in [
          fields.border,
          fields.enabledBorder,
          fields.focusedBorder,
          fields.errorBorder,
          fields.focusedErrorBorder,
          fields.disabledBorder,
        ]) {
          expect((border! as OutlineInputBorder).gapPadding, 0);
        }
      });
    }

    testEveryVariant('a stock disabled icon button paints muted ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const IconButton(onPressed: null, icon: Icon(MmIcons.add)),
        variant: variant,
      );
      final glyph = tester.widget<RichText>(
        find.descendant(
          of: find.byIcon(MmIcons.add),
          matching: find.byType(RichText),
        ),
      );
      expect(glyph.text.style!.color, colorsOf(variant).inkMuted);
    });

    testEveryVariant('a stock dialog shows the edge of overlays', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const AlertDialog(content: Text('Ledger saved')),
        variant: variant,
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (material.shape! as RoundedRectangleBorder).side,
        MmTheme.overlayEdge(
          colorsOf(variant),
          brightness: variant.brightness,
          highContrast: variant.highContrast,
        ),
      );
    });
  });

  group('MmSemantics.withTabularFigures', () {
    test('adds tabular figures and keeps the other features', () {
      const style = TextStyle(
        fontSize: 14,
        fontFeatures: [FontFeature.enable('ss01')],
      );
      final figures = MmSemantics.withTabularFigures(style);
      expect(figures.fontSize, 14);
      expect(figures.fontFeatures, [
        const FontFeature.enable('ss01'),
        const FontFeature.tabularFigures(),
      ]);
      // Applying it twice does not repeat the feature.
      expect(
        MmSemantics.withTabularFigures(figures).fontFeatures,
        figures.fontFeatures,
      );
      expect(MmSemantics.withTabularFigures(const TextStyle()).fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
    });
  });

  group('MmLocalizations.joined', () {
    test(
      'joins the parts of a spoken label with the comma of the language',
      () {
        expect(MmLocalizations.english.listSeparator, ', ');
        expect(MmLocalizations.urdu.listSeparator, '، ');
        expect(
          MmLocalizations.english.joined(['Monthly rent', '45000 rupees']),
          'Monthly rent, 45000 rupees',
        );
        expect(
          MmLocalizations.urdu.joined(['ماہانہ کرایہ', '45000 روپے']),
          'ماہانہ کرایہ، 45000 روپے',
        );
        expect(MmLocalizations.english.joined(['Rent']), 'Rent');
      },
    );
  });
}
