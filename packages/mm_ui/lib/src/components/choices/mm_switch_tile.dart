import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A setting that is on or off and takes effect at once: send rent
/// reminders, add late fees, show amounts in lakh and crore.
///
/// The whole row is the target: tapping anywhere on it, or pressing Enter
/// or Space while it has focus, flips the switch. The switch sits at the
/// end; while on, its thumb carries a check mark (the theme draws it), so
/// the state does not rest on colour or position alone. Disabled, the
/// switch and its words turn muted ink, still readable. Assistive
/// technology hears one element: the label and description, and whether
/// it is on.
///
/// Use it for settings that apply immediately. For a choice that is saved
/// with a form, or agreeing to something, use an `MmCheckboxTile`.
///
/// ```dart
/// MmSwitchTile(
///   label: l10n.rentReminders,
///   description: l10n.rentRemindersHint,
///   value: settings.reminders,
///   onChanged: (on) => settings.setReminders(on),
/// )
/// ```
class MmSwitchTile extends StatelessWidget {
  /// Creates a switch row named [label], on when [value] is true.
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  /// What the switch turns on ("Send rent reminders").
  final String label;

  /// A line below the label that explains the setting.
  final String? description;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new state when the row is toggled. When null the row
  /// is disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final description = this.description;
    final enabled = onChanged != null;
    return MmFocusWithin(
      radius: MmRadius.none,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: mm.styleFor(
            label,
            text.bodyLarge!.copyWith(
              color: enabled ? colors.ink : colors.inkMuted,
            ),
          ),
        ),
        subtitle: description == null
            ? null
            : Text(
                description,
                style: mm.styleFor(
                  description,
                  text.bodyMedium!.copyWith(color: colors.inkMuted),
                ),
              ),
      ),
    );
  }
}
