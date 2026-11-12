import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';
import 'package:mm_ui/src/components/choices/mm_choice_frame.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A whole number nudged up or down within limits: the months of advance
/// rent, the number of rooms in a unit, the reminder days before the due
/// date.
///
/// The value sits in the middle of a field-shaped box, with a minus button
/// at the start and a plus button at the end that move it by [step]; each
/// button is disabled at its limit ([min], [max]), its sign turning from
/// ink to muted ink. When the button with keyboard focus reaches its
/// limit, focus moves to the other one.
///
/// Assistive technology hears the value as an adjustable element named
/// [label] (swipe up or down to change it), and the two buttons by
/// [decreaseLabel] and [increaseLabel]. The label sits above the box and
/// [helper] below it, as for text fields.
///
/// Use it for small counts where most changes are a step or two. For
/// amounts of money or long numbers, use a text field.
///
/// ```dart
/// MmStepperField(
///   label: l10n.advanceMonths,
///   value: months,
///   min: 0,
///   max: 12,
///   decreaseLabel: l10n.fewerMonths,
///   increaseLabel: l10n.moreMonths,
///   format: l10n.monthCount,
///   onChanged: (value) => setState(() => months = value),
/// )
/// ```
class MmStepperField extends StatefulWidget {
  /// Creates a stepper named [label] showing [value] within [min]..[max].
  const new({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.step = 1,
    this.helper,
    this.format,
    super.key,
  }) : assert(min <= max, 'min must not be greater than max.'),
       assert(step > 0, 'step must be positive.'),
       assert(value >= min && value <= max, 'value must be within min..max.');

  /// The field's name, shown above it and announced as the value's name.
  final String label;

  /// The current value, within [min]..[max].
  final int value;

  /// The smallest value; the minus button is disabled there.
  final int min;

  /// The largest value; the plus button is disabled there.
  final int max;

  /// How far one press moves the value (never past [min] or [max]).
  final int step;

  /// Called with the new value when a button is pressed or the value is
  /// adjusted by assistive technology. When null the field is disabled.
  final ValueChanged<int>? onChanged;

  /// The minus button's tooltip and accessible name ("Fewer months").
  final String decreaseLabel;

  /// The plus button's tooltip and accessible name ("More months").
  final String increaseLabel;

  /// Shown below the field in muted ink.
  final String? helper;

  /// The words for a value ("3 months"); defaults to the number in the
  /// app's number format.
  final String Function(int value)? format;

  /// Whether the value is also said in the accessible name ("Grace days,
  /// 5 days"). True on the web: Flutter's web engine renders the adjustable
  /// value as `<input type="range">`, leaves the value out of its name and
  /// means to set `aria-valuetext`, but sets neither it nor `aria-valuenow`
  /// until the value first changes (Flutter 3.47), so a screen reader heard
  /// only "Grace days, slider" (docs/uat.md, D7). Elsewhere TalkBack and
  /// VoiceOver read the name and the value apart.
  @visibleForTesting
  static bool nameCarriesValue = kIsWeb;

  @override
  State<MmStepperField> createState() => _MmStepperFieldState();
}

class _MmStepperFieldState extends State<MmStepperField> {
  final FocusNode _decreaseFocus = FocusNode(debugLabel: 'MmStepperField -');
  final FocusNode _increaseFocus = FocusNode(debugLabel: 'MmStepperField +');

  @override
  void dispose() {
    _decreaseFocus.dispose();
    _increaseFocus.dispose();
    super.dispose();
  }

  int get _lower => math.max(widget.min, widget.value - widget.step);
  int get _higher => math.min(widget.max, widget.value + widget.step);

  /// Reports [next]; if the button that had focus ([from]) is disabled by
  /// the change, gives focus to the other one ([to]) so keyboard users keep
  /// their place.
  void _change(int next, {required FocusNode from, required FocusNode to}) {
    final hadFocus = from.hasFocus;
    widget.onChanged!(next);
    if (!hadFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !from.canRequestFocus) to.requestFocus();
    });
  }

  void _decrease() => _change(_lower, from: _decreaseFocus, to: _increaseFocus);

  void _increase() =>
      _change(_higher, from: _increaseFocus, to: _decreaseFocus);

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final textTheme = Theme.of(context).textTheme;
    final material = MaterialLocalizations.of(context);
    String format(int value) =>
        widget.format?.call(value) ?? material.formatDecimal(value);
    final enabled = widget.onChanged != null;
    final canDecrease = enabled && widget.value > widget.min;
    final canIncrease = enabled && widget.value < widget.max;
    final shown = format(widget.value);
    final ink = enabled ? colors.ink : colors.inkMuted;
    // The signs are ink while they can be pressed, so a button at its
    // limit (muted ink) stands apart from the other.
    final buttonStyle = MmChoiceBox.buttonStyle(context, color: colors.ink);
    // Figures are set in the Latin face with tabular figures, like amounts;
    // words in Urdu stay in the Urdu face.
    final style = MmSemantics.hasArabicScript(shown)
        ? textTheme.titleMedium!.copyWith(color: ink)
        : mm.amount.copyWith(color: ink);
    return MmChoiceFrame(
      label: widget.label,
      helper: widget.helper,
      enabled: enabled,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.sm)),
          side: BorderSide(color: enabled ? colors.outline : colors.rule),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MmSize.fieldHeight),
          child: Row(
            children: [
              const SizedBox(width: MmSpace.s1),
              IconButton(
                focusNode: _decreaseFocus,
                tooltip: widget.decreaseLabel,
                style: buttonStyle,
                onPressed: canDecrease ? _decrease : null,
                icon: const Icon(MmIcons.minus),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  enabled: enabled,
                  label: MmStepperField.nameCarriesValue
                      ? '${widget.label}, $shown'
                      : widget.label,
                  value: shown,
                  increasedValue: canIncrease ? format(_higher) : null,
                  decreasedValue: canDecrease ? format(_lower) : null,
                  onIncrease: canIncrease ? _increase : null,
                  onDecrease: canDecrease ? _decrease : null,
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: MmSpace.s3),
                      child: Text(
                        shown,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                focusNode: _increaseFocus,
                tooltip: widget.increaseLabel,
                style: buttonStyle,
                onPressed: canIncrease ? _increase : null,
                icon: const Icon(MmIcons.add),
              ),
              const SizedBox(width: MmSpace.s1),
            ],
          ),
        ),
      ),
    );
  }
}
