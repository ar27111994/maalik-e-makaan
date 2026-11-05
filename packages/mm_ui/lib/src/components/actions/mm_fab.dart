import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The floating action button: the one action a screen exists for, kept
/// within thumb reach above the content ("Add tenant" on the tenants list).
///
/// Extended (the default), it shows its [icon] and [label]; the label wraps
/// rather than truncating at large text sizes. Not extended, it shows the
/// icon alone, and the label becomes its tooltip and what screen readers
/// announce. Use the compact form where the extended one would cover
/// content, for example while a list scrolls.
///
/// Put at most one on a screen, usually as `Scaffold.floatingActionButton`.
/// For actions inside the content, use `MmButton`.
///
/// ```dart
/// Scaffold(
///   floatingActionButton: MmFab(
///     label: l10n.addTenant,
///     icon: MmIcons.invite,
///     onPressed: addTenant,
///   ),
/// )
/// ```
class MmFab extends StatelessWidget {
  /// Creates a floating action button that calls [onPressed] when
  /// activated.
  const new({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extended = true,
    super.key,
  });

  /// What the button does, as a verb ("Add tenant"). Shown beside the icon
  /// when [extended]; the tooltip and screen reader label otherwise.
  final String label;

  /// The icon of the action.
  final IconData icon;

  /// Called when the button is tapped or activated from the keyboard. When
  /// null the button is disabled and drawn flat in muted colours.
  final VoidCallback? onPressed;

  /// Whether the label is shown beside the icon.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final enabled = onPressed != null;
    final icon = Icon(this.icon);
    final fab = FloatingActionButton(
      onPressed: onPressed,
      // The theme draws an enabled button, its focus ring included. A
      // disabled one lies flat on sunken paper inside the rule border, in
      // muted ink, as the theme's disabled filled buttons do.
      backgroundColor: enabled ? null : colors.surfaceSunken,
      foregroundColor: enabled ? null : colors.inkMuted,
      disabledElevation: 0,
      shape: enabled
          ? null
          : RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(MmRadius.md),
              ),
              side: BorderSide(color: colors.rule),
            ),
      child: extended
          ? Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MmSpace.s4,
                MmSpace.s2,
                MmSpace.s5,
                MmSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: MmSpace.s3,
                children: [
                  icon,
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
            )
          : Semantics(label: label, child: icon),
    );
    if (extended) {
      // Material's extended button lays its label out on one line however
      // long it is; this one keeps the standard size as a minimum and grows
      // to fit a wrapped label instead.
      return FloatingActionButtonTheme(
        data: FloatingActionButtonTheme.of(context).copyWith(
          sizeConstraints: const BoxConstraints(
            minWidth: MmSize.fab,
            minHeight: MmSize.fab,
          ),
        ),
        child: fab,
      );
    }
    // The label is the semantics label already; a second tooltip node
    // would make screen readers say it twice.
    return Tooltip(message: label, excludeFromSemantics: true, child: fab);
  }
}
