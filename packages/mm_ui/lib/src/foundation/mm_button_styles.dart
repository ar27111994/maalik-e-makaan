import 'package:flutter/material.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// What mm_ui's labelled buttons add to the theme's button styles: `MmButton`
/// and the actions of the feedback components (an empty state's next step,
/// a confirm dialog's confirm button).
///
/// The theme gives every button its shape, height, focus ring and disabled
/// colours; these add room for a label that wraps at large text, the icon
/// size, and the colours of a destructive action.
///
/// Internal to mm_ui: any component family may use it.
abstract final class MmButtonStyles {
  /// Room for a label that wraps at large text ([MmSpace.s2] above and
  /// below it, [MmSpace.s4] at its sides) and icons of [MmSize.iconMd].
  static const ButtonStyle labelled = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsetsDirectional.symmetric(
        horizontal: MmSpace.s4,
        vertical: MmSpace.s2,
      ),
    ),
    iconSize: WidgetStatePropertyAll(MmSize.iconMd),
  );

  /// [labelled], filled in [scheme]'s error colour (the overdue role) with
  /// its on colour for the label and icon: an action that removes or
  /// destroys a record. The theme's on-error colour is the surface role,
  /// which the token build checks at 4.5:1 or better against overdue in
  /// every mode. Disabled, it keeps the theme's disabled colours.
  static ButtonStyle destructive(ColorScheme scheme) => labelled.copyWith(
    backgroundColor: whileEnabled(scheme.error),
    foregroundColor: whileEnabled(scheme.onError),
    iconColor: whileEnabled(scheme.onError),
  );

  /// [labelled], outlined and labelled in [scheme]'s error colour (the
  /// overdue role): the button that starts removing a record and opens its
  /// confirmation. Focused, it keeps the theme's focus ring on its edge;
  /// disabled, the theme's muted label inside a rule border.
  static ButtonStyle destructiveOutlined(ColorScheme scheme) =>
      labelled.copyWith(
        foregroundColor: whileEnabled(scheme.error),
        iconColor: whileEnabled(scheme.error),
        side: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ||
                  states.contains(WidgetState.focused)
              ? null
              : BorderSide(color: scheme.error),
        ),
      );

  /// [color] while the button is enabled, and nothing while it is disabled,
  /// so the theme's (or the variant's) disabled colour shows.
  static WidgetStateProperty<Color?> whileEnabled(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : color,
      );
}
