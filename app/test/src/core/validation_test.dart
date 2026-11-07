import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('required', () {
    expect(Validators.required(l10n, null), l10n.validationRequired);
    expect(Validators.required(l10n, '  '), l10n.validationRequired);
    expect(Validators.required(l10n, 'x'), isNull);
  });

  test('email', () {
    expect(Validators.email(l10n, ''), l10n.validationRequired);
    expect(Validators.email(l10n, null), l10n.validationRequired);
    for (final bad in ['ali', 'ali@', 'ali@example', 'a b@example.com']) {
      expect(Validators.email(l10n, bad), l10n.validationEmail, reason: bad);
    }
    expect(Validators.email(l10n, ' Ali.Raza+rent@Example.PK '), isNull);
  });

  test('new passwords follow the server rules', () {
    expect(Validators.newPassword(l10n, ''), l10n.validationRequired);
    for (final weak in [
      'Short1a',
      'alllowercase123',
      'ALLUPPERCASE123',
      'NoDigitsAtAllHere',
    ]) {
      expect(
        Validators.newPassword(l10n, weak),
        l10n.validationPassword,
        reason: weak,
      );
    }
    expect(Validators.newPassword(l10n, 'Rent2026ok'), isNull);
    expect(
      Validators.newPassword(l10n, 'Aa1${'x' * 70}'),
      l10n.validationTooLong(Validators.passwordMaxLength),
    );
  });

  test('repeated password', () {
    expect(Validators.repeatedPassword(l10n, '', 'a'), l10n.validationRequired);
    expect(
      Validators.repeatedPassword(l10n, 'b', 'a'),
      l10n.validationPasswordMismatch,
    );
    expect(Validators.repeatedPassword(l10n, 'a', 'a'), isNull);
  });

  test('names count characters as people see them, once tidied', () {
    expect(Validators.name(l10n, '  ', maxLength: 5), l10n.validationRequired);
    expect(Validators.name(l10n, '', maxLength: 5, required: false), isNull);
    expect(Validators.name(l10n, ' a   b ', maxLength: 3), isNull);
    expect(
      Validators.name(l10n, 'abcdef', maxLength: 5),
      l10n.validationTooLong(5),
    );
    // Four Urdu letters, however they are encoded, are four characters.
    expect(Validators.name(l10n, 'مکان', maxLength: 4), isNull);
  });
}
