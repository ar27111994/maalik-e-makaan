import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_line_icon.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The close button at the end of a notice (a banner, a snackbar that
/// stays): an icon button that says "Dismiss" (from `MmLocalizations`) to
/// screen readers once, shows it as a tooltip, and is centred on the first
/// line of the notice's text. Its glyph grows with the text, as the
/// notice's own icon does, up to [MmIconLabel.maxIconScale] times.
///
/// Its focus ring comes from the ambient theme, so a notice drawn in the
/// opposite mode (a snackbar) gets that mode's ring. Internal to the
/// feedback family.
class MmDismissButton extends StatelessWidget {
  /// Creates a dismiss button in [color] that calls [onPressed], centred on
  /// the first line of [style] text that starts [textTop] below the
  /// button's top.
  const new({
    required this.color,
    required this.onPressed,
    required this.style,
    required this.textTop,
    super.key,
  });

  /// The colour of the icon.
  final Color color;

  /// Called when the button is activated.
  final VoidCallback onPressed;

  /// The style of the first line of the notice's text.
  final TextStyle style;

  /// How far the notice's text starts below the top of the row the button
  /// sits in.
  final double textTop;

  @override
  Widget build(BuildContext context) {
    final label = MmLocalizations.of(context).dismiss;
    final iconSize = MmIconLabel.scaledSize(context, MmSize.iconLg);
    // An icon button is its glyph in an 8 dp padding, and at least a touch
    // target.
    final height = math.max(MmSize.minTarget, iconSize + 2 * MmSpace.s2);
    final top = math.max<double>(
      0,
      textTop + MmLineIcon.lineHeightOf(context, style) / 2 - height / 2,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(top: top, end: MmSpace.s1),
      // The tooltip's words are already the label; announcing them again as
      // a tooltip would make screen readers say them twice.
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          color: color,
          iconSize: iconSize,
          icon: Semantics(label: label, child: const Icon(MmIcons.close)),
        ),
      ),
    );
  }
}
