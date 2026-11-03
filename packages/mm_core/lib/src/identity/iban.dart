import 'package:meta/meta.dart';
import 'package:mm_core/src/text/digits.dart';

/// A validated International Bank Account Number.
///
/// Pakistani IBANs are 24 characters: `PK`, two check digits, a four-letter
/// bank code and a 16-character account identifier, e.g.
/// `PK36 SCBL 0000 0011 2345 6702`. Validation follows ISO 13616: structure
/// plus the MOD-97-10 checksum, so typos are caught before a tenant is asked
/// to transfer rent to the wrong account.
@immutable
final class Iban {
  const new _(this.value);

  /// Restores a canonical IBAN (e.g. from the database). Throws a
  /// [FormatException] when invalid.
  factory parse(String input, {bool allowForeign = false}) {
    final parsed = tryParse(input, allowForeign: allowForeign);
    if (parsed == null) throw FormatException('Invalid IBAN', input);
    return parsed;
  }

  /// Parses user input (spaces, dashes, lower case and Urdu digits are
  /// accepted). Returns `null` when the structure or checksum is invalid.
  ///
  /// Only Pakistani IBANs are accepted unless [allowForeign] is `true`.
  static Iban? tryParse(String input, {bool allowForeign = false}) {
    final compact = normalizeDigits(input)
        .replaceAll(RegExp(r'[\s\-]'), '')
        .toUpperCase();
    if (compact.length < 15 || compact.length > 34) return null;
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(compact)) return null;
    final country = compact.substring(0, 2);
    if (country == 'PK') {
      if (!RegExp(r'^PK\d{2}[A-Z]{4}[A-Z0-9]{16}$').hasMatch(compact)) {
        return null;
      }
    } else if (!allowForeign) {
      return null;
    }
    if (!hasValidChecksum(compact)) return null;
    return Iban._(compact);
  }

  /// Whether [iban] (compact, upper case) satisfies the MOD-97-10 check.
  static bool hasValidChecksum(String iban) {
    if (iban.length < 5) return false;
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      final String chunk;
      if (unit >= 0x30 && unit <= 0x39) {
        chunk = String.fromCharCode(unit);
      } else if (unit >= 0x41 && unit <= 0x5A) {
        chunk = (unit - 0x41 + 10).toString();
      } else {
        return false;
      }
      for (final digit in chunk.codeUnits) {
        remainder = (remainder * 10 + (digit - 0x30)) % 97;
      }
    }
    return remainder == 1;
  }

  /// Compact, upper-case IBAN without spaces.
  final String value;

  /// ISO 3166-1 alpha-2 country code.
  String get countryCode => value.substring(0, 2);

  /// The four-letter bank code for Pakistani IBANs, otherwise `null`.
  String? get bankCode => countryCode == 'PK' ? value.substring(4, 8) : null;

  /// The bank's name when the bank code is recognised.
  String? get bankName => pakistaniBankNames[bankCode];

  /// Printed form in groups of four characters.
  String get formatted {
    final groups = <String>[];
    for (var i = 0; i < value.length; i += 4) {
      groups.add(
        value.substring(i, i + 4 > value.length ? value.length : i + 4),
      );
    }
    return groups.join(' ');
  }

  /// The IBAN with the account digits hidden except the last four, for
  /// display on shared screens and receipts.
  String get masked {
    final visibleTail = value.substring(value.length - 4);
    final hidden = value.length - 8;
    final maskedValue = value.substring(0, 4) + ('•' * hidden) + visibleTail;
    final groups = <String>[];
    for (var i = 0; i < maskedValue.length; i += 4) {
      final end = i + 4 > maskedValue.length ? maskedValue.length : i + 4;
      groups.add(maskedValue.substring(i, end));
    }
    return groups.join(' ');
  }

  @override
  bool operator ==(Object other) => other is Iban && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => formatted;
}

/// Well-known Pakistani bank codes (characters 5–8 of a PK IBAN, which are
/// the first four letters of the bank's SWIFT/BIC code).
const Map<String, String> pakistaniBankNames = {
  'ABPA': 'Allied Bank',
  'ALFH': 'Bank Alfalah',
  'ASCM': 'Askari Bank',
  'BAHL': 'Bank AL Habib',
  'BKIP': 'BankIslami',
  'BPUN': 'The Bank of Punjab',
  'DUIB': 'Dubai Islamic Bank',
  'FAYS': 'Faysal Bank',
  'HABB': 'HBL',
  'JSBL': 'JS Bank',
  'KHYB': 'The Bank of Khyber',
  'MEZN': 'Meezan Bank',
  'MPBL': 'Habib Metropolitan Bank',
  'MUCB': 'MCB Bank',
  'NBPA': 'National Bank of Pakistan',
  'SCBL': 'Standard Chartered',
  'SIND': 'Sindh Bank',
  'SONE': 'Soneri Bank',
  'UNIL': 'UBL',
};
