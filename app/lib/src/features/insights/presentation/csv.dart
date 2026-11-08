import 'dart:convert';
import 'dart:typed_data';

import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:mm_core/mm_core.dart';

/// One cell of a CSV file: text (the landlord's words, the app's words,
/// dates) or a number the app wrote itself.
sealed class CsvCell {
  const new();

  /// [text], guarded against formula injection when written.
  const factory text(String text) = _Text;

  /// [amount] as a plain decimal ("45000.00"), which spreadsheets read as
  /// a number.
  factory money(Money amount) => _Number(amount.toDecimalString());

  /// [date] as `YYYY-MM-DD`, which spreadsheets read as a date.
  factory date(CalendarDate date) => _Text(date.toIso());

  /// An empty cell.
  static const CsvCell empty = _Text('');

  /// The cell as written into the file.
  String get written;
}

final class _Text extends CsvCell {
  const new(this.text);

  final String text;

  /// What makes a spreadsheet read a cell as a formula (OWASP's CSV
  /// injection list): a leading `=`, `+`, `-` or `@`, or a tab or carriage
  /// return before one.
  static final RegExp _formula = RegExp(r'^[\t\r]*[=+\-@]|^[\t\r]');

  @override
  String get written => _formula.hasMatch(text) ? "'$text" : text;
}

final class _Number extends CsvCell {
  const new(this.number);

  final String number;

  @override
  String get written => number;
}

/// [rows] as a CSV file (RFC 4180, lines ending in CRLF), in UTF-8 with a
/// byte-order mark so spreadsheet apps read Urdu correctly, every text
/// cell guarded against formula injection (RPT-03).
Uint8List csvBytes(List<List<CsvCell>> rows) {
  final buffer = StringBuffer('\uFEFF');
  for (final row in rows) {
    buffer
      ..writeAll(row.map((cell) => _quoted(cell.written)), ',')
      ..write('\r\n');
  }
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

/// [field] quoted when it holds a comma, a quote, a line break or space
/// at either end; quotes inside are doubled.
String _quoted(String field) {
  final needs =
      field.contains(RegExp('[",\r\n]')) || field.trim().length != field.length;
  return needs ? '"${field.replaceAll('"', '""')}"' : field;
}

String _yes(AppLocalizations l10n, bool value) => value ? l10n.csvYes : '';

/// The ledger export: every due of the period, with its tenancy, what was
/// paid, waived and is owed, and whether it was voided.
List<List<CsvCell>> chargesTable(
  AppLocalizations l10n,
  List<ExportCharge> rows,
) => [
  [
    for (final header in [
      l10n.dueDateLabel,
      l10n.tenantLabel,
      l10n.unitLabel,
      l10n.propertyLabel,
      l10n.chargeForLabel,
      l10n.csvMonth,
      l10n.csvDescription,
      l10n.inRupees(l10n.amountLabel),
      l10n.inRupees(l10n.paidLabel),
      l10n.inRupees(l10n.csvWaived),
      l10n.inRupees(l10n.csvOwed),
      l10n.csvVoided,
    ])
      CsvCell.text(header),
  ],
  for (final ExportCharge(:charge, :tenancy) in rows)
    [
      CsvCell.date(charge.dueDate),
      CsvCell.text(tenancy.tenantName),
      CsvCell.text(tenancy.unitLabel),
      CsvCell.text(tenancy.propertyName),
      CsvCell.text(l10n.chargeKind(charge.kind)),
      CsvCell.text(charge.periodMonth?.toIso() ?? ''),
      CsvCell.text(charge.description ?? ''),
      CsvCell.money(charge.amount),
      CsvCell.money(charge.paidAmount),
      CsvCell.money(charge.waivedAmount),
      CsvCell.money(charge.voided ? Money.zero : charge.outstanding),
      CsvCell.text(_yes(l10n, charge.voided)),
    ],
];

/// The payments export: every payment of the period with its receipt,
/// method, tax withheld and certificate, and whether it was voided.
List<List<CsvCell>> paymentsTable(
  AppLocalizations l10n,
  List<ExportPayment> rows,
) => [
  [
    for (final header in [
      l10n.receivedOnLabel,
      l10n.receiptNumberLabel,
      l10n.tenantLabel,
      l10n.unitLabel,
      l10n.propertyLabel,
      l10n.paidByLabel,
      l10n.paymentReferenceLabel,
      l10n.inRupees(l10n.amountReceivedLabel),
      l10n.inRupees(l10n.taxWithheldLabel),
      l10n.taxCertificateLabel,
      l10n.notesLabel,
      l10n.csvVoided,
    ])
      CsvCell.text(header),
  ],
  for (final ExportPayment(:payment, :tenancy) in rows)
    [
      CsvCell.date(payment.paidOn),
      CsvCell.text(payment.receiptNumber),
      CsvCell.text(tenancy.tenantName),
      CsvCell.text(tenancy.unitLabel),
      CsvCell.text(tenancy.propertyName),
      CsvCell.text(l10n.paymentMethod(payment.method)),
      CsvCell.text(payment.reference ?? ''),
      CsvCell.money(payment.amount),
      CsvCell.money(payment.taxWithheld),
      CsvCell.text(payment.taxCertificateNo ?? ''),
      CsvCell.text(payment.notes ?? ''),
      CsvCell.text(_yes(l10n, payment.voided)),
    ],
];

/// The expenses export: every expense of the period with where it was
/// spent, its category, payee and method.
List<List<CsvCell>> expensesTable(AppLocalizations l10n, List<Expense> rows) =>
    [
      [
        for (final header in [
          l10n.spentOnLabel,
          l10n.propertyLabel,
          l10n.unitLabel,
          l10n.expenseCategoryLabel,
          l10n.payeeLabel,
          l10n.methodLabel,
          l10n.paymentReferenceLabel,
          l10n.inRupees(l10n.amountLabel),
          l10n.csvRepair,
          l10n.notesLabel,
        ])
          CsvCell.text(header),
      ],
      for (final expense in rows)
        [
          CsvCell.date(expense.spentOn),
          CsvCell.text(expense.propertyName ?? ''),
          CsvCell.text(expense.unitLabel ?? ''),
          CsvCell.text(l10n.expenseCategory(expense.category)),
          CsvCell.text(expense.payee ?? ''),
          CsvCell.text(l10n.paymentMethod(expense.method)),
          CsvCell.text(expense.reference ?? ''),
          CsvCell.money(expense.amount),
          CsvCell.text(expense.maintenanceTitle ?? ''),
          CsvCell.text(expense.notes ?? ''),
        ],
    ];

/// The tax-year statement as a table (RPT-01): one row per property, then
/// the totals, then the warning that it is not tax advice.
List<List<CsvCell>> taxYearTable(
  AppLocalizations l10n,
  TaxYearStatement statement,
) {
  final categories = [
    for (final category in ExpenseCategory.values)
      if (statement.properties.any(
        (p) => p.expensesByCategory.containsKey(category),
      ))
        category,
  ];
  List<CsvCell> row(
    String name,
    Money gross,
    Money tax,
    Money allowance,
    Money net,
    Money Function(ExpenseCategory) spent,
    Money expenses,
  ) => [
    CsvCell.text(name),
    CsvCell.money(gross),
    CsvCell.money(tax),
    CsvCell.money(allowance),
    CsvCell.money(net),
    for (final category in categories) CsvCell.money(spent(category)),
    CsvCell.money(expenses),
  ];
  return [
    [CsvCell.text(l10n.taxYearDocumentTitle('${statement.taxYear.endYear}'))],
    [CsvCell.text('${l10n.notTaxAdviceTitle}: ${l10n.notTaxAdviceBody}')],
    [
      for (final header in [
        l10n.propertyLabel,
        l10n.inRupees(l10n.grossRentLabel),
        l10n.inRupees(l10n.taxWithheldLabel),
        l10n.inRupees(l10n.repairsAllowanceLabel),
        l10n.inRupees(l10n.netAfterAllowanceLabel),
        for (final category in categories)
          l10n.inRupees(l10n.expenseCategory(category)),
        l10n.inRupees(l10n.expensesRecordedLabel),
      ])
        CsvCell.text(header),
    ],
    for (final property in statement.properties)
      row(
        property.propertyName,
        property.grossRent,
        property.taxWithheld,
        property.repairsAllowance,
        property.netAfterRepairsAllowance,
        (category) => property.expensesByCategory[category] ?? Money.zero,
        property.expensesTotal,
      ),
    row(
      l10n.allPropertiesLabel,
      statement.grossRent,
      statement.taxWithheld,
      statement.repairsAllowance,
      statement.netAfterRepairsAllowance,
      (category) => Money.sum([
        for (final p in statement.properties)
          p.expensesByCategory[category] ?? Money.zero,
      ]),
      statement.expensesTotal,
    ),
    [CsvCell.text(l10n.deductibleNote)],
  ];
}
