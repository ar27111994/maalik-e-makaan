import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/choices/mm_focus_ring.dart';
import 'package:mm_ui/src/components/choices/mm_option.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One of a few exclusive options, all in view, under a [label]: how a
/// payment was received, which day rent falls due, who pays the
/// electricity bill.
///
/// Each option is a row with its radio button at the start, its label and
/// an optional description, and its icon at the end; the whole row is the
/// target. The chosen option's button is filled, not only coloured. From
/// the keyboard, Tab enters the group at the chosen option, the arrow keys
/// move the choice, and Space chooses the focused option.
///
/// Assistive technology hears the group as a radio group named [label],
/// and each row as one radio button with its checked state.
///
/// Use it for two to about six options that deserve to be compared side by
/// side. For more, or when space is short, use an `MmSelectField`; for
/// switching views, a segmented control.
///
/// ```dart
/// MmRadioGroup<PaymentMethod>(
///   label: l10n.receivedBy,
///   options: [
///     MmOption(value: PaymentMethod.cash, label: l10n.cash),
///     MmOption(value: PaymentMethod.bank, label: l10n.bankTransfer),
///   ],
///   value: method,
///   onChanged: (method) => setState(() => this.method = method),
/// )
/// ```
class MmRadioGroup<T> extends StatelessWidget {
  /// Creates a group named [label] choosing among [options].
  const new({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The group's name, shown above the options and announced as the
  /// group's name.
  final String label;

  /// The options, in reading order.
  final List<MmOption<T>> options;

  /// The value of the chosen option; null (or a value no option has)
  /// leaves every option unchosen.
  final T? value;

  /// Called with the value of the option the landlord chooses. When null
  /// the group is disabled.
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    return RadioGroup<T>(
      groupValue: value,
      // RadioGroup needs a handler; a disabled group's rows cannot be
      // chosen, so its handler is never called.
      onChanged: onChanged ?? (_) {},
      // Inside the group's own semantics node, so the label names it.
      child: Semantics(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: MmSpace.s4,
                  end: MmSpace.s4,
                  bottom: MmSpace.s1,
                ),
                child: Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    color: enabled ? colors.ink : colors.inkMuted,
                  ),
                ),
              ),
            ),
            for (final option in options)
              MmFocusRing(
                radius: MmRadius.none,
                child: RadioListTile<T>(
                  value: option.value,
                  enabled: enabled,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    option.label,
                    style: mm.styleFor(
                      option.label,
                      text.bodyLarge!.copyWith(
                        color: enabled ? colors.ink : colors.inkMuted,
                      ),
                    ),
                  ),
                  subtitle: option.description == null
                      ? null
                      : Text(
                          option.description!,
                          style: mm.styleFor(
                            option.description!,
                            text.bodyMedium!.copyWith(color: colors.inkMuted),
                          ),
                        ),
                  secondary: option.icon == null
                      ? null
                      : Icon(
                          option.icon,
                          size: MmSize.iconLg,
                          color: colors.inkMuted,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
