import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The one filled action of a feedback component: the empty state's next
/// step, the error state's retry, a confirm dialog's confirm button.
///
/// A themed [FilledButton] with what the feedback family adds to it: room
/// for a label that wraps at large text, a focus ring drawn in the button's
/// text colour (the theme's focus colour is the cobalt of the fill itself,
/// so its ring would not show), and, when [destructive], the overdue fill
/// with whichever of the surface and ink roles contrasts more with it.
///
/// Internal to the feedback family.
class MmFilledAction extends StatelessWidget {
  /// Creates a filled action that calls [onPressed] when activated.
  const new({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    super.key,
  });

  /// What the action does, as a verb ("Add tenant").
  final String label;

  /// Called when the button is tapped or activated from the keyboard. When
  /// null the button is disabled.
  final VoidCallback? onPressed;

  /// An icon before the label (after it in right-to-left layouts).
  final IconData? icon;

  /// Whether the action removes or destroys a record: the fill is the
  /// overdue colour instead of cobalt.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final style = styleFor(context.mm.colors, destructive: destructive);
    final text = Text(label, textAlign: TextAlign.center);
    final icon = this.icon;
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: text,
    );
  }

  /// The style of a filled feedback action in [colors]: cobalt, or the
  /// overdue colours when [destructive], with a visible focus ring. The
  /// disabled colours stay the theme's.
  static ButtonStyle styleFor(
    MmColorTokens colors, {
    bool destructive = false,
  }) {
    final fill = destructive ? colors.overdue : colors.primary;
    final ink = destructive ? onOverdue(colors) : colors.onPrimary;
    return ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s4,
          vertical: MmSpace.s2,
        ),
      ),
      iconSize: const WidgetStatePropertyAll(MmSize.iconMd),
      backgroundColor: _whileEnabled(fill),
      foregroundColor: _whileEnabled(ink),
      iconColor: _whileEnabled(ink),
      side: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) &&
                !states.contains(WidgetState.disabled)
            ? BorderSide(color: ink, width: MmSize.focusRing)
            : null,
      ),
    );
  }

  /// The text colour on the overdue fill: whichever of the surface and ink
  /// roles contrasts more with it. The token build checks the surface on
  /// overdue at 4.5:1 or better in every mode.
  static Color onOverdue(MmColorTokens colors) {
    final fill = colors.overdue.computeLuminance();
    double contrast(Color color) {
      final other = color.computeLuminance();
      return (math.max(fill, other) + 0.05) / (math.min(fill, other) + 0.05);
    }

    return contrast(colors.surface) >= contrast(colors.ink)
        ? colors.surface
        : colors.ink;
  }

  /// [color] while the button is enabled; the theme's disabled colours
  /// otherwise.
  static WidgetStateProperty<Color?> _whileEnabled(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : color,
      );
}
