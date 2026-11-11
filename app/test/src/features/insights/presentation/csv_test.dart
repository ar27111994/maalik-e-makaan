import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/csv.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';

/// The text of [rows] as a CSV file, without its byte-order mark.
String _text(List<List<CsvCell>> rows) {
  final bytes = csvBytes(rows);
  expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
  return utf8.decode(bytes.sublist(3));
}

/// [fields] as one line of a CSV file, without its line end.
String _fields(List<String> fields) => fields.join(',');

const _tenancy = ExportTenancy(
  tenantName: 'Ali Raza',
  unitLabel: 'Ground floor',
  propertyName: 'Gulberg House',
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ur = lookupAppLocalizations(const Locale('ur'));

  test('cells are quoted only when they must be', () {
    final expected = _fields([
      'plain',
      '"a, b"',
      '"say ""hi"""',
      '"two\nlines"',
      '" padded"',
      '',
      '1250.50',
      '2026-11-07',
    ]);
    expect(
      _text([
        [
          const CsvCell.text('plain'),
          const CsvCell.text('a, b'),
          const CsvCell.text('say "hi"'),
          const CsvCell.text('two\nlines'),
          const CsvCell.text(' padded'),
          CsvCell.empty,
          CsvCell.money(Money.parseDecimal('1250.5')),
          CsvCell.date(CalendarDate(2026, 11, 7)),
        ],
      ]),
      '$expected\r\n',
    );
  });

  test('text that a spreadsheet would run as a formula is defused', () {
    for (final formula in [
      '=HYPERLINK("http://x")',
      '+92 300',
      '-5',
      '@SUM(A1)',
      '\t=1',
      '\rcmd',
    ]) {
      expect(
        _text([
          [CsvCell.text(formula)],
        ]),
        startsWith(formula.contains(RegExp('[",\r\n]')) ? '"\'' : "'"),
        reason: formula,
      );
    }
    // Amounts the app writes are numbers, negative ones too.
    expect(
      _text([
        [CsvCell.money(const Money.fromRupees(-500))],
      ]),
      '-500.00\r\n',
    );
    expect(
      _text([
        [const CsvCell.text('a=b')],
      ]),
      'a=b\r\n',
    );
  });

  test('a file is shared with the media type of its name', () {
    expect(documentMimeType('rows.csv'), 'text/csv');
    expect(documentMimeType('Statement.PDF'), 'application/pdf');
  });

  test('Urdu is written in UTF-8', () {
    expect(
      _text([
        [const CsvCell.text('علی رضا')],
      ]),
      'علی رضا\r\n',
    );
  });

  test('the ledger export lists every due with whose it is', () {
    final ledger = FakeLedgerRepository();
    final charges = ledger.chargesOf[aliLease.id]!;
    final voided = Charge.fromRow({
      ...charges.first.toRow(),
      'paid_amount': 0,
      'waived_amount': 0,
      'outstanding': charges.first.amount.toJson(),
      'voided_at': '2026-11-01T05:00:00+00:00',
      'void_reason': 'Typed twice',
      'description': '=cmd',
    });
    final rows = chargesTable(en, [
      for (final c in [...charges, voided])
        ExportCharge(charge: c, tenancy: _tenancy),
    ]);
    expect(rows, hasLength(charges.length + 2));
    final text = _text(rows);
    expect(
      text.split('\r\n').first,
      _fields([
        'Due date',
        'Tenant',
        'Unit',
        'Property',
        'What for',
        'Month',
        'Note',
        'Amount (Rs)',
        'Paid (Rs)',
        'Waived (Rs)',
        'Owed (Rs)',
        'Voided',
      ]),
    );
    final last = text.split('\r\n')[rows.length - 1];
    expect(last, contains(",'=cmd,"));
    expect(last, endsWith(',0.00,Yes'));
    expect(text, contains('Ali Raza,Ground floor,Gulberg House,Rent,2026-'));
    expect(
      _text(chargesTable(ur, const [])),
      startsWith('دینے کی تاریخ,کرایہ دار'),
    );
  });

  test('the payments export carries receipts, methods and tax', () {
    final payment = FakeLedgerRepository().paymentsOf[aliLease.id]!.first;
    final rows = paymentsTable(en, [
      ExportPayment(payment: payment, tenancy: _tenancy),
    ]);
    final [header, row] = _text(rows).trim().split('\r\n');
    expect(
      header,
      _fields([
        'Received on',
        'Receipt no.',
        'Tenant',
        'Unit',
        'Property',
        'Paid by',
        'Reference',
        'Amount received (Rs)',
        'Tax withheld (s.155) (Rs)',
        'Certificate or CPR number',
        'Notes',
        'Voided',
      ]),
    );
    expect(
      row,
      startsWith('${payment.paidOn.toIso()},${payment.receiptNumber},'),
    );
    expect(row, contains(payment.amount.toDecimalString()));
  });

  test('the expenses export says where and for what', () {
    final rows = expensesTable(en, [plumberExpense, taxExpense]);
    final lines = _text(rows).trim().split('\r\n');
    expect(lines.first, startsWith('Spent on,Property,Unit,Category,Paid to'));
    expect(lines, hasLength(3));
    expect(lines[1], contains(plumberExpense.amount.toDecimalString()));
  });

  test('the tax-year table has a column per category used, and totals', () {
    final statement = TaxYearStatement(
      taxYear: TaxYear(2026),
      properties: [
        for (final row in taxYearJson()) TaxYearProperty.fromRow(row),
      ],
    );
    final lines = _text(taxYearTable(en, statement)).trim().split('\r\n');
    expect(lines.first, '"Rental income, tax year 2026"');
    expect(lines[1], startsWith('"Not tax advice: These figures'));
    expect(
      lines[2],
      _fields([
        'Property',
        '"Rent received, gross (Rs)"',
        'Tax withheld (s.155) (Rs)',
        '"Repairs allowance, one fifth (Rs)"',
        'Rent after the repairs allowance (Rs)',
        'Repairs and maintenance (Rs)',
        'Property tax (Rs)',
        'Society charges (Rs)',
        'Expenses recorded (Rs)',
      ]),
    );
    expect(
      lines[3],
      _fields([
        'Gulberg House',
        '1020000.00',
        '30000.00',
        '204000.00',
        '816000.00',
        '45000.00',
        '18500.50',
        '0.00',
        '63500.50',
      ]),
    );
    expect(
      lines[5],
      _fields([
        'All properties',
        '2460000.00',
        '174000.00',
        '492000.00',
        '1968000.00',
        '45000.00',
        '18500.50',
        '36000.00',
        '99500.50',
      ]),
    );
    expect(lines.last, contains('tax adviser'));
  });
}
