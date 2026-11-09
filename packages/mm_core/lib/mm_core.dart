/// Pure-Dart domain layer for Maalik-e-Makaan.
///
/// Everything here is free of Flutter and I/O so it can be unit tested
/// exhaustively and reused by every layer of the app:
///
/// * **Money** – exact rupee/paisa arithmetic, Pakistani formatting
///   (Western or lakh/crore grouping, English or Urdu) and lenient parsing
///   of typed amounts.
/// * **Time** – date-only values, months, Pakistan's July–June tax year and
///   date ranges, all evaluated in Pakistan Standard Time.
/// * **Identity** – CNIC, phone number, IBAN and e-mail value objects.
/// * **Text** – sanitisation against control/bidi spoofing characters and
///   Urdu digit normalisation.
/// * **Rent & ledger** – proration, increments, late fees, oldest-first
///   payment allocation.
library;

export 'src/identity/cnic.dart';
export 'src/identity/email_address.dart';
export 'src/identity/iban.dart';
export 'src/identity/phone_number.dart';
export 'src/ledger/allocation.dart';
export 'src/money/basis_points.dart';
export 'src/money/money.dart' hide divideRounded;
export 'src/money/money_format.dart';
export 'src/money/money_parse.dart';
export 'src/rent/late_fee_policy.dart';
export 'src/rent/rent_math.dart';
export 'src/text/digits.dart';
export 'src/text/sanitize.dart';
export 'src/time/calendar_date.dart';
export 'src/time/date_range.dart';
export 'src/time/month_period.dart';
export 'src/time/tax_year.dart';
