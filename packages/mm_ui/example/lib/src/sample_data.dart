import 'package:flutter/widgets.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';

/// Words in both of the gallery's languages.
typedef Words = ({String en, String ur});

/// Picks the wording for the gallery's language.
extension WordsIn on Words {
  String of(BuildContext context) => context.tr(en, ur);
}

/// A sample tenant. Every name, CNIC and phone number here is made up; the
/// CNICs follow the real 5-7-1 format with Lahore (352xx) and Karachi
/// (42xxx) district codes, and the phone numbers use the 555 exchange.
final class SampleTenant {
  const new({
    required this.name,
    required this.unit,
    required this.property,
    required this.rent,
    required this.status,
    required this.statusLabel,
    required this.cnic,
    required this.phone,
    required this.score,
  });

  final Words name;
  final Words unit;
  final Words property;
  final Money rent;
  final MmStatus status;
  final Words statusLabel;
  final String cnic;
  final String phone;
  final int score;

  Cnic get parsedCnic => Cnic.parse(cnic);
  PhoneNumber get parsedPhone => PhoneNumber.tryParse(phone)!;
}

const tenants = [
  SampleTenant(
    name: (en: 'Ali Raza', ur: 'علی رضا'),
    unit: (en: 'Flat 3, Gulberg III, Lahore', ur: 'فلیٹ 3، گلبرگ III، لاہور'),
    property: (en: 'Raza Manzil', ur: 'رضا منزل'),
    rent: Money.fromRupees(45000),
    status: MmStatus.paid,
    statusLabel: (en: 'Paid', ur: 'ادا شدہ'),
    cnic: '35202-4817263-5',
    phone: '0321-5550147',
    score: 92,
  ),
  SampleTenant(
    name: (en: 'Ayesha Khan', ur: 'عائشہ خان'),
    unit: (
      en: 'House 12, Street 4, DHA Phase 5, Lahore',
      ur: 'مکان 12، گلی 4، ڈی ایچ اے فیز 5، لاہور',
    ),
    property: (en: 'Gulberg Heights', ur: 'گلبرگ ہائٹس'),
    rent: Money.fromRupees(125000),
    status: MmStatus.overdue,
    statusLabel: (en: 'Overdue 12 days', ur: '12 دن سے واجب الادا'),
    cnic: '35201-6620418-4',
    phone: '0300-5550192',
    score: 41,
  ),
  SampleTenant(
    name: (en: 'Bilal Ahmed', ur: 'بلال احمد'),
    unit: (en: 'Shop 7, Tariq Road, Karachi', ur: 'دکان 7، طارق روڈ، کراچی'),
    property: (en: 'Tariq Road Arcade', ur: 'طارق روڈ آرکیڈ'),
    rent: Money.fromRupees(60000),
    status: MmStatus.dueSoon,
    statusLabel: (en: 'Due in 3 days', ur: '3 دن میں واجب'),
    cnic: '42201-3398021-7',
    phone: '0333-5550318',
    score: 68,
  ),
  SampleTenant(
    name: (en: 'Fatima Siddiqui', ur: 'فاطمہ صدیقی'),
    unit: (
      en: 'Flat 5B, Clifton Block 2, Karachi',
      ur: 'فلیٹ 5 بی، کلفٹن بلاک 2، کراچی',
    ),
    property: (en: 'Clifton Residency', ur: 'کلفٹن ریزیڈنسی'),
    rent: Money.fromRupees(38000),
    status: MmStatus.credit,
    statusLabel: (en: 'Advance Rs 15,000', ur: 'پیشگی 15,000 روپے'),
    cnic: '42101-7754210-2',
    phone: '0345-5550466',
    score: 88,
  ),
  SampleTenant(
    name: (en: 'Usman Tariq', ur: 'عثمان طارق'),
    unit: (
      en: 'Upper portion, Model Town, Lahore',
      ur: 'اوپری پورشن، ماڈل ٹاؤن، لاہور',
    ),
    property: (en: 'Model Town Residence', ur: 'ماڈل ٹاؤن ریزیڈنس'),
    rent: Money.fromRupees(52000),
    status: MmStatus.neutral,
    statusLabel: (en: 'Moving out', ur: 'مکان خالی کر رہے ہیں'),
    cnic: '35202-9902137-1',
    phone: '0302-5550583',
    score: 75,
  ),
];

/// Short month names, January first.
const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Urdu month names, January first.
const _monthsUr = [
  'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', //
  'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
];

/// [month] (1 to 12) as the gallery's language writes it: "Oct", "اکتوبر".
String monthName(BuildContext context, int month) =>
    context.tr(_monthsEn[month - 1], _monthsUr[month - 1]);

/// [date] the way Pakistani receipts write it: "5 Oct 2026", "5 اکتوبر 2026".
String dateLabel(BuildContext context, CalendarDate date) =>
    '${date.day} ${monthName(context, date.month)} ${date.year}';

/// [amount] in the gallery's money format ("Rs 45,000"), with no-break
/// spaces so the currency never ends a line apart from its number.
String money(BuildContext context, Money amount) =>
    MmFormats.moneyOf(context).format(amount).replaceAll(' ', ' ');

/// [amount] as screen readers should hear it ("45000 rupees").
String spoken(BuildContext context, Money amount) =>
    MmFormats.spokenMoney(context, amount);
