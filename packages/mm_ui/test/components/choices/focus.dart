import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';

/// Whether the [MmFocusWithin] ring around the row that holds [text] (or
/// around the first ringed row, when [text] is null) is drawn.
bool ringShown(WidgetTester tester, [String? text]) {
  final row = text == null
      ? find.byType(MmFocusWithin).first
      : find.ancestor(
          of: find.text(text),
          matching: find.byType(MmFocusWithin),
        );
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: row, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).border != null;
}

/// The colour of the icon [icon] as painted (its glyph's text colour).
Color? iconColorOf(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

/// Shows [child] in a golden composition as the keyboard leaves it: with
/// focus on the [index]th control of [child] that Tab can reach, and focus
/// drawn as for a keyboard. A golden test file that uses it resets the
/// highlight strategy after each test with [resetFocusHighlights].
class KeyboardFocused extends StatefulWidget {
  /// Focuses the [index]th traversable control in [child].
  const new({required this.child, this.index = 0, super.key});

  /// The composition's part to focus within.
  final Widget child;

  /// Which control to focus, in tree order.
  final int index;

  @override
  State<KeyboardFocused> createState() => _KeyboardFocusedState();
}

class _KeyboardFocusedState extends State<KeyboardFocused> {
  final FocusNode _scope = FocusNode(
    debugLabel: 'KeyboardFocused',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      _scope.traversalDescendants.elementAt(widget.index).requestFocus();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _scope, child: widget.child);
}

/// Puts the focus highlight strategy back after a [KeyboardFocused] test.
void resetFocusHighlights() =>
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;

/// Whether every piece of text under [of] is shown whole: no paragraph is
/// cut short with an ellipsis, and no number (a day of the month) breaks
/// across lines.
void expectTextWhole(WidgetTester tester, Finder of) {
  for (final element
      in find.descendant(of: of, matching: find.byType(RichText)).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" is cut');
    if (RegExp(r'^\d+$').hasMatch(text)) {
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + 0.01),
        reason: '"$text" breaks across lines',
      );
    }
  }
}
