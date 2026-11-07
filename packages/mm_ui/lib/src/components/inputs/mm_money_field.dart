import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/inputs/mm_input_editing.dart';
import 'package:mm_ui/src/components/inputs/mm_value_entry.dart';
import 'package:mm_ui/src/components/inputs/mm_value_field.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// A labelled field for a rupee amount: rent, a payment, a deposit.
///
/// The amount is grouped as it is typed, with the grouping the app set
/// (`MmFormats`: Western `125,000` or lakh/crore `1,25,000`), keeping the
/// caret beside the digit being edited. It takes Urdu digits and pasted
/// text such as "Rs 1,25,000" or "1.5 lakh", and shows the currency the
/// way the money format writes it: "Rs" before the amount in English,
/// "روپے" after it in Urdu, with the amount against it. Figures are
/// tabular in the Latin amount face, on one line that is never cut short:
/// at large text sizes a long amount is set only as much smaller as it
/// needs to fit. A screen reader hears the plain number and the currency
/// ("125000 rupees"), since grouped figures are read out unreliably, and
/// the currency's name while the field is empty.
///
/// [onChanged] receives the amount, or null while the field is empty or
/// the text is not an acceptable amount (more than two decimals, zero when
/// [allowZero] is false, above [max]); the text keeps what was typed, so
/// pass the matching [errorText], or check the amount in [validator].
///
/// The field takes amounts of zero or more, as people pay and are owed
/// them: [value] is never negative. Say a credit in words beside the
/// field instead of passing a negative amount.
///
/// For a number that is not money (a meter reading, a percentage), use
/// `MmTextField` with a number keyboard.
///
/// ```dart
/// MmMoneyField(
///   label: l10n.monthlyRent,
///   value: rent,
///   max: Money.fromRupees(10000000),
///   allowZero: false,
///   required: true,
///   errorText: rentError,
///   onChanged: (amount) => setState(() => rent = amount),
/// )
/// ```
class MmMoneyField extends StatelessWidget {
  /// Creates a money field labelled [label]. A field is not both
  /// [required] and [optional].
  const new({
    required this.label,
    required this.onChanged,
    this.value,
    this.max,
    this.allowZero = true,
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

  /// The amount shown; null for an empty field. Pass back what [onChanged]
  /// reports, or a new amount to replace the text. Never negative.
  final Money? value;

  /// Called whenever the amount changes: the amount, or null while the
  /// field is empty or not an acceptable amount.
  final ValueChanged<Money?> onChanged;

  /// The largest acceptable amount; larger amounts report null.
  final Money? max;

  /// Whether zero is an acceptable amount.
  final bool allowZero;

  /// Guidance shown below the field in muted ink.
  final String? helper;

  /// An error from outside the field, such as a server check ("More than the
  /// balance due"), shown below the field with the error icon at once, in place
  /// of [helper], and announced.
  ///
  /// While it is set it wins: [validator] is not called, and the field
  /// counts as invalid, so the enclosing `Form`'s `validate()` returns false.
  /// Typing does not clear it: set it back to null once the user changes
  /// what it is about (in [onChanged], say). The field then shows
  /// [validator]'s error again only when it next validates.
  final String? errorText;

  /// Checks the amount (null while the text is not an acceptable amount)
  /// when the enclosing `Form` validates, or as [autovalidateMode] says,
  /// and returns the error to show, or null.
  final FormFieldValidator<Money>? validator;

  /// The error shown when the field validates while it holds text that is not
  /// an amount, not nothing; [validator] is not asked then. Without it,
  /// [validator] gets null for such text, as for an empty field, so an optional
  /// field would take the mistake for no value.
  final String? invalidText;

  /// Called after every change of the text with the text and the value it
  /// stands for, so an empty field and one holding text that is not an amount
  /// can be told apart ([MmValueEntry.isEmpty], [MmValueEntry.isInvalid]).
  final ValueChanged<MmValueEntry<Money>>? onEntryChanged;

  /// When the field validates itself; by default only when the `Form`
  /// asks.
  final AutovalidateMode? autovalidateMode;

  /// Called with the amount (null when the text is not an acceptable
  /// amount) when the user submits from the keyboard.
  final ValueChanged<Money?>? onSubmitted;

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

  /// The amount a text in the field stands for, whatever the limits: the
  /// grouping commas dropped, a trailing decimal point ignored. Null when
  /// it is empty or has more than two decimals.
  static Money? _amountOf(String text) {
    final plain = text.replaceAll(',', '');
    if (plain.isEmpty) return null;
    return Money.tryParseDecimal(
      plain.endsWith('.') ? plain.substring(0, plain.length - 1) : plain,
    );
  }

  Money? _accept(String text) {
    final amount = _amountOf(text);
    if (amount == null) return null;
    if (!allowZero && amount.isZero) return null;
    if (max != null && amount > max!) return null;
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !(value?.isNegative ?? false),
      'MmMoneyField takes amounts of zero or more; say a credit in words.',
    );
    final app = MmFormats.moneyOf(context);
    // The field always writes the full amount with Western digits; only
    // the grouping and the currency's place follow the app's format.
    final plain = app.copyWith(
      notation: MoneyNotation.standard,
      paisa: PaisaDisplay.auto,
      nativeDigits: false,
    );
    final number = plain.copyWith(
      currency: CurrencyDisplay.none,
      language: MoneyLanguage.english,
    );
    final marked = plain.format(Money.zero);
    final zero = number.format(Money.zero);
    final at = marked.indexOf(zero);
    final before = marked.substring(0, at).trim();
    final after = marked.substring(at + zero.length).trim();
    final marker = before.isNotEmpty ? before : after;

    return MmValueField<Money>(
      label: label,
      value: value,
      onChanged: onChanged,
      parse: _accept,
      display: number.format,
      formatter: _MoneyInputFormatter(number),
      layout: number,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      describe: (context, text) {
        final amount = _amountOf(text);
        if (amount == null) return null;
        return MmFormats.spokenMoney(context, amount, format: plain);
      },
      style: context.mm.amount,
      // The marker is always visible, and hidden from assistive technology:
      // the amount is announced with the currency.
      marker: marker.isEmpty ? null : marker,
      markerLeading: before.isNotEmpty,
      unit: MmLocalizations.of(context).rupees,
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

/// Groups the digits of an amount as they are typed, keeping the caret
/// beside the digit being edited, and turns pasted text such as
/// "Rs 1,25,000" into the amount.
class _MoneyInputFormatter extends TextInputFormatter {
  const new(this.format);

  /// Writes amounts (number only, Western digits, the app's grouping).
  final MoneyFormat format;

  /// The integer digits the largest storable amount has.
  static final int _maxWholeDigits = '${Money.maxValue.wholeRupees}'.length;

  /// Text made only of what typing an amount produces.
  static final RegExp _typed = RegExp(r'^[0-9.,\s]*$');

  static bool _isSignificant(String character) =>
      isAsciiDigit(character) || character == '.';

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
    // Urdu and Arabic digits and separators become their ASCII forms
    // (one code unit for one, so the caret keeps its place).
    final text = normalizeDigits(edit.text)
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');

    if (!_typed.hasMatch(text)) {
      // Pasted words and markers: "Rs 1,25,000", "1.5 lakh".
      final pasted = parseMoneyInput(text);
      if (pasted == null) return oldValue;
      final shown = format.format(pasted);
      return TextEditingValue(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    }

    final kept = keepCharacters(
      edit.copyWith(text: text),
      (character, _) => _isSignificant(character),
    );
    var plain = kept.kept;
    var before = kept.before;
    if ('.'.allMatches(plain).length > 1) return oldValue;

    var zeros = 0;
    while (zeros + 1 < plain.length &&
        plain[zeros] == '0' &&
        plain[zeros + 1] != '.') {
      zeros++;
    }
    plain = plain.substring(zeros);
    before = before > zeros ? before - zeros : 0;
    if (plain.startsWith('.')) {
      plain = '0$plain';
      before++;
    }

    final point = plain.indexOf('.');
    final whole = point < 0 ? plain : plain.substring(0, point);
    if (whole.length > _maxWholeDigits) return oldValue;
    final shown =
        groupDigits(whole, format.grouping) +
        (point < 0 ? '' : plain.substring(point));
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(
        offset: offsetAfterKept(
          shown,
          before,
          isSeparator: (character) => character == ',',
        ),
      ),
    );
  }
}
