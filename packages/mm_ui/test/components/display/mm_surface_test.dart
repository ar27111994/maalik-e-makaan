import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';

import '../../support/testing.dart';

/// Pumps a tappable surface in [theme] and focuses it from the keyboard.
Future<Material> _focusedIn(WidgetTester tester, ThemeData theme) async {
  await pumpThemed(
    tester,
    Builder(
      builder: (context) => Theme(
        data: theme,
        child: MmSurface(onTap: () {}, child: const Text('Ali Raza')),
      ),
    ),
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  return tester.widget<Material>(find.byType(Material).last);
}

void main() {
  group('MmSurface', () {
    testWidgets('falls back to card corners when the theme has no shape', (
      tester,
    ) async {
      final theme = MmVariant.light.theme;
      final material = await _focusedIn(
        tester,
        theme.copyWith(cardTheme: const CardThemeData()),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.md)),
      );
      expect(shape.side.color, MmColorModes.light.focus);
      expect(material.color, MmColorModes.light.surface);
    });

    testWidgets('keeps a theme shape it cannot outline', (tester) async {
      final theme = MmVariant.light.theme;
      final border = Border.all(color: MmColorModes.light.rule);
      final material = await _focusedIn(
        tester,
        theme.copyWith(cardTheme: CardThemeData(shape: border)),
      );
      expect(material.shape, border);
    });

    testWidgets('tells its content what it is filled with', (tester) async {
      Color? fill;
      await pumpThemed(
        tester,
        MmSurface(
          onTap: null,
          outlined: false,
          color: MmColorModes.light.primaryContainer,
          child: Builder(
            builder: (context) {
              fill = MmSurfaceFill.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fill, MmColorModes.light.primaryContainer);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            fill = MmSurfaceFill.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(fill, isNull);
    });
  });
}
