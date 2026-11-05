import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_window.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One chip of an [MmFilterChips]: the [value] the list is filtered by, its
/// [label], and optionally how many items it matches.
@immutable
class MmFilterOption<T> {
  /// Creates the chip for [value], shown as [label] and [count].
  const new({required this.value, required this.label, this.count});

  /// The value reported while the chip is selected.
  final T value;

  /// The filter's name ("Overdue").
  final String label;

  /// How many items the filter matches, shown after the label ("Overdue ·
  /// 3"); null shows no count.
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is MmFilterOption<T> &&
      other.value == value &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(value, label, count);
}

/// A row of filter chips above a list: tenants who are overdue, paid or
/// due soon; properties in Lahore or Karachi.
///
/// Each chip toggles its filter; a selected chip is filled and carries a
/// check mark, so the choice does not rest on colour alone. A count
/// ([MmFilterOption.count]) follows the label ("Overdue · 3"). With
/// [multiSelect] off, choosing a chip deselects the others, and choosing
/// the selected chip clears the filter.
///
/// On phones (compact windows) the chips stay on one line and the row
/// scrolls sideways, so large text never squeezes them; on medium and
/// wider windows they wrap onto as many lines as they need.
///
/// Use it to narrow a list the landlord is looking at. To choose a value
/// for a form, use an `MmSelectField`, an `MmRadioGroup` or checkboxes.
///
/// ```dart
/// MmFilterChips<RentStatus>(
///   options: [
///     MmFilterOption(value: RentStatus.overdue, label: l10n.overdue,
///         count: 3),
///     MmFilterOption(value: RentStatus.dueSoon, label: l10n.dueSoon,
///         count: 5),
///     MmFilterOption(value: RentStatus.paid, label: l10n.paid, count: 12),
///   ],
///   selected: filters,
///   onChanged: (filters) => setState(() => this.filters = filters),
/// )
/// ```
class MmFilterChips<T> extends StatelessWidget {
  /// Creates a row of chips for [options], with [selected] selected.
  const new({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = true,
    super.key,
  });

  /// The chips, in reading order.
  final List<MmFilterOption<T>> options;

  /// The values of the selected chips.
  final Set<T> selected;

  /// Called with the new set of selected values when a chip is toggled.
  /// When null every chip is disabled.
  final ValueChanged<Set<T>>? onChanged;

  /// Whether several chips can be selected at once; when false, selecting
  /// a chip deselects the others.
  final bool multiSelect;

  Set<T> _toggled(T value) {
    final wasSelected = selected.contains(value);
    if (!multiSelect) return wasSelected ? <T>{} : {value};
    return wasSelected ? ({...selected}..remove(value)) : {...selected, value};
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final colors = context.mm.colors;
    final onChanged = this.onChanged;
    final side = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: colors.rule);
      }
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colors.focus, width: MmSize.focusRing);
      }
      // Muted ink rather than the field outline: a chip's border runs as
      // close to its label as the label's own strokes, and the thin
      // strokes of Nastaliq must not read fainter than the frame around
      // them.
      return BorderSide(
        color: states.contains(WidgetState.selected)
            ? colors.primary
            : colors.inkMuted,
      );
    });
    final chips = [
      for (final option in options)
        _chip(
          context.mm,
          option,
          selected: selected.contains(option.value),
          count: option.count == null
              ? null
              : material.formatDecimal(option.count!),
          side: side,
          onSelected: onChanged == null
              ? null
              : (_) => onChanged(_toggled(option.value)),
        ),
    ];
    if (MmWindowSize.of(context).atLeast(MmWindowSize.medium)) {
      return Wrap(spacing: MmSpace.s2, runSpacing: MmSpace.s2, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: MmSpace.s2, children: chips),
    );
  }

  Widget _chip(
    MmSemantics mm,
    MmFilterOption<T> option, {
    required bool selected,
    required String? count,
    required WidgetStateBorderSide side,
    required ValueChanged<bool>? onSelected,
  }) {
    // Chip labels stay on one line, so the count never wraps away. The
    // count is set like an amount, in the Latin face in both languages;
    // a label typed in Latin script (a city, a property) is too.
    final suffix = count == null ? null : ' · $count';
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: multiSelect ? null : true,
        child: FilterChip(
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: option.label,
                  style: mm.styleFor(option.label, const TextStyle()),
                ),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: mm.styleFor(suffix, const TextStyle()),
                  ),
              ],
            ),
            semanticsLabel: count == null
                ? option.label
                : '${option.label} $count',
          ),
          selected: selected,
          showCheckmark: false,
          avatar: selected ? const Icon(MmIcons.check) : null,
          side: side,
          // Room above and below the label for the tall strokes of
          // Nastaliq; Latin labels stay within the standard 32 dp chip.
          labelPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: MmSpace.s2,
            vertical: MmSpace.s1,
          ),
          onSelected: onSelected,
        ),
      ),
    );
  }
}
