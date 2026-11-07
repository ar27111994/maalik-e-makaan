import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The Material that paints the surface of the widget found by [widget].
Material surfaceOf(WidgetTester tester, Finder widget) => tester.widget(
  find.descendant(of: widget, matching: find.byType(Material)).first,
);

/// The border of the surface of the widget found by [widget].
BorderSide sideOf(WidgetTester tester, Finder widget) =>
    (surfaceOf(tester, widget).shape! as OutlinedBorder).side;

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

/// A letter or digit: what a word or a number is made of.
final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The lines of every paragraph under [within] (the whole screen by
/// default) that break inside a word or a number, such as "Collect|ed" or
/// "Rs 1,2|5,000": each as the text before and after the break.
List<String> brokenWords(WidgetTester tester, {Finder? within}) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(
    within == null
        ? find.byType(RichText)
        : find.descendant(of: within, matching: find.byType(RichText)),
  );
  final broken = <String>[];
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    double lineOf(int offset) =>
        paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
    // Runs in different faces (Latin and Nastaliq) start a few pixels apart
    // on one line; a new line starts at least half a line further down.
    final fontSize = paragraph.text.style?.fontSize ?? kDefaultFontSize;
    final newLine = paragraph.textScaler.scale(fontSize) / 2;
    for (var offset = 1; offset < text.length; offset++) {
      final before = lineOf(offset - 1);
      final after = lineOf(offset);
      // A new line starts here, within what the paragraph shows (an
      // ellipsis hides the rest).
      if (after < before + newLine || after >= paragraph.size.height) continue;
      final word = paragraph.getWordBoundary(TextPosition(offset: offset));
      if (word.start < offset &&
          offset < word.end &&
          _wordCharacter.hasMatch(word.textInside(text))) {
        broken.add(
          '${text.substring(word.start, offset)}|'
          '${text.substring(offset, word.end)}',
        );
      }
    }
  }
  return broken;
}

/// Fails when a paragraph under [within] breaks a line inside a word or a
/// number: text at large sizes must wrap between words, never mid-word,
/// and an amount never mid-number.
void expectWholeWords(WidgetTester tester, {Finder? within}) {
  final broken = brokenWords(tester, within: within);
  expect(broken, isEmpty, reason: 'lines break inside words: $broken');
}

/// Pumps [child] at 200% text on a phone [width] wide (320 dp by default),
/// in English and in Urdu, in a scrolling page as a screen would hold it,
/// and fails on any overflow or other reported error and on any line that
/// breaks inside a word or a number. [then] checks more in each language.
///
/// It is the shared `expectFitsNarrowLargeText` with the check for broken
/// words added.
Future<void> expectWholeAtLargeText(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double height = 740,
  void Function(Locale locale)? then,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  for (final locale in const [Locale('en'), Locale('ur')]) {
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(MmSpace.s4),
            child: child,
          ),
        ),
        variant: MmVariant.largeText,
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: locale.languageCode);
    final broken = brokenWords(tester);
    expect(
      broken,
      isEmpty,
      reason: '${locale.languageCode}: lines break inside words: $broken',
    );
    then?.call(locale);
  }
}

/// The bounds of the ink inside the circle that [boundary] holds: the
/// pixels that differ clearly from the circle's [fill], in logical pixels
/// from the boundary's top left.
Future<Rect> inkOnCircle(
  WidgetTester tester,
  Finder boundary,
  Color fill,
) async {
  const pixelRatio = 4.0;
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final image = (await tester.runAsync(
    () => render.toImage(pixelRatio: pixelRatio),
  ))!;
  // Raw RGBA, the default.
  final data = (await tester.runAsync(image.toByteData))!;
  int channel(double value) => (value * 255).round();
  final (r, g, b) = (channel(fill.r), channel(fill.g), channel(fill.b));
  // Inside the circle, clear of its anti-aliased edge.
  final radius = image.width / 2 - 2 * pixelRatio;
  var ink = Rect.zero;
  var found = false;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x + 0.5 - image.width / 2;
      final dy = y + 0.5 - image.height / 2;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (y * image.width + x) * 4;
      final distance =
          (data.getUint8(i) - r).abs() +
          (data.getUint8(i + 1) - g).abs() +
          (data.getUint8(i + 2) - b).abs();
      if (distance <= 90) continue;
      final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
      ink = found ? ink.expandToInclude(pixel) : pixel;
      found = true;
    }
  }
  expect(found, isTrue, reason: 'no ink on the circle');
  return Rect.fromLTRB(
    ink.left / pixelRatio,
    ink.top / pixelRatio,
    ink.right / pixelRatio,
    ink.bottom / pixelRatio,
  );
}
