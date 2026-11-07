import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/testing.dart';

/// The Material that paints the button found by [button].
Material materialOf(WidgetTester tester, Finder button) => tester.widget(
  find.descendant(of: button, matching: find.byType(Material)).first,
);

/// The edge of the button found by [button].
BorderSide sideOf(WidgetTester tester, Finder button) =>
    (materialOf(tester, button).shape! as OutlinedBorder).side;

/// The colour [icon] is painted in.
Color iconColorOf(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

/// The colour the paragraph showing [text] is painted in.
Color textColorOf(WidgetTester tester, String text) =>
    styleOf(tester, text).color!;

/// The `Text` that says [english], or [urdu] in the Urdu variant.
Finder textIn(String english, String urdu) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data == english || widget.data == urdu),
);

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
