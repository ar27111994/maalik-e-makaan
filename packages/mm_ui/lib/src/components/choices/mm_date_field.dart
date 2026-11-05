import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';
import 'package:mm_ui/src/components/choices/mm_choice_frame.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';

/// A field for one calendar date: a lease's start, a rent due date, the
/// day a payment was received.
///
/// The date is shown read-only in the app's language with its year
/// ("Nov 5, 2026", "5 نومبر، 2026"), and announced in full with its
/// weekday. Tapping the field or its calendar button, or pressing Enter or
/// Space while it has focus, opens the Material date picker limited to
/// [firstDate]..[lastDate]; the picker opens on the chosen date, or on
/// today in Pakistan. An [optional] field with a date also shows a clear
/// button. Focus returns to the field when the picker or the clear button
/// is done.
///
/// The label sits above the field, helper or error text below it, as for
/// text fields. Dates travel as [CalendarDate] (no time of day, no time
/// zone); see [toDateTime] and [toCalendarDate] for how they meet the
/// picker's [DateTime]s without drifting a day.
///
/// Use it for a single date. For a month (a rent period), offer the months
/// in an `MmSelectField`; for typing a date, use a text field.
///
/// ```dart
/// MmDateField(
///   label: l10n.leaseStart,
///   value: leaseStart,
///   firstDate: CalendarDate(2020, 1, 1),
///   lastDate: CalendarDate(2030, 12, 31),
///   required: true,
///   onChanged: (date) => setState(() => leaseStart = date),
/// )
/// ```
class MmDateField extends StatefulWidget {
  /// Creates a date field named [label] showing [value].
  const new({
    required this.label,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.value,
    this.helper,
    this.errorText,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// The chosen date; null shows the field empty.
  final CalendarDate? value;

  /// Called with the date the landlord picks, or with null when an
  /// [optional] field is cleared. Not called when the picker is dismissed
  /// or the same date is picked again.
  final ValueChanged<CalendarDate?> onChanged;

  /// The earliest date the picker offers.
  final CalendarDate firstDate;

  /// The latest date the picker offers; not before [firstDate].
  final CalendarDate lastDate;

  /// Shown below the field in muted ink.
  final String? helper;

  /// Shown below the field instead of [helper], with the error icon; the
  /// outline turns overdue.
  final String? errorText;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional"; an optional field with a date shows
  /// a clear button.
  final bool optional;

  /// Whether the field can be changed.
  final bool enabled;

  /// [date] as the [DateTime] Material's date pickers work in: local
  /// midnight at the start of that day. Built from the date's fields, so
  /// no time-zone conversion can move it to a neighbouring day.
  static DateTime toDateTime(CalendarDate date) =>
      DateTime(date.year, date.month, date.day);

  /// The calendar date of [dateTime] as its own fields give it (the
  /// picker's local midnight, or a UTC midnight from
  /// `CalendarDate.toDateTimeUtc`), without converting between time zones.
  static CalendarDate toCalendarDate(DateTime dateTime) =>
      CalendarDate(dateTime.year, dateTime.month, dateTime.day);

  @override
  State<MmDateField> createState() => _MmDateFieldState();
}

class _MmDateFieldState extends State<MmDateField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'MmDateField');

  /// The calendar button repeats what the field does, so keyboard users
  /// reach the picker from the field and Tab skips the button.
  final FocusNode _calendarFocusNode = FocusNode(
    debugLabel: 'MmDateField calendar',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    _calendarFocusNode.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final first = widget.firstDate;
    final last = widget.lastDate;
    final today = CalendarDate.todayInPakistan();
    final initial = CalendarDate.max(
      first,
      CalendarDate.min(last, widget.value ?? today),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: MmDateField.toDateTime(initial),
      firstDate: MmDateField.toDateTime(first),
      lastDate: MmDateField.toDateTime(last),
      currentDate: MmDateField.toDateTime(today),
      helpText: widget.label,
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (picked == null) return;
    final date = MmDateField.toCalendarDate(picked);
    if (date != widget.value) widget.onChanged(date);
  }

  void _clear() {
    widget.onChanged(null);
    // The clear button goes away with the date; keep focus in the field.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.firstDate.isOnOrBefore(widget.lastDate),
      'MmDateField: firstDate (${widget.firstDate}) is after lastDate '
      '(${widget.lastDate}).',
    );
    final strings = MmLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final value = widget.value;
    final enabled = widget.enabled;
    final date = value == null ? null : MmDateField.toDateTime(value);
    return MmChoiceFrame(
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText,
      required: widget.required,
      optional: widget.optional,
      enabled: enabled,
      child: MmChoiceBox(
        label: widget.label,
        text: date == null ? null : material.formatShortDate(date),
        semanticValue: date == null ? null : material.formatFullDate(date),
        hasError: widget.errorText != null,
        required: widget.required,
        optional: widget.optional,
        focusNode: _focusNode,
        onTap: enabled ? _choose : null,
        actions: [
          if (widget.optional && value != null && enabled)
            IconButton(
              tooltip: strings.clearText,
              onPressed: _clear,
              icon: const Icon(MmIcons.close),
            ),
          IconButton(
            tooltip: strings.chooseDate,
            focusNode: _calendarFocusNode,
            onPressed: enabled ? _choose : null,
            icon: const Icon(MmIcons.calendar),
          ),
        ],
      ),
    );
  }
}
