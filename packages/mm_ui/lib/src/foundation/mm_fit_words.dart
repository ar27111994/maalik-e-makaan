import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shows [tight] where its longest word fits the width it is given, and
/// [loose] (the same words with more places to break) where it does not.
///
/// An amount and its currency word are joined by a no-break space, and a
/// receipt number has no place to break at all; on a narrow badge or seal
/// at 200% text, such a word can be wider than the line, and a paragraph
/// then cuts it wherever the line ends, inside the figures ("1,25,00" /
/// "0 روپے"). [loosened] gives the words that break between the figures
/// and the currency word, and after each dash of a number, so the figures
/// themselves stay whole; [tight] keeps them together wherever they fit.
///
/// It reports [tight]'s natural width and [loose]'s narrowest, lays out,
/// paints and reads only the one it shows, and has that one's baseline.
///
/// Internal to mm_ui: any component family may use it.
class MmFitWords
    extends SlottedMultiChildRenderObjectWidget<MmFitWordsSlot, RenderBox> {
  /// Shows [tight], or [loose] where [tight]'s longest word does not fit.
  const new({required this.tight, required this.loose, super.key});

  /// The words as they are, shown wherever their longest word fits.
  final Widget tight;

  /// The words with more places to break ([loosened]).
  final Widget loose;

  /// [text] with places to break where an amount or a number has none: a
  /// no-break space (or the narrow one `intl` uses) becomes a space, and a
  /// dash followed by more of a number gets a zero-width break after it.
  static String loosened(String text) => text
      .replaceAll(_noBreakSpaces, ' ')
      .replaceAllMapped(_dashInWord, (match) => '-\u200B');

  static final _noBreakSpaces = RegExp('[\u00A0\u202F]');
  static final _dashInWord = RegExp(r'-(?=\S)');

  @override
  Iterable<MmFitWordsSlot> get slots => MmFitWordsSlot.values;

  @override
  Widget childForSlot(MmFitWordsSlot slot) => switch (slot) {
    MmFitWordsSlot.tight => tight,
    MmFitWordsSlot.loose => loose,
  };

  @override
  RenderMmFitWords createRenderObject(BuildContext context) =>
      RenderMmFitWords();
}

/// The places [MmFitWords] holds its two versions of the words in.
enum MmFitWordsSlot {
  /// The words as they are.
  tight,

  /// The words with more places to break.
  loose,
}

/// The render object of [MmFitWords].
class RenderMmFitWords extends RenderBox
    with SlottedContainerRenderObjectMixin<MmFitWordsSlot, RenderBox> {
  RenderBox get _child => childForSlot(MmFitWordsSlot.tight)!;
  RenderBox get _loose => childForSlot(MmFitWordsSlot.loose)!;

  /// The version shown at [maxWidth]: the words as they are while their
  /// longest word fits.
  RenderBox _shownAt(double maxWidth) =>
      _child.getMinIntrinsicWidth(double.infinity) <= maxWidth
      ? _child
      : _loose;

  /// The version shown: the one laid out for the current constraints.
  RenderBox get shown => _shown;
  late RenderBox _shown;

  @override
  Iterable<RenderBox> get children => [
    for (final slot in MmFitWordsSlot.values) ?childForSlot(slot),
  ];

  @override
  double computeMinIntrinsicWidth(double height) => math.min(
    _child.getMinIntrinsicWidth(height),
    _loose.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _child.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _shownAt(width).getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _shownAt(width).getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _shownAt(constraints.maxWidth).getDryLayout(constraints);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _shownAt(constraints.maxWidth).getDryBaseline(constraints, baseline);

  @override
  void performLayout() {
    final shown = _shownAt(constraints.maxWidth)
      ..layout(constraints, parentUsesSize: true);
    _shown = shown;
    // The other is laid out too, so it stays ready, but never shown. It is
    // given all the width it wants: laid out at the shown one's width, it
    // would wrap inside the very word that made it the wrong one, and
    // anything that reads the laid-out words (a test of where lines
    // break) would find a cut word the screen never shows.
    (shown == _child ? _loose : _child).layout(
      BoxConstraints(maxHeight: constraints.maxHeight),
    );
    size = shown.size;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _shown.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(_shown, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(_shown);
}
