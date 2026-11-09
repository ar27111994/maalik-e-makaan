import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_button_styles.dart';

import '../support/testing.dart';

void main() {
  group('MmButtonStyles', () {
    test('labelled leaves room for a wrapped label and sizes icons', () {
      const style = MmButtonStyles.labelled;
      expect(
        style.padding!.resolve({}),
        const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s4,
          vertical: MmSpace.s2,
        ),
      );
      expect(style.iconSize!.resolve({}), MmSize.iconMd);
      // Colours, shape and focus ring stay the theme's.
      expect(style.backgroundColor, isNull);
      expect(style.shape, isNull);
      expect(style.side, isNull);
    });

    for (final variant in MmVariant.values) {
      test('destructive is overdue with on-error ink (${variant.name})', () {
        final scheme = variant.theme.colorScheme;
        final colors = variant.colors;
        final style = MmButtonStyles.destructive(scheme);
        expect(style.padding, MmButtonStyles.labelled.padding);
        expect(style.iconSize, MmButtonStyles.labelled.iconSize);
        expect(style.backgroundColor!.resolve({}), colors.overdue);
        expect(style.foregroundColor!.resolve({}), colors.surface);
        expect(style.iconColor!.resolve({}), colors.surface);
        // Disabled, the theme's disabled colours show.
        const disabled = {WidgetState.disabled};
        expect(style.backgroundColor!.resolve(disabled), isNull);
        expect(style.foregroundColor!.resolve(disabled), isNull);
        expect(style.iconColor!.resolve(disabled), isNull);
      });
    }

    test('whileEnabled gives way to the disabled colours', () {
      final color = MmButtonStyles.whileEnabled(MmColorModes.light.primary);
      expect(color.resolve({}), MmColorModes.light.primary);
      expect(color.resolve({WidgetState.hovered}), MmColorModes.light.primary);
      expect(color.resolve({WidgetState.disabled}), isNull);
    });
  });
}
