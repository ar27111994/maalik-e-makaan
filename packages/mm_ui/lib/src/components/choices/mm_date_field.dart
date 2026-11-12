import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';
import 'package:mm_ui/src/components/choices/mm_choice_frame.dart';
import 'package:mm_ui/src/foundation/mm_date_locale.dart';
import 'package:mm_ui/src/foundation/mm_urdu_material_localizations.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// A field for one calendar date: a lease's start, a rent due date, the
/// day a payment was received.
///
/// The date is shown read-only in the app's language with its year, the
/// day first as Pakistan writes it ("5 Nov 2026", "5 نومبر، 2026"; see
/// `MmDateLocale`), and announced in full with its weekday. Tapping the
/// field or its calendar button, or pressing Enter or Space while it has
/// focus, opens the Material date picker limited to
/// [firstDate]..[lastDate], in the same conventions (typed as dd/mm/yyyy,
/// weeks from Sunday); the picker opens on the chosen date, or on today in
/// Pakistan. An [optional] field with a date also shows a clear button.
/// Focus returns to the field when the picker or the clear button is done.
///
/// The picker's text grows with the landlord's text size only up to
/// [pickerTextScale]: Material lays the picker out in fixed slots (seven
/// day columns, a month label beside the arrows, a header of fixed
/// height), and beyond that size its month names are cut short and its
/// Urdu header overflows on a 320 dp phone. The field itself grows to
/// 200% and more.
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

  /// The largest text scale the date picker is drawn at: the largest, in
  /// steps of 5%, at which it fits a 320 dp wide phone in English and in
  /// Urdu, in its calendar and its typing mode (the tests open it there at
  /// 200% and check that no text is cut). At 110% "September 2026" no
  /// longer fits beside the month arrows, and at 115% the Urdu header
  /// outgrows its fixed height.
  static const pickerTextScale = 1.05;

  /// How wide a column of days is in the date picker on a window [width]
  /// wide: Material's dialog stands 16 dp in from each side, is at most
  /// 328 dp wide, and pads its grid of seven columns 12 dp on each side.
  static double _dayColumnWidth(double width) =>
      (math.min(width - 2 * _pickerInset, _pickerMaxWidth) -
          2 * _pickerGridPadding) /
      DateTime.daysPerWeek;

  /// Material's geometry of the date picker dialog, no tokens.
  static const double _pickerInset = 16;
  static const double _pickerMaxWidth = 328;
  static const double _pickerGridPadding = 12;

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

  /// Opens the picker from [dates], a context inside the field's
  /// [MmDateLocale], so the picker takes its date conventions (and, in
  /// Urdu, its day names) from there.
  Future<void> _choose(BuildContext dates) async {
    final first = widget.firstDate;
    final last = widget.lastDate;
    final today = CalendarDate.todayInPakistan();
    final initial = CalendarDate.max(
      first,
      CalendarDate.min(last, widget.value ?? today),
    );
    final strings = MmLocalizations.of(context);
    final picked = await showDatePicker(
      context: dates,
      locale: MmDateLocale.forLocale(Localizations.localeOf(context)),
      initialDate: MmDateField.toDateTime(initial),
      firstDate: MmDateField.toDateTime(first),
      lastDate: MmDateField.toDateTime(last),
      currentDate: MmDateField.toDateTime(today),
      helpText: widget.label,
      cancelText: strings.cancel,
      confirmText: strings.chooseDate,
      switchToInputEntryModeIcon: const Icon(MmIcons.edit),
      switchToCalendarEntryModeIcon: const Icon(MmIcons.calendar),
      builder: (context, picker) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: MmDateField.pickerTextScale,
        child: _withDayNames(context, picker!),
      ),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (picked == null) return;
    final date = MmDateField.toCalendarDate(picked);
    if (date != widget.value) widget.onChanged(date);
  }

  /// [picker], with its Urdu day names over the columns in the Urdu UI's
  /// smallest text (the theme sets the English initials in the figures'
  /// style).
  ///
  /// Seven columns share the picker's width: 43 dp each on a 360 dp phone
  /// and 38 dp on a 320 dp one, and "جمعرات" at 13 px is 43 dp, so it would
  /// break inside the word. The row's text is set only as much smaller as
  /// the longest name needs to fit its column whole with a pixel to spare:
  /// 1% smaller on a 360 dp phone, 13% on a 320 dp one.
  static Widget _withDayNames(BuildContext context, Widget picker) {
    if (context.mm.script != MmScript.urdu) return picker;
    final theme = DatePickerTheme.of(context);
    final small = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: theme.weekdayStyle?.color);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: MmDateField.pickerTextScale);
    final column = MmDateField._dayColumnWidth(
      MediaQuery.sizeOf(context).width,
    );
    final widest = MmUrduMaterialLocalizations.dayNames
        .map((name) {
          final painter = TextPainter(
            text: TextSpan(text: name, style: small),
            textDirection: TextDirection.rtl,
            textScaler: scaler,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        })
        .reduce(math.max);
    // A pixel to spare, so rounding never pushes the name onto two lines.
    final fit = math.min(1, (column - 1) / widest);
    return DatePickerTheme(
      data: theme.copyWith(
        weekdayStyle: small.copyWith(fontSize: small.fontSize! * fit),
      ),
      child: picker,
    );
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
    // Formatted in Pakistan's conventions: the day before the month.
    return MmDateLocale(child: Builder(builder: _buildField));
  }

  Widget _buildField(BuildContext context) {
    final strings = MmLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = context.mm.colors;
    final value = widget.value;
    final enabled = widget.enabled;
    final date = value == null ? null : MmDateField.toDateTime(value);
    // Icons inside a field are muted ink in every state, as in text
    // fields: the field's own outline and text say it is disabled.
    final buttonStyle = MmChoiceBox.buttonStyle(
      context,
      color: colors.inkMuted,
    );
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
        latinFigures: true,
        focusNode: _focusNode,
        onTap: enabled ? () => _choose(context) : null,
        actions: [
          if (widget.optional && value != null && enabled)
            IconButton(
              tooltip: strings.clearText,
              style: buttonStyle,
              onPressed: _clear,
              icon: const Icon(MmIcons.close),
            ),
          IconButton(
            tooltip: strings.chooseDate,
            style: buttonStyle,
            focusNode: _calendarFocusNode,
            onPressed: enabled ? () => _choose(context) : null,
            icon: const Icon(MmIcons.calendar),
          ),
        ],
      ),
    );
  }
}
