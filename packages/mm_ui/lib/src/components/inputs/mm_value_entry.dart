import 'package:flutter/foundation.dart';

/// What a value field (`MmMoneyField`, `MmCnicField`, `MmPhoneField`)
/// holds: the [text] as typed and the [value] it stands for.
///
/// A field's `onChanged` reports only the value, which is null both for an
/// empty field and for one holding a typo or an unfinished number. An
/// optional field must tell the two apart, or a mistyped phone number is
/// saved as "no phone": read [isEmpty] and [isInvalid] from the field's
/// `onEntryChanged`, or give the field an `invalidText` to show when the
/// enclosing `Form` validates.
///
/// ```dart
/// MmPhoneField(
///   label: l10n.tenantPhone,
///   optional: true,
///   value: phone,
///   onChanged: (phone) => setState(() => this.phone = phone),
///   onEntryChanged: (entry) => phoneIsTypo = entry.isInvalid,
///   invalidText: l10n.phoneNotValid,
/// )
/// ```
@immutable
final class MmValueEntry<T extends Object> {
  /// Describes a field holding [text], which stands for [value] (null when
  /// it stands for none).
  const new({required this.text, required this.value});

  /// The text as typed, laid out as the field shows it.
  final String text;

  /// The value [text] stands for, or null when it stands for none: the
  /// field is empty, or its text is not a value.
  final T? value;

  /// Whether the field holds no text (spaces alone count as none).
  bool get isEmpty => text.trim().isEmpty;

  /// Whether the text stands for a value.
  bool get isValid => value != null;

  /// Whether the field holds text that does not stand for a value: a typo
  /// or an unfinished number, not an empty field.
  bool get isInvalid => !isEmpty && value == null;

  @override
  bool operator ==(Object other) =>
      other is MmValueEntry<T> && other.text == text && other.value == value;

  @override
  int get hashCode => Object.hash(text, value);

  @override
  String toString() => 'MmValueEntry("$text", $value)';
}
