import 'package:meta/meta.dart';
import 'package:mm_core/src/text/digits.dart';

/// The region encoded in the first digit of a CNIC.
///
/// NADRA's published structure: 1 Khyber Pakhtunkhwa, 2 the former FATA,
/// 3 Punjab, 4 Sindh, 5 Balochistan, 6 Islamabad Capital Territory,
/// 7 Gilgit-Baltistan, 8 Azad Jammu & Kashmir.
enum CnicRegion {
  /// Khyber Pakhtunkhwa (1).
  khyberPakhtunkhwa(1),

  /// Former Federally Administered Tribal Areas (2).
  formerFata(2),

  /// Punjab (3).
  punjab(3),

  /// Sindh (4).
  sindh(4),

  /// Balochistan (5).
  balochistan(5),

  /// Islamabad Capital Territory (6).
  islamabad(6),

  /// Gilgit-Baltistan (7).
  gilgitBaltistan(7),

  /// Azad Jammu & Kashmir (8).
  azadKashmir(8);

  new(this.code);

  /// The leading digit.
  final int code;

  /// The region for a leading [digit], or `null` when unknown.
  static CnicRegion? fromDigit(int digit) {
    for (final region in values) {
      if (region.code == digit) return region;
    }
    return null;
  }
}

/// A Computerised National Identity Card number (also used by NICOP).
///
/// Stored as exactly 13 ASCII digits and displayed as `XXXXX-XXXXXXX-X`.
/// NADRA publishes no checksum algorithm, so validation is structural only.
///
/// Deliberately, this type does **not** expose a gender derived from the last
/// digit: inferring gender is unnecessary for renting, error-prone and
/// disrespectful to people whose card does not match that assumption.
@immutable
final class Cnic {
  const new _(this.digits);

  /// Parses [input]; throws a [FormatException] when invalid.
  factory parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) throw FormatException('Invalid CNIC', input);
    return parsed;
  }

  /// Number of digits in a CNIC.
  static const int length = 13;

  static final RegExp _allowed = RegExp(r'^[0-9\s\-]+$');

  /// Parses user input such as `35202-1234567-1`, `3520212345671` or the
  /// same with Urdu digits/spaces. Returns `null` when the input is not 13
  /// digits, contains other characters, or is an obvious placeholder
  /// (all zeros or a single repeated digit).
  static Cnic? tryParse(String input) {
    final normalized = normalizeDigits(input).trim();
    if (normalized.isEmpty || !_allowed.hasMatch(normalized)) return null;
    final digits = digitsOnly(normalized);
    if (digits.length != length) return null;
    if (RegExp(r'^(\d)\1{12}$').hasMatch(digits)) return null;
    if (digits.startsWith('0')) return null;
    // When dashes are used they must be in the official positions.
    if (normalized.contains('-') &&
        !RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(normalized.replaceAll(' ', ''))) {
      return null;
    }
    return Cnic._(digits);
  }

  /// The 13 digits without separators.
  final String digits;

  /// `XXXXX-XXXXXXX-X`.
  String get formatted =>
      '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits[12]}';

  /// Privacy-preserving form for lists and shared screens:
  /// `35202-•••••••-1`.
  String get masked => '${digits.substring(0, 5)}-•••••••-${digits[12]}';

  /// The region from the first digit, or `null` for an unexpected digit
  /// (the UI warns but does not block, since NADRA may add codes).
  CnicRegion? get region => CnicRegion.fromDigit(int.parse(digits[0]));

  /// Whether the leading digit is one of NADRA's known region codes.
  bool get hasKnownRegion => region != null;

  @override
  bool operator ==(Object other) => other is Cnic && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => masked;
}
