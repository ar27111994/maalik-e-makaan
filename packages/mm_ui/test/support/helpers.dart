import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'harness.dart';
import 'words.dart';

/// The colour roles of [variant] (the same as [MmVariant.colors]).
MmColorTokens colorsOf(MmVariant variant) => variant.colors;

/// A callback for controls that should look enabled.
void tapped() {}

/// Draws focus as when driven from a keyboard, for the rest of the test.
void useKeyboardHighlights() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// [child] with animations turned off, as when the platform asks for
/// reduced motion.
Widget withoutAnimations(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// Pumps [child] at 200% text on a 320 dp wide phone.
Future<void> pumpLargeNarrow(
  WidgetTester tester,
  Widget child, {
  double height = 740,
}) => pumpThemed(
  tester,
  child,
  variant: MmVariant.largeText,
  size: Size(320, height),
);

/// Pumps [child] at 200% text on a phone [width] wide (320 dp by default),
/// in English and in Urdu, in a scrolling page as a screen would hold it,
/// and fails on any overflow or other reported error and on any line that
/// breaks inside a word or a number ([brokenWords]): text at large sizes
/// wraps between words, never mid-word, and an amount never mid-number.
/// [then] checks more in each language.
Future<void> expectFitsNarrowLargeText(
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

/// Pumps [child] as the app shows the Urdu UI at 200% text: the Urdu
/// variant (Noto Sans Arabic, with figures in the Latin face) with the text
/// scaled twice, on a phone [width] wide, in a scrolling page.
Future<void> pumpUrduAt200(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double height = 1400,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(MmSpace.s4),
              child: child,
            ),
          ),
        ),
      ),
      variant: MmVariant.urdu,
    ),
  );
  await tester.pumpAndSettle();
}

/// The `Text` that says [english], or [urdu] in the Urdu variant.
Finder textIn(String english, String urdu) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data == english || widget.data == urdu),
);

/// The paragraph whose text contains [text].
RenderParagraph paragraphOf(WidgetTester tester, String text) =>
    tester.renderObject(find.textContaining(text, findRichText: true).first);

/// The effective style of the paragraph whose text contains [text]: a
/// `Text` wraps its span in one that carries the merged style.
TextStyle styleOf(WidgetTester tester, String text) =>
    paragraphOf(tester, text).text.style!;

/// Whether the widget found by [finder] has the primary focus.
bool hasFocus(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder.first)).hasPrimaryFocus;

/// Whether the control around [text] has the primary focus.
bool focusedAt(WidgetTester tester, String text) =>
    hasFocus(tester, find.text(text));

/// The labels of [node]'s descendants that have one, in the order a screen
/// reader reads them.
List<String> labelsIn(SemanticsNode node) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      if (child.label.isNotEmpty) labels.add(child.label);
      visit(child);
    }
  }

  visit(node);
  return labels;
}

/// The labels of [node]'s children (not their descendants) in the order a
/// screen reader reads them.
List<String> readingOrder(SemanticsNode node) => [
  for (final child in node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.traversalOrder,
  ))
    child.label,
];

/// The painters of every [CustomPaint] under [widget] whose painter is a
/// [T], in tree order.
List<T> paintersIn<T extends CustomPainter>(
  WidgetTester tester,
  Finder widget,
) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: widget, matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.painter)
    .whereType<T>()
    .toList();

/// The painter of the first [CustomPaint] under [widget] whose painter is
/// a [T].
T painterIn<T extends CustomPainter>(WidgetTester tester, Finder widget) =>
    paintersIn<T>(tester, widget).first;

/// The number of lines [part] of [paragraph]'s text is drawn across: 1
/// when it is whole on one line. [part] must be set in one face (figures,
/// or Urdu words): boxes of different faces differ in height.
int linesOf(RenderParagraph paragraph, String part) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final start = text.indexOf(part);
  expect(start, isNot(-1), reason: '"$part" is not in "$text"');
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + part.length),
  );
  return {for (final box in boxes) box.bottom.round()}.length;
}
