import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_button_styles.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

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
    // The icon grows with the label as MmButton's does, up to 150%.
    final style =
        (destructive
                ? MmButtonStyles.destructive(Theme.of(context).colorScheme)
                : MmButtonStyles.labelled)
            .copyWith(
              iconSize: WidgetStatePropertyAll(
                MmIconLabel.scaledSize(context, MmSize.iconMd),
              ),
            );
    final text = MmScriptText(
      label,
      style: const TextStyle(),
      textAlign: TextAlign.center,
    );
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
