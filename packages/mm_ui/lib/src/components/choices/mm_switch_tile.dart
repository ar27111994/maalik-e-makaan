import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/choices/mm_tile_bleed.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
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
/// The row's highlight and focus ring reach 16 dp into the page's gutter,
/// so its words start, and its switch's track ends, on the content edge with
/// the fields and headings around it. The switch grows with the text as
/// icons do, up to 150%.
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

  /// A Material 3 switch laid out with no padding and a shrink-wrapped
  /// target, at 100% text: its 52 by 32 dp track centred in a 40 dp tall
  /// box. Material's geometry, no token.
  static const Size _switchSize = Size(52, 40);

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final description = this.description;
    final onChanged = this.onChanged;
    final enabled = onChanged != null;
    // The row reaches into the gutter, so its control lines up with the
    // fields and headings around it (see MmTileBleed). It is a
    // SwitchListTile's row, built here so the switch can grow with the text:
    // its track ends on the content edge, drawn with no padding of its own,
    // and grows as icons do, up to 150%.
    final scale = MmTileBleed.scaleOf(context);
    final control = ExcludeFocus(
      child: SizedBox(
        width: _switchSize.width * scale,
        height: _switchSize.height * scale,
        // At the end edge even when the row's trailing slot is shorter
        // than the grown switch and it grows a little less.
        child: FittedBox(
          alignment: AlignmentDirectional.centerEnd,
          child: Switch(
            value: value,
            onChanged: onChanged,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
    return MmTileBleed(
      child: MmFocusWithin(
        radius: MmRadius.none,
        child: MergeSemantics(
          child: ListTile(
            // A switch row, as SwitchListTile builds it: the switch says
            // what the row is, so the row is not also announced a button.
            internalAddSemanticForOnTap: false,
            enabled: enabled,
            onTap: onChanged == null ? null : () => onChanged(!value),
            title: MmScriptText(
              label,
              style: text.bodyLarge!.copyWith(
                color: enabled ? colors.ink : colors.inkMuted,
              ),
            ),
            subtitle: description == null
                ? null
                : MmScriptText(
                    description,
                    style: text.bodyMedium!.copyWith(color: colors.inkMuted),
                  ),
            trailing: control,
          ),
        ),
      ),
    );
  }
}
