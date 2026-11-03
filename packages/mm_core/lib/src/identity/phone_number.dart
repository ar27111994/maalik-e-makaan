import 'package:meta/meta.dart';
import 'package:mm_core/src/text/digits.dart';

/// The kind of telephone number.
enum PhoneNumberType {
  /// A Pakistani mobile number (`03xx-xxxxxxx`).
  mobile,

  /// A Pakistani fixed-line, UAN or toll-free number.
  landline,

  /// A number outside Pakistan (e.g. an overseas landlord or tenant).
  international,
}

/// A validated telephone number stored in E.164 form (`+923001234567`).
///
/// Parsing accepts every way Pakistani users write numbers — `0300-1234567`,
/// `0300 123 4567`, `3001234567`, `+92 300 1234567`, `0092300…`, `92300…` and
/// Urdu digits — and normalises them to one canonical value so that duplicate
/// detection, WhatsApp links and database uniqueness all work reliably.
@immutable
final class PhoneNumber {
  const new _(this.e164, this.type);

  /// Restores a number previously produced by [PhoneNumber.e164] (e.g. from
  /// the database). Throws a [FormatException] if it is not valid.
  factory fromE164(String e164) {
    final parsed = tryParse(e164);
    if (parsed == null || parsed.e164 != e164) {
      throw FormatException('Not a canonical E.164 phone number', e164);
    }
    return parsed;
  }

  /// Pakistan's international dialling code.
  static const String pakistanCountryCode = '92';

  /// Parses user input, returning `null` when it is not a plausible number.
  static PhoneNumber? tryParse(String input) {
    final trimmed = normalizeDigits(input).trim();
    if (trimmed.isEmpty) return null;
    // Only digits, spaces and the usual punctuation are allowed.
    if (!RegExp(r'^[+0-9\s().\-/]+$').hasMatch(trimmed)) return null;
    final hasPlus = trimmed.startsWith('+');
    if (trimmed.lastIndexOf('+') > 0) return null;
    var digits = digitsOnly(trimmed);
    if (digits.isEmpty) return null;

    if (hasPlus) {
      return _fromInternational(digits);
    }
    if (digits.startsWith('00')) {
      return _fromInternational(digits.substring(2));
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
      return _fromPakistaniNational(digits);
    }
    if (digits.startsWith(pakistanCountryCode) && digits.length == 12) {
      return _fromPakistaniNational(digits.substring(2));
    }
    if (digits.startsWith('3') && digits.length == 10) {
      return _fromPakistaniNational(digits);
    }
    return null;
  }

  static PhoneNumber? _fromInternational(String digits) {
    if (digits.startsWith(pakistanCountryCode)) {
      return _fromPakistaniNational(digits.substring(2));
    }
    // E.164 allows at most 15 digits; country codes never start with 0.
    if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) {
      return null;
    }
    return PhoneNumber._('+$digits', PhoneNumberType.international);
  }

  /// [nsn] is the national significant number (no trunk prefix 0).
  static PhoneNumber? _fromPakistaniNational(String nsn) {
    if (nsn.isEmpty || nsn.startsWith('0')) return null;
    if (nsn.startsWith('3')) {
      // Mobile: 3XX + 7 digits. Mobile number portability means the prefix no
      // longer identifies the operator, so every 3XX prefix is accepted.
      if (nsn.length != 10) return null;
      return PhoneNumber._('+92$nsn', PhoneNumberType.mobile);
    }
    // Fixed line (area code + subscriber), UAN (111-…) and toll-free (800-…).
    if (nsn.length < 8 || nsn.length > 11) return null;
    return PhoneNumber._('+92$nsn', PhoneNumberType.landline);
  }

  /// Canonical E.164 form, e.g. `+923001234567`.
  final String e164;

  /// Mobile, landline or international.
  final PhoneNumberType type;

  /// Whether this is a Pakistani mobile number (WhatsApp-capable in practice).
  bool get isMobile => type == PhoneNumberType.mobile;

  /// Whether this number is in Pakistan.
  bool get isPakistani => type != PhoneNumberType.international;

  /// Whether a Pakistani mobile number uses one of the allocated operator
  /// prefixes (300–349 and SCO's 355). Other `3XX` prefixes are accepted but
  /// the UI shows a soft warning, since a typo is more likely than a new
  /// allocation. Always `true` for non-mobile numbers.
  bool get hasKnownMobilePrefix {
    if (type != PhoneNumberType.mobile) return true;
    final prefix = int.parse(e164.substring(3, 6));
    return (prefix >= 300 && prefix <= 349) || prefix == 355;
  }

  /// The number without the leading `+`, as used by `wa.me` links.
  String get digits => e164.substring(1);

  /// Local format: `0300 1234567` for mobiles, `042123456789` for landlines;
  /// international numbers keep the E.164 form.
  String get national {
    switch (type) {
      case PhoneNumberType.mobile:
        final nsn = e164.substring(3);
        return '0${nsn.substring(0, 3)} ${nsn.substring(3)}';
      case PhoneNumberType.landline:
        return '0${e164.substring(3)}';
      case PhoneNumberType.international:
        return e164;
    }
  }

  /// International format: `+92 300 1234567` for Pakistani mobiles.
  String get international {
    if (type == PhoneNumberType.mobile) {
      final nsn = e164.substring(3);
      return '+92 ${nsn.substring(0, 3)} ${nsn.substring(3)}';
    }
    if (type == PhoneNumberType.landline) return '+92 ${e164.substring(3)}';
    return e164;
  }

  /// A `tel:` URI for dialling.
  Uri get telUri => Uri(scheme: 'tel', path: e164);

  @override
  bool operator ==(Object other) => other is PhoneNumber && other.e164 == e164;

  @override
  int get hashCode => e164.hashCode;

  @override
  String toString() => e164;
}
