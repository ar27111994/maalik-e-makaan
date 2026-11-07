import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';
import 'package:mm_ui/src/components/choices/mm_choice_frame.dart';
import 'package:mm_ui/src/components/choices/mm_option.dart';
import 'package:mm_ui/src/components/choices/mm_search_field.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_modal_sheet.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A field that picks one of a list of [options]: the property a tenant
/// rents in, the unit, the month a payment is for.
///
/// The field shows the chosen option's label (and icon), or [placeholder]
/// in muted ink. Tapping it, or pressing Enter or Space while it has
/// focus, opens a bottom sheet titled with [label], with a close button,
/// that lists the options; the chosen one carries a check mark, not colour
/// alone. With more than eight options the sheet starts with a search
/// field that filters the labels as the landlord types (ignoring case, and
/// reading Urdu digits as Western ones). Choosing an option closes the
/// sheet and focus returns to the field.
///
/// The label sits above the field, helper or error text below it, as for
/// text fields. Use it for a handful to a few dozen options. For two to
/// five options that are worth seeing at once, use an `MmRadioGroup` or a
/// segmented control; to filter a list, use `MmFilterChips`.
///
/// ```dart
/// MmSelectField<String>(
///   label: l10n.property,
///   placeholder: l10n.chooseProperty,
///   options: [
///     for (final property in properties)
///       MmOption(value: property.id, label: property.name),
///   ],
///   value: propertyId,
///   required: true,
///   onChanged: (id) => setState(() => propertyId = id),
/// )
/// ```
class MmSelectField<T> extends StatefulWidget {
  /// Creates a field named [label] choosing among [options].
  const new({
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.helper,
    this.errorText,
    this.required = false,
    this.optional = false,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// More options than this give the sheet a search field.
  static const searchThreshold = 8;

  /// The field's name, shown above it, announced as its accessible name,
  /// and the title of the sheet.
  final String label;

  /// The options, in the order the sheet lists them.
  final List<MmOption<T>> options;

  /// The value of the chosen option; null, or a value no option has, shows
  /// the field empty.
  final T? value;

  /// Called with the value of the option the landlord chooses (not when
  /// the chosen one is chosen again, or the sheet is dismissed). When null
  /// the field is disabled.
  final ValueChanged<T>? onChanged;

  /// Shown in the field in muted ink while nothing is chosen ("Choose a
  /// property").
  final String? placeholder;

  /// Shown below the field in muted ink.
  final String? helper;

  /// Shown below the field instead of [helper], with the error icon; the
  /// outline turns overdue.
  final String? errorText;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  @override
  State<MmSelectField<T>> createState() => _MmSelectFieldState<T>();
}

class _MmSelectFieldState<T> extends State<MmSelectField<T>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'MmSelectField');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    // A record, so an option whose value is null is not mistaken for the
    // sheet being dismissed.
    final chosen = await showMmModalSheet<(T,)>(
      context,
      builder: (context) => _SelectSheet<T>(
        title: widget.label,
        options: widget.options,
        value: widget.value,
      ),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    final onChanged = widget.onChanged;
    if (chosen == null || onChanged == null) return;
    final (value,) = chosen;
    if (value != widget.value) onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final selected = widget.options
        .where((option) => option.value == value)
        .firstOrNull;
    final enabled = widget.onChanged != null;
    return MmChoiceFrame(
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText,
      required: widget.required,
      optional: widget.optional,
      enabled: enabled,
      child: MmChoiceBox(
        label: widget.label,
        text: selected?.label,
        placeholder: widget.placeholder,
        leading: selected?.icon,
        trailing: MmIcons.expand,
        hasError: widget.errorText != null,
        required: widget.required,
        optional: widget.optional,
        focusNode: _focusNode,
        onTap: enabled ? _choose : null,
      ),
    );
  }
}

/// The sheet of an [MmSelectField]: its title and close button, a search
/// field when there are many options, and the options, the chosen one
/// checked and focused.
class _SelectSheet<T> extends StatefulWidget {
  const new({required this.title, required this.options, required this.value});

  final String title;
  final List<MmOption<T>> options;
  final T? value;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  /// The search, normalised: lower case, Western digits, trimmed.
  String _query = '';

  /// Marks the chosen option's row, to scroll it into view.
  final GlobalKey _selectedKey = GlobalKey(debugLabel: 'chosen option');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row != null) Scrollable.ensureVisible(row, alignment: 0.5);
    });
  }

  static String _normalise(String text) =>
      normalizeDigits(text).trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final searchable = widget.options.length > MmSelectField.searchThreshold;
    final matches = [
      for (final option in widget.options)
        if (_normalise(option.label).contains(_query)) option,
    ];
    final textTheme = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    // When some options have icons, every row keeps the icon's place, so
    // the labels line up.
    final icons = widget.options.any((option) => option.icon != null);
    const inset = EdgeInsetsDirectional.symmetric(horizontal: MmSpace.s4);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmSheetHeader(title: widget.title),
            if (searchable)
              Padding(
                padding: inset.add(
                  const EdgeInsetsDirectional.only(top: MmSpace.s3),
                ),
                child: MmSearchField(
                  onChanged: (query) =>
                      setState(() => _query = _normalise(query)),
                ),
              ),
            const SizedBox(height: MmSpace.s2),
            if (matches.isEmpty)
              Padding(
                padding: inset.add(
                  const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s4),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    MmLocalizations.of(context).noMatches,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in matches)
                      _OptionRow<T>(
                        key: option.value == widget.value ? _selectedKey : null,
                        option: option,
                        selected: option.value == widget.value,
                        iconSlot: icons,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: MmSpace.s4),
          ],
        ),
      ),
    );
  }
}

/// One option in the sheet: a row that closes the sheet with its value.
class _OptionRow<T> extends StatelessWidget {
  const new({
    required this.option,
    required this.selected,
    required this.iconSlot,
    super.key,
  });

  final MmOption<T> option;
  final bool selected;

  /// Whether the row keeps an icon's place before its label, with or
  /// without an icon of its own.
  final bool iconSlot;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final textTheme = Theme.of(context).textTheme;
    final icon = option.icon;
    final description = option.description;
    final colors = mm.colors;
    final ink = selected ? colors.onPrimaryContainer : colors.ink;
    final muted = selected ? colors.onPrimaryContainer : colors.inkMuted;
    final iconSize = MmIconLabel.scaledSize(context, MmSize.iconLg);
    return MmFocusWithin(
      radius: MmRadius.none,
      child: MergeSemantics(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          child: ListTile(
            selected: selected,
            autofocus: selected,
            selectedColor: ink,
            leading: icon != null
                ? Icon(icon, size: iconSize)
                : (iconSlot ? SizedBox.square(dimension: iconSize) : null),
            title: Text(
              option.label,
              style: mm.styleFor(
                option.label,
                textTheme.bodyLarge!.copyWith(color: ink),
              ),
            ),
            subtitle: description == null
                ? null
                : Text(
                    description,
                    style: mm.styleFor(
                      description,
                      textTheme.bodyMedium!.copyWith(color: muted),
                    ),
                  ),
            trailing: selected
                ? Icon(MmIcons.check, size: iconSize, color: ink)
                : null,
            onTap: () => Navigator.pop(context, (option.value,)),
          ),
        ),
      ),
    );
  }
}
