import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:mm_core/mm_core.dart';

/// Checks forms run before sending anything, so people learn what to fix
/// next to the field. Each returns the message to show, or null when the
/// value is fine. The server checks again and has the last word.
abstract final class Validators {
  /// The shortest password Supabase Auth accepts
  /// (`supabase/config.toml`: `minimum_password_length`).
  static const passwordMinLength = 10;

  /// The longest password Supabase Auth hashes (bcrypt reads 72 bytes).
  static const passwordMaxLength = 72;

  static final _lower = RegExp('[a-z]');
  static final _upper = RegExp('[A-Z]');
  static final _digit = RegExp('[0-9]');

  /// Something must be typed.
  static String? required(AppLocalizations l10n, String? value) =>
      (value ?? '').trim().isEmpty ? l10n.validationRequired : null;

  /// A plausible e-mail address.
  static String? email(AppLocalizations l10n, String? value) {
    if ((value ?? '').trim().isEmpty) return l10n.validationRequired;
    return EmailAddress.tryParse(value!) == null ? l10n.validationEmail : null;
  }

  /// A new password that meets Supabase Auth's rules
  /// (`password_requirements = "lower_upper_letters_digits"`), so the
  /// server does not refuse it after the form is sent.
  static String? newPassword(AppLocalizations l10n, String? value) {
    final password = value ?? '';
    if (password.isEmpty) return l10n.validationRequired;
    if (password.length > passwordMaxLength) {
      return l10n.validationTooLong(passwordMaxLength);
    }
    final strong =
        password.length >= passwordMinLength &&
        _lower.hasMatch(password) &&
        _upper.hasMatch(password) &&
        _digit.hasMatch(password);
    return strong ? null : l10n.validationPassword;
  }

  /// The same password typed again.
  static String? repeatedPassword(
    AppLocalizations l10n,
    String? value,
    String password,
  ) {
    if ((value ?? '').isEmpty) return l10n.validationRequired;
    return value == password ? null : l10n.validationPasswordMismatch;
  }

  /// A name of at most [maxLength] characters once tidied
  /// (`sanitizeSingleLine`, as it is saved).
  static String? name(
    AppLocalizations l10n,
    String? value, {
    required int maxLength,
    bool required = true,
  }) {
    final tidy = sanitizeSingleLine(value ?? '');
    if (tidy.isEmpty) return required ? l10n.validationRequired : null;
    return tidy.characters.length > maxLength
        ? l10n.validationTooLong(maxLength)
        : null;
  }
}
