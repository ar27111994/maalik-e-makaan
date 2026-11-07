import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'helpers.dart';

/// Gives keyboard focus to the control around [inside], a widget the
/// control draws (its label or icon), as Tab would.
Future<void> focusOn(WidgetTester tester, Finder inside) async {
  Focus.of(tester.element(inside.first)).requestFocus();
  await tester.pumpAndSettle();
}

/// [goldenEveryVariant] as a keyboard user sees the composition: focus
/// drawn as for the keyboard, on the control around [focused].
void focusedGoldenEveryVariant(
  String name,
  Widget Function() build, {
  required Finder focused,
  Map<MmVariant, Size> sizes = const {},
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    useKeyboardHighlights();
    await pumpThemed(
      tester,
      build(),
      variant: variant,
      size: sizes[variant] ?? const Size(360, 740),
    );
    await focusOn(tester, focused);
    await expectAccessible(tester);
    await expectGolden(name, variant);
  });
}
