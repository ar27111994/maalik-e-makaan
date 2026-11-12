import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How much room a run of text takes as a `Text` would set it: its box,
/// and how far its glyphs reach past the top and the bottom of its lines.
///
/// The dots and marks of Urdu letters can reach past the lines they sit
/// on; a component sizing itself around a label leaves room for that
/// overhang so nothing is clipped.
///
/// Internal to mm_ui: any component family may use it (the scaffold, the
/// page and the tabs size their bars by it; the segmented control, the
/// snack bar and the avatar measure their labels with it).
@immutable
final class MmTextMetrics {
  /// Measures [text] in [style] as it would be set in [context]: in the
  /// ambient direction and language, at [textScaler] (the ambient text
  /// scale when null), wrapped at [maxWidth] and cut at [maxLines].
  factory of(
    BuildContext context,
    String text,
    TextStyle? style, {
    TextScaler? textScaler,
    double maxWidth = double.infinity,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    var top = 0.0;
    var bottom = painter.height;
    for (final box in painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    )) {
      top = math.min(top, box.top);
      bottom = math.max(bottom, box.bottom);
    }
    final metrics = MmTextMetrics._(
      size: painter.size,
      minIntrinsicWidth: painter.minIntrinsicWidth,
      maxIntrinsicWidth: painter.maxIntrinsicWidth,
      overhangAbove: -top,
      overhangBelow: bottom - painter.height,
      lineCount: painter.computeLineMetrics().length,
    );
    painter.dispose();
    return metrics;
  }

  const new _({
    required this.size,
    required this.minIntrinsicWidth,
    required this.maxIntrinsicWidth,
    required this.overhangAbove,
    required this.overhangBelow,
    required this.lineCount,
  });

  /// The width of the widest line and the height of all the lines.
  final Size size;

  /// The width of the widest word: the narrowest the text can be set
  /// without breaking inside a word.
  final double minIntrinsicWidth;

  /// The width of the text on one line, without wrapping.
  final double maxIntrinsicWidth;

  /// How far the glyphs reach above the first line's top (zero or more).
  final double overhangAbove;

  /// How far the glyphs reach below the last line's bottom (zero or more).
  final double overhangBelow;

  /// How many lines the text takes.
  final int lineCount;
}
