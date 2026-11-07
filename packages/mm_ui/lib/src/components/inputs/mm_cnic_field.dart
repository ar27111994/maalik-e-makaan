import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/inputs/mm_input_editing.dart';
import 'package:mm_ui/src/components/inputs/mm_value_field.dart';

/// A labelled field for a CNIC (Computerised National Identity Card)
/// number.
///
/// It takes digits only (Urdu digits become Western ones), inserts the
/// dashes as the digits are typed (`35202-1234567-1`) and stops at 13
/// digits, keeping the caret beside the digit being edited. The number is
/// set in the Latin face in both languages, on one line that is never cut
/// short (at large text sizes it is set only as much smaller as it needs
/// to fit), and read out digit by digit.
///
/// [onChanged] receives the CNIC once the 13 digits make a valid number,
/// and null until then (and whenever it stops being one).
///
/// To show a saved CNIC, use `MmCnicText`, which masks it.
///
/// ```dart
/// MmCnicField(
///   label: l10n.tenantCnic,
///   value: cnic,
///   required: true,
///   helper: l10n.cnicHelp,
///   onChanged: (cnic) => setState(() => this.cnic = cnic),
/// )
/// ```
class MmCnicField extends StatelessWidget {
  /// Creates a CNIC field labelled [label]. A field is not both [required]
  /// and [optional].
  const new({
    required this.label,
    required this.onChanged,
    this.value,
    this.helper,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.onSubmitted,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// The CNIC shown; null for an empty field. Pass back what [onChanged]
  /// reports, or a new CNIC to replace the text.
  final Cnic? value;

  /// Called whenever the CNIC changes: the CNIC, or null while the digits
  /// do not make a valid one.
  final ValueChanged<Cnic?> onChanged;

  /// Guidance shown below the field in muted ink.
  final String? helper;

  /// Shown below the field with the error icon while set; it wins over
  /// [validator]'s error.
  final String? errorText;

  /// Checks the CNIC (null while the digits do not make a valid one) when
  /// the enclosing `Form` validates, or as [autovalidateMode] says, and
  /// returns the error to show, or null.
  final FormFieldValidator<Cnic>? validator;

  /// When the field validates itself; by default only when the `Form`
  /// asks.
  final AutovalidateMode? autovalidateMode;

  /// Called with the CNIC (null when the text is not one) when the user
  /// submits from the keyboard.
  final ValueChanged<Cnic?>? onSubmitted;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Whether the field accepts input.
  final bool enabled;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// The keyboard's action button (next, done).
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return MmValueField<Cnic>(
      label: label,
      value: value,
      onChanged: onChanged,
      parse: Cnic.tryParse,
      display: (cnic) => cnic.formatted,
      formatter: const _CnicInputFormatter(),
      keyboardType: TextInputType.number,
      spellOut: true,
      helper: helper,
      errorText: errorText,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onSubmitted: onSubmitted,
      required: required,
      optional: optional,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
    );
  }
}

/// Keeps the digits of a CNIC and lays them out as `#####-#######-#`.
class _CnicInputFormatter extends TextInputFormatter {
  const new();

  static bool _isDash(String character) => character == '-';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final edit = deleteThroughSeparator(
      oldValue,
      newValue,
      isSignificant: isAsciiDigit,
    );
    final kept = keepCharacters(
      edit.copyWith(text: normalizeDigits(edit.text)),
      (character, _) => isAsciiDigit(character),
    );
    final digits = kept.kept;
    if (digits.length > Cnic.length) return oldValue;
    final shown = switch (digits.length) {
      <= 5 => digits,
      <= 12 => '${digits.substring(0, 5)}-${digits.substring(5)}',
      _ =>
        '${digits.substring(0, 5)}-${digits.substring(5, 12)}-'
            '${digits.substring(12)}',
    };
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(
        offset: offsetAfterKept(shown, kept.before, isSeparator: _isDash),
      ),
    );
  }
}
