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
/// wider windows they wrap onto as many lines as they need. To let the
/// scrolling row run to the screen's edges, place it without the page's
/// side margins and pass them as [padding]: the first chip then lines up
/// with the page's content, and the others scroll in from the edge.
///
/// Disabled (a null [onChanged]), the chips sit on sunken paper in muted
/// ink, still readable, and take no taps or focus.
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
///   padding: const EdgeInsetsDirectional.symmetric(
///     horizontal: MmSpace.s4,
///   ),
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
    this.padding = EdgeInsetsDirectional.zero,
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

  /// Space around the chips, inside the row: the page's side margins when
  /// the scrolling row runs to the screen's edges.
  final EdgeInsetsGeometry padding;

  Set<T> _toggled(T value) {
    final wasSelected = selected.contains(value);
    if (!multiSelect) return wasSelected ? <T>{} : {value};
    return wasSelected ? ({...selected}..remove(value)) : {...selected, value};
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final onChanged = this.onChanged;
    final chips = [
      for (final option in options)
        _chip(
          context.mm,
          option,
          enabled: onChanged != null,
          selected: selected.contains(option.value),
          count: option.count == null
              ? null
              : material.formatDecimal(option.count!),
          onSelected: onChanged == null
              ? _inert
              : (_) => onChanged(_toggled(option.value)),
        ),
    ];
    if (MmWindowSize.of(context).atLeast(MmWindowSize.medium)) {
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: MmSpace.s2,
          runSpacing: MmSpace.s2,
          children: chips,
        ),
      );
    }
    // A focused, selected chip draws its ring outside itself: the row
    // clips the scrolling chips that far past its edges, not at them.
    return ClipRect(
      clipper: const _RingRoom(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: padding,
        child: Row(spacing: MmSpace.s2, children: chips),
      ),
    );
  }

  /// What a disabled chip does when selected: nothing. Material fades a
  /// chip without a handler to 38% (under 3:1), so a disabled row keeps
  /// its chips enabled for painting, styles them as disabled, and takes
  /// their taps, focus and semantics away.
  static void _inert(bool selected) {}

  Widget _chip(
    MmSemantics mm,
    MmFilterOption<T> option, {
    required bool enabled,
    required bool selected,
    required String? count,
    required ValueChanged<bool> onSelected,
  }) {
    final colors = mm.colors;
    // Chip labels stay on one line, so the count never wraps away. The
    // count is set like an amount, in the Latin face in both languages;
    // a label typed in Latin script (a city, a property) is too.
    final suffix = count == null ? null : ' · $count';
    final label = count == null ? option.label : '${option.label} $count';
    final chip = FilterChip(
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
        semanticsLabel: label,
      ),
      selected: selected,
      showCheckmark: false,
      avatar: selected
          ? Icon(MmIcons.check, color: enabled ? null : colors.inkMuted)
          : null,
      backgroundColor: enabled ? null : colors.surfaceSunken,
      selectedColor: enabled ? null : colors.surfaceSunken,
      side: enabled ? null : BorderSide(color: colors.rule),
      labelStyle: enabled ? null : TextStyle(color: colors.inkMuted),
      onSelected: onSelected,
    );
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: multiSelect ? null : true,
        child: enabled
            ? chip
            : Semantics(
                button: true,
                enabled: false,
                selected: selected,
                label: label,
                child: ExcludeSemantics(
                  child: ExcludeFocus(child: IgnorePointer(child: chip)),
                ),
              ),
      ),
    );
  }
}

/// The scrolling row's clip: its own bounds and the reach of a focus ring
/// drawn outside a chip (the gap and the ring) beyond them.
class _RingRoom extends CustomClipper<Rect> {
  const new();

  @override
  Rect getClip(Size size) =>
      (Offset.zero & size).inflate(MmSize.focusGap + MmSize.focusRing);

  @override
  bool shouldReclip(_RingRoom oldClipper) => false;
}
