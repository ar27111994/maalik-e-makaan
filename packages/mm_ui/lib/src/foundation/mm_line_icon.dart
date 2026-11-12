import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A decorative icon that sits before a block of text, centred on the
/// text's first line at every text size and in both scripts (an Urdu line
/// is taller than a Latin one).
///
/// It grows with the text size, up to [MmIconLabel.maxIconScale] times its
/// [MmSize.iconLg] size, as every icon beside words in mm_ui does. It is
/// hidden from assistive technology: the text beside it carries the
/// meaning: a banner's or snackbar's icon, a nameplate's property icon.
///
/// Internal to mm_ui: any component family may use it.
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

  /// The icon's size at the ambient text scale.
  static double sizeOf(BuildContext context) =>
      MmIconLabel.scaledSize(context, MmSize.iconLg);

  /// How far below the top of a block of [style] text a control [height]
  /// tall starts so that it is centred on the text's first line (never
  /// above the block's top).
  static double firstLineInset(
    BuildContext context,
    TextStyle style,
    double height,
  ) => math.max<double>(0, (lineHeightOf(context, style) - height) / 2);

  @override
  Widget build(BuildContext context) {
    final size = sizeOf(context);
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: firstLineInset(context, style, size),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
