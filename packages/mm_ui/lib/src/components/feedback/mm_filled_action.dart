import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_button_styles.dart';

/// The one filled action of a feedback component: the empty state's next
/// step, the error state's retry, a confirm dialog's confirm button.
///
/// A themed [FilledButton] (cobalt, with the theme's focus ring outside it)
/// with room for a label that wraps at large text; when [destructive], it
/// is filled in the overdue colour ([MmButtonStyles.destructive]).
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
    final style = destructive
        ? MmButtonStyles.destructive(Theme.of(context).colorScheme)
        : MmButtonStyles.labelled;
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
}
