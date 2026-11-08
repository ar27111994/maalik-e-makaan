import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/pdf_text.dart';
import 'package:mm_core/mm_core.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../support/harness.dart';

/// How many pages [pdf] has, read from its page objects.
int _pages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

/// How many images [pdf] holds (the Urdu text Flutter drew).
int _images(Uint8List pdf) =>
    RegExp(r'/Subtype\s*/Image').allMatches(latin1.decode(pdf)).length;

void main() {
  late PaymentDetail detail;
  late LedgerStatement statement;

  setUp(() async {
    final ledger = FakeLedgerRepository();
    final payments = ledger.paymentsOf[aliLease.id]!;
    // October's payment with tax withheld and voided, so the receipt shows
    // every part.
    final index = payments.indexWhere((p) => p.id == 'pay-oct');
    payments[index] = Payment.fromRow({
      ...payments[index].toRow(),
      'tax_withheld': '4500.00',
      'tax_certificate_no': 'CPR-7',
      'notes': 'Paid at the shop',
      'voided_at': '2026-11-01T05:00:00+00:00',
      'void_reason': 'Cheque bounced',
    });
    detail = await ledger.payment('pay-oct');
    statement = await ledger.statement(aliLease.id);
  });

  DocumentSetup setup(DocumentLanguage language) => DocumentSetup(
    language: language,
    issuer: 'Ayesha Khan',
    today: CalendarDate(2026, 11, 7),
  );

  testWidgets('a receipt in English is PDF text on one page', (tester) async {
    final pdf = (await tester.runAsync(
      () => receiptPdf(detail, setup(DocumentLanguage.english)),
    ))!;
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_pages(pdf), 1);
    // Every word is Latin: nothing is drawn as an image.
    expect(_images(pdf), 0);
  });

  testWidgets('a receipt in Urdu draws its Nastaliq with Flutter', (
    tester,
  ) async {
    final pdf = (await tester.runAsync(
      () => receiptPdf(detail, setup(DocumentLanguage.urdu)),
    ))!;
    // Its tall Nastaliq lines do not fit one A5 page: the rest flows on to
    // a second page instead of being cut off (the footer was lost).
    expect(_pages(pdf), 2);
    expect(_images(pdf), greaterThan(10));
  });

  testWidgets('a receipt settling many dues flows across pages', (
    tester,
  ) async {
    final many = PaymentDetail(
      payment: detail.payment,
      lease: detail.lease,
      settled: [
        for (var month = 1; month <= 36; month++)
          SettledCharge(
            chargeId: 'ch-$month',
            amount: const Money.fromRupees(85000),
            kind: ChargeKind.rent,
            periodMonth: MonthPeriod(2024, 1).addMonths(month - 1),
            dueDate: CalendarDate(2024, 1, 5),
          ),
      ],
    );
    for (final language in DocumentLanguage.values) {
      final pdf = (await tester.runAsync(
        () => receiptPdf(many, setup(language)),
      ))!;
      expect(_pages(pdf), greaterThan(1), reason: language.name);
    }
  });

  testWidgets('a statement lists every due and payment', (tester) async {
    final english = (await tester.runAsync(
      () => statementPdf(statement, setup(DocumentLanguage.english)),
    ))!;
    expect(_pages(english), 1);
    final urdu = (await tester.runAsync(
      () => statementPdf(statement, setup(DocumentLanguage.urdu)),
    ))!;
    expect(_pages(urdu), 2);
    // With no payments, it says so.
    final empty = LedgerStatement(
      lease: endedLease,
      charges: const [],
      payments: const [],
      deposit: DepositPosition.none,
      refunds: const [],
    );
    final none = (await tester.runAsync(
      () => statementPdf(empty, setup(DocumentLanguage.english)),
    ))!;
    expect(_pages(none), 1);
  });

  /// [years] of a tenancy: rent, a bill and a payment every month.
  LedgerStatement longStatement(int years) {
    final start = CalendarDate(2026 - years, 11, 5);
    final months = years * 12;
    return LedgerStatement(
      lease: statement.lease,
      charges: [
        for (var month = 0; month < months; month++) ...[
          Charge(
            id: 'rent-$month',
            leaseId: statement.lease.id,
            kind: ChargeKind.rent,
            source: ChargeSource.autoRent,
            periodMonth: MonthPeriod.of(start.addMonths(month)),
            dueDate: start.addMonths(month),
            amount: const Money.fromRupees(85000),
            paidAmount: const Money.fromRupees(85000),
          ),
          Charge(
            id: 'bill-$month',
            leaseId: statement.lease.id,
            kind: ChargeKind.electricity,
            source: ChargeSource.manual,
            periodMonth: MonthPeriod.of(start.addMonths(month)),
            dueDate: start.addMonths(month).addDays(10),
            amount: Money.fromRupees(5000 + month * 37),
            description: 'LESCO',
          ),
        ],
      ],
      payments: [
        for (var month = 0; month < months; month++)
          Payment(
            id: 'pay-$month',
            leaseId: statement.lease.id,
            amount: const Money.fromRupees(85000),
            paidOn: start.addMonths(month).addDays(2),
            method: PaymentMethod.bankTransfer,
            receiptNumber: 'MM-${2026 - years + month ~/ 12}-${month + 1}',
          ),
      ],
      deposit: statement.deposit,
      refunds: const [],
    );
  }

  testWidgets('a statement longer than 20 pages is made', (tester) async {
    // Thirty years: 1,080 rows on more pages than the pdf package allows
    // by default.
    final pdf = (await tester.runAsync(
      () => statementPdf(longStatement(30), setup(DocumentLanguage.english)),
    ))!;
    expect(_pages(pdf), greaterThan(20));
  });

  testWidgets('ten years in Urdu are made in time and size', (tester) async {
    // 360 rows, each Urdu cell drawn as an image. Measured: 15 pages,
    // 6.8 MB, about 5 s; the limits leave room for slower machines.
    final clock = Stopwatch()..start();
    final pdf = (await tester.runAsync(
      () => statementPdf(longStatement(10), setup(DocumentLanguage.urdu)),
    ))!;
    clock.stop();
    expect(_pages(pdf), greaterThan(10));
    expect(pdf.length, lessThan(12 * 1024 * 1024));
    expect(clock.elapsed, lessThan(const Duration(seconds: 90)));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('file names keep to Latin letters, figures and dashes', () {
    expect(
      documentFileName('receipt MM-2026-00041'),
      'receipt-MM-2026-00041.pdf',
    );
    expect(documentFileName('statement علی 2026'), 'statement-2026.pdf');
    expect(documentFileName('رسید'), 'document.pdf');
  });

  test('text with Urdu letters is told apart', () {
    expect(hasArabicScript('Ali Raza'), isFalse);
    expect(hasArabicScript('کرایہ 2026'), isTrue);
  });

  testWidgets('drawn text is cached and fills its cell', (tester) async {
    final writer = (await tester.runAsync(
      () => PdfTextWriter.load(direction: TextDirection.rtl),
    ))!;
    expect(writer.rightToLeft, isTrue);
    final first = (await tester.runAsync(
      () => writer.text('کرایہ', fill: true, bold: true),
    ))!;
    final second = (await tester.runAsync(
      () => writer.text('کرایہ', fill: true, bold: true, end: true),
    ))!;
    expect(first, isNot(same(second)));
    final latin = (await tester.runAsync(() => writer.text('Rs 5,000')))!;
    expect(latin.runtimeType.toString(), 'Text');
  });

  testWidgets('drawn Urdu keeps every stroke, the first letter too', (
    tester,
  ) async {
    final writer = (await tester.runAsync(
      () => PdfTextWriter.load(direction: TextDirection.rtl),
    ))!;
    // A kaf starting a line reaches past the start of the line.
    final drawn = (await tester.runAsync(() => writer.text('کون سے')))!;
    final png = ((drawn as pw.Image).image as pw.MemoryImage).bytes;
    final image = img.decodePng(png)!;
    bool blank(int x) =>
        [for (var y = 0; y < image.height; y++) image.getPixel(x, y).a]
            .every((alpha) => alpha == 0);
    // Nothing touches either side: no stroke was cut off.
    expect(blank(0), isTrue);
    expect(blank(image.width - 1), isTrue);
  });
}
