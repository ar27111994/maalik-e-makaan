import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A decorative icon that sits before a block of text, centred on the
/// text's first line at every text size and in both scripts (a Nastaliq
/// line is about twice as tall as a Latin one).
///
/// It is hidden from assistive technology: the text beside it carries the
/// meaning. Internal to the feedback family (banners and snackbars).
class MmLineIcon extends StatelessWidget {
  /// Creates an icon centred on the first line of text set in [style].
  const new({
    required this.icon,
    required this.color,
    required this.style,
    super.key,
  });

  /// The glyph.
  final IconData icon;

  /// The glyph's colour.
  final Color color;

  /// The style of the text beside the icon.
  final TextStyle style;

  /// The height of one line of [style] at the ambient text scale.
  static double lineHeightOf(BuildContext context, TextStyle style) {
    final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    return fontSize * (style.height ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final line = lineHeightOf(context, style);
    final inset = math.max<double>(0, (line - MmSize.iconLg) / 2);
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.only(top: inset),
        child: Icon(icon, size: MmSize.iconLg, color: color),
      ),
    );
  }
}
