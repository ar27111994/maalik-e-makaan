import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';

import '../../support/testing.dart';
import 'support.dart';

/// Pumps a tappable surface in [theme] and focuses it from the keyboard.
Future<Material> _focusedIn(WidgetTester tester, ThemeData theme) async {
  await pumpThemed(
    tester,
    Builder(
      builder: (context) => Theme(
        data: theme,
        child: MmSurface(
          owner: 'MmCard',
          onTap: () {},
          child: const Text('Ali Raza'),
        ),
      ),
    ),
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  return tester.widget<Material>(find.byType(Material).last);
}

const _remind = 'Remind';

/// A card's content with a button of its own.
Widget _withButton() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Text('Ali Raza'),
    TextButton(onPressed: () {}, child: const Text(_remind)),
  ],
);

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
          owner: 'MmListTile',
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

    testEveryVariant('a tappable surface is bounded by the outline colour, '
        'a static one by the rule', (tester, variant) async {
      final colors = colorsOf(variant);
      await pumpThemed(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmCard(onTap: () {}, child: const Text('Tappable')),
            const MmCard(child: Text('Static')),
          ],
        ),
        variant: variant,
      );
      expect(
        sideOf(tester, find.byType(MmCard).first),
        BorderSide(color: colors.outline),
      );
      expect(
        sideOf(tester, find.byType(MmCard).last),
        BorderSide(color: colors.rule),
      );
    });

    testWidgets('focus on a control inside a static card rings the control, '
        'not the card', (tester) async {
      useKeyboardHighlights();
      final card = find.byType(MmCard);
      await pumpThemed(tester, MmCard(child: _withButton()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _remind), isTrue);
      expect(sideOf(tester, card), BorderSide(color: MmColorModes.light.rule));
      expect(tester.takeException(), isNull);
    });

    testWidgets('focus on a control in a static row rings the control, not '
        'the row', (tester) async {
      useKeyboardHighlights();
      final tile = find.byType(MmListTile);
      await pumpThemed(
        tester,
        MmListTile(
          title: 'Ali Raza',
          trailing: IconButton(
            tooltip: 'Call',
            onPressed: () {},
            icon: const Icon(MmIcons.phone),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.byIcon(MmIcons.phone)), isTrue);
      expect(sideOf(tester, tile), BorderSide.none);
    });

    testWidgets('reports a control inside a tappable surface, once', (
      tester,
    ) async {
      await pumpThemed(tester, MmCard(onTap: () {}, child: _withButton()));
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      final message = (error as FlutterError).toStringDeep();
      expect(message, contains('A tappable MmCard holds a control.'));
      expect(message, contains('cannot be reached'));
      expect(message, contains('Leave onTap null'));
      expect(message, contains('The control has the focus node'));

      // Not again on the next frames while the control stays.
      useKeyboardHighlights();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Taken out and put back, it is reported again.
      await pumpThemed(
        tester,
        MmCard(onTap: () {}, child: const Text('Ali Raza')),
      );
      expect(tester.takeException(), isNull);
      await pumpThemed(tester, MmCard(onTap: () {}, child: _withButton()));
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('names the component the surface belongs to', (tester) async {
      await pumpThemed(
        tester,
        MmStatTile(
          label: 'Collected',
          value: TextButton(onPressed: () {}, child: const Text('Rs 95,000')),
          onTap: () {},
        ),
      );
      final error = tester.takeException()! as FlutterError;
      expect(
        error.toStringDeep(),
        contains('A tappable MmStatTile holds a control.'),
      );
    });

    testWidgets('a focus node that takes no focus is not a control', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmCard(
          onTap: () {},
          child: const Focus(canRequestFocus: false, child: Text(_remind)),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
