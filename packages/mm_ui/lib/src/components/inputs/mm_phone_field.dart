import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/inputs/mm_input_editing.dart';
import 'package:mm_ui/src/components/inputs/mm_value_entry.dart';
import 'package:mm_ui/src/components/inputs/mm_value_field.dart';

/// A labelled field for a phone number, Pakistani first.
///
/// It takes the number however people write it (`0300 1234567`,
/// `+92 300 1234567`, `0092300…`, Urdu digits) and shows the national
/// format as it is typed: a space after the mobile prefix
/// (`0300 1234567`), landlines as one run of digits. A complete Pakistani
/// number written another way becomes national; numbers abroad keep their
/// `+` and country code. The number is set in the Latin face in both
/// languages, on one line that is never cut short (at large text sizes it
/// is set only as much smaller as it needs to fit), read out digit by
/// digit, and offered to autofill.
///
/// [onChanged] receives the number (E.164 inside, `+923001234567`) once it
/// is a plausible one, and null until then: null both while the field is
/// empty and while it holds a typo. An optional field tells them apart with
/// [invalidText] (the error a `Form` shows for a typo) or [onEntryChanged]
/// ([MmValueEntry.isInvalid]), so a mistyped number is never saved as "no
/// phone".
///
/// For other numbers people type (a bank account, a meter number), use
/// `MmTextField` with a number keyboard.
///
/// ```dart
/// MmPhoneField(
///   label: l10n.tenantPhone,
///   value: phone,
///   optional: true,
///   invalidText: l10n.phoneNotValid,
///   onChanged: (phone) => setState(() => this.phone = phone),
/// )
/// ```
class MmPhoneField extends StatelessWidget {
  /// Creates a phone field labelled [label]. A field is not both
  /// [required] and [optional].
  const new({
    required this.label,
    required this.onChanged,
    this.value,
    this.helper,
    this.errorText,
    this.validator,
    this.invalidText,
    this.onEntryChanged,
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

  /// The number shown, in its national format; null for an empty field.
  /// Pass back what [onChanged] reports, or a new number to replace the
  /// text.
  final PhoneNumber? value;

  /// Called whenever the number changes: the number, or null while the
  /// text is not a plausible one.
  final ValueChanged<PhoneNumber?> onChanged;

  /// Guidance shown below the field in muted ink.
  final String? helper;

  /// An error from outside the field, such as a server check ("This number
  /// belongs to another tenant"), shown below the field with the error icon at
  /// once, in place of [helper], and announced.
  ///
  /// While it is set it wins: [validator] is not called, and the field
  /// counts as invalid, so the enclosing `Form`'s `validate()` returns false.
  /// Typing does not clear it: set it back to null once the user changes
  /// what it is about (in [onChanged], say). The field then shows
  /// [validator]'s error again only when it next validates.
  final String? errorText;

  /// Checks the number (null while the text is not a plausible one) when
  /// the enclosing `Form` validates, or as [autovalidateMode] says, and
  /// returns the error to show, or null.
  final FormFieldValidator<PhoneNumber>? validator;

  /// The error shown when the field validates while it holds a mistyped or
  /// unfinished number, not nothing; [validator] is not asked then. Without it,
  /// [validator] gets null for such text, as for an empty field, so an optional
  /// field would take the mistake for no value.
  final String? invalidText;

  /// Called after every change of the text with the text and the value it
  /// stands for, so an empty field and one holding a mistyped or unfinished
  /// number can be told apart ([MmValueEntry.isEmpty],
  /// [MmValueEntry.isInvalid]).
  final ValueChanged<MmValueEntry<PhoneNumber>>? onEntryChanged;

  /// When the field validates itself; by default only when the `Form`
  /// asks.
  final AutovalidateMode? autovalidateMode;

  /// Called with the number (null when the text is not one) when the user
  /// submits from the keyboard.
  final ValueChanged<PhoneNumber?>? onSubmitted;

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
    return MmValueField<PhoneNumber>(
      label: label,
      value: value,
      onChanged: onChanged,
      parse: PhoneNumber.tryParse,
      display: (phone) => phone.national,
      formatter: const _PhoneInputFormatter(),
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      spellOut: true,
      helper: helper,
      errorText: errorText,
      validator: validator,
      invalidText: invalidText,
      onEntryChanged: onEntryChanged,
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

/// Lays a phone number out as it is typed: Pakistani numbers in the
/// national format, others as `+` and digits.
class _PhoneInputFormatter extends TextInputFormatter {
  const new();

  /// Digits in a Pakistani mobile number written nationally (`03001234567`).
  static const _mobileDigits = 11;

  /// Most digits in any Pakistani number written nationally: the trunk
  /// `0` and up to 11 more.
  static const _nationalDigits = 12;

  /// Most digits in an international number (E.164).
  static const _internationalDigits = 15;

  static bool _isSignificant(String character) =>
      isAsciiDigit(character) || character == '+';

  static bool _isSpace(String character) => character == ' ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final edit = deleteThroughSeparator(
      oldValue,
      newValue,
      isSignificant: _isSignificant,
    );
    final text = normalizeDigits(edit.text);
    final lead = text.indexOf(RegExp(r'\S'));
    // Digits, and a plus only where it starts the number.
    final kept = keepCharacters(
      edit.copyWith(text: text),
      (character, index) =>
          isAsciiDigit(character) || (character == '+' && index == lead),
    );
    final number = kept.kept;
    final plus = number.startsWith('+');
    final digits = plus ? number.substring(1) : number;
    final national =
        !plus && digits.startsWith('0') && !digits.startsWith('00');

    if (!national) {
      final parsed = PhoneNumber.tryParse(number);
      if (parsed != null && parsed.isPakistani) {
        // A complete Pakistani number written another way: show it the way
        // it is written at home.
        return _collapsed(parsed.national);
      }
      final limit = digits.startsWith('00')
          ? _internationalDigits + 2
          : _internationalDigits;
      if (digits.length > limit) return oldValue;
      return _laidOut(number, kept.before);
    }

    final mobile = digits.startsWith('03');
    if (digits.length > (mobile ? _mobileDigits : _nationalDigits)) {
      return oldValue;
    }
    final shown = mobile && digits.length > 4
        ? '${digits.substring(0, 4)} ${digits.substring(4)}'
        : digits;
    return _laidOut(shown, kept.before);
  }

  static TextEditingValue _laidOut(String shown, int before) =>
      TextEditingValue(
        text: shown,
        selection: TextSelection.collapsed(
          offset: offsetAfterKept(shown, before, isSeparator: _isSpace),
        ),
      );

  static TextEditingValue _collapsed(String shown) => TextEditingValue(
    text: shown,
    selection: TextSelection.collapsed(offset: shown.length),
  );
}
