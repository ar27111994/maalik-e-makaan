import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A yes-or-no choice saved with a form: the tenant confirmed their CNIC,
/// the rent includes electricity, every unit in a list is selected.
///
/// The whole row is the target: tapping anywhere on it, or pressing Enter
/// or Space while it has focus, toggles the box at the start of the row.
/// With [tristate], the box also shows a dash for "some" (a "select all"
/// row over a partly selected list) and cycles unchecked, checked, mixed.
/// Assistive technology hears one element: the label and description, and
/// whether it is checked, unchecked or mixed.
///
/// Use it for choices that are saved together, or for selecting rows. For
/// a setting that applies at once, use an `MmSwitchTile`; for one of
/// several exclusive options, an `MmRadioGroup`.
///
/// ```dart
/// MmCheckboxTile(
///   label: l10n.includesElectricity,
///   value: includesElectricity,
///   onChanged: (checked) =>
///       setState(() => includesElectricity = checked!),
/// )
/// ```
class MmCheckboxTile extends StatelessWidget {
  /// Creates a checkbox row named [label], checked when [value] is true.
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.tristate = false,
    super.key,
  }) : assert(tristate || value != null, 'Only a tristate box can be mixed.');

  /// What checking the box means ("Rent includes electricity").
  final String label;

  /// A line below the label that explains the choice.
  final String? description;

  /// Whether the box is checked; null shows it mixed (only with
  /// [tristate]).
  final bool? value;

  /// Whether the box can be mixed (null) as well as checked and unchecked.
  final bool tristate;

  /// Called with the new state when the row is toggled (null when a
  /// [tristate] box turns mixed). When null the row is disabled.
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final description = this.description;
    final enabled = onChanged != null;
    return MmFocusWithin(
      radius: MmRadius.none,
      child: CheckboxListTile(
        value: value,
        tristate: tristate,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
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
