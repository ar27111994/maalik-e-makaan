import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/pdf_text.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The language a printed document is written in, whatever the app's.
enum DocumentLanguage {
  english('en'),
  urdu('ur');

  new(this.code);

  /// Its language code.
  final String code;
}

/// What a document says beside its rows: who issues it, in which
/// language, with which amount grouping, and on which day.
final class DocumentSetup {
  const new({
    required this.language,
    required this.issuer,
    required this.today,
    this.grouping = DigitGrouping.western,
    this.bundle,
  });

  final DocumentLanguage language;

  /// The landlord's (or the portfolio's) name.
  final String issuer;

  /// The day it is made, in Pakistan.
  final CalendarDate today;
  final DigitGrouping grouping;

  /// Where the fonts are read from (the app's assets unless a test says).
  final AssetBundle? bundle;
}

/// The words, amounts and dates of a document, in its language.
final class DocumentWords {
  new(this.setup)
    : l10n = lookupAppLocalizations(ui.Locale(setup.language.code)),
      money = MoneyFormat(
        grouping: setup.grouping,
        language: setup.language == DocumentLanguage.urdu
            ? MoneyLanguage.urdu
            : MoneyLanguage.english,
      );

  /// The words of [setup]'s language, with its date formats ready.
  static Future<DocumentWords> load(DocumentSetup setup) async {
    final words = DocumentWords(setup);
    await initializeDateFormatting(words._locale);
    return words;
  }

  final DocumentSetup setup;
  final AppLocalizations l10n;
  final MoneyFormat money;

  String get _locale =>
      setup.language == DocumentLanguage.english ? 'en_IN' : 'ur';

  String date(CalendarDate date) =>
      DateFormat.yMMMd(_locale).format(date.toDateTimeUtc());

  String month(MonthPeriod month) =>
      DateFormat.yMMMM(_locale).format(month.first.toDateTimeUtc());

  String charge(ChargeKind kind, MonthPeriod? period) =>
      l10n.chargeTitle(kind, period, month);

  ui.TextDirection get direction => setup.language == DocumentLanguage.urdu
      ? ui.TextDirection.rtl
      : ui.TextDirection.ltr;
}

/// The light theme's colours, as printed documents use them.
abstract final class DocumentColors {
  static PdfColor get ink => pdfColor(MmColorModes.light.ink);
  static PdfColor get muted => pdfColor(MmColorModes.light.inkMuted);
  static PdfColor get rule => pdfColor(MmColorModes.light.rule);
  static PdfColor get brass => pdfColor(MmColorModes.light.brass);
  static PdfColor get overdue => pdfColor(MmColorModes.light.overdue);
  static PdfColor get overdueContainer =>
      pdfColor(MmColorModes.light.overdueContainer);
  static PdfColor get sunken => pdfColor(MmColorModes.light.surfaceSunken);
}

/// The page margin of every document, in points (the screens' 4-point grid
/// is the documents' too).
const double documentMargin = MmSpace.s8;

/// A receipt's margin above and below, in points. With it, and the receipt's
/// tighter gaps and one-paragraph footer, an A5 page holds an Urdu receipt
/// that settles three dues and has a reference; before, the tall Nastaliq
/// lines pushed the footer of one settling two on to a second page
/// (docs/uat.md, D8).
const double receiptMarginVertical = MmSpace.s5;

/// The type sizes of documents, in points.
abstract final class DocumentSize {
  static const double caption = 8;
  static const double small = 9;
  static const double title = 12;
  static const double number = 13;
  static const double headline = 16;
  static const double amount = 22;
}

/// A receipt (LEDGER-05) for [detail] as a PDF, in [setup]'s language: the
/// issuer, the receipt number on its seal, the amount received, who paid
/// it for what, the tax withheld with its certificate (LEDGER-10), the dues
/// it settled, and VOID with the reason when it was voided.
Future<Uint8List> receiptPdf(PaymentDetail detail, DocumentSetup setup) async {
  final words = await DocumentWords.load(setup);
  final l10n = words.l10n;
  final writer = await PdfTextWriter.load(
    direction: words.direction,
    bundle: setup.bundle,
  );
  const format = PdfPageFormat.a5;
  final width = format.width - 2 * documentMargin;
  final payment = detail.payment;
  final lease = detail.lease;

  Future<pw.Widget> row(String label, String value) =>
      documentRow(writer, label, value, width: width);

  final settledRows = [
    for (final settled in detail.settled)
      await row(
        words.charge(settled.kind, settled.periodMonth),
        words.money.format(settled.amount),
      ),
  ];
  final voidReason = payment.voidReason;
  final children = <pw.Widget>[
    await writer.text(
      setup.issuer,
      size: DocumentSize.headline,
      maxWidth: width,
      bold: true,
    ),
    pw.SizedBox(height: MmSpace.sHalf),
    await writer.text(l10n.receiptDocumentTitle, color: DocumentColors.muted),
    pw.SizedBox(height: MmSpace.s2),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: MmSpace.s3,
        vertical: MmSpace.s2,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: DocumentColors.brass, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          await writer.text(
            l10n.receiptNumberLabel,
            size: DocumentSize.caption,
            color: DocumentColors.muted,
          ),
          await writer.text(payment.receiptNumber, size: DocumentSize.number),
        ],
      ),
    ),
    if (payment.voided) ...[
      pw.SizedBox(height: MmSpace.s2),
      pw.Container(
        width: width,
        padding: const pw.EdgeInsets.all(MmSpace.s2),
        color: DocumentColors.overdueContainer,
        child: await writer.text(
          voidReason == null
              ? l10n.receiptVoid
              : l10n.receiptVoidBecause(voidReason),
          color: DocumentColors.overdue,
          maxWidth: width - 2 * MmSpace.s2,
        ),
      ),
    ],
    pw.SizedBox(height: MmSpace.s2),
    await writer.text(
      l10n.amountReceivedLabel,
      size: DocumentSize.small,
      color: DocumentColors.muted,
    ),
    await writer.text(
      words.money.format(payment.amount),
      size: DocumentSize.amount,
    ),
    pw.SizedBox(height: MmSpace.s2),
    pw.Divider(color: DocumentColors.rule, thickness: 0.5),
    await row(l10n.receivedFromLabel, lease.tenantName),
    await row(
      l10n.receiptForLabel,
      l10n.unitAtProperty(lease.unitLabel, lease.propertyName),
    ),
    await row(l10n.receivedOnLabel, words.date(payment.paidOn)),
    await row(l10n.paidByLabel, l10n.paymentMethod(payment.method)),
    if (payment.reference case final reference?)
      await row(l10n.paymentReferenceLabel, reference),
    if (payment.taxWithheld.isPositive) ...[
      await row(l10n.taxWithheldLabel, words.money.format(payment.taxWithheld)),
      if (payment.taxCertificateNo case final certificate?)
        await row(l10n.taxCertificateLabel, certificate),
      await row(l10n.totalSettledLabel, words.money.format(payment.applied)),
    ],
    if (settledRows.isNotEmpty) ...[
      pw.SizedBox(height: MmSpace.s2),
      await writer.text(l10n.receiptSettledHeading, size: DocumentSize.title),
      pw.SizedBox(height: MmSpace.sHalf),
      ...settledRows,
    ],
    if (!payment.voided && payment.unallocated.isPositive)
      await row(l10n.creditKeptLabel, words.money.format(payment.unallocated)),
    if (payment.notes case final notes?) ...[
      pw.SizedBox(height: MmSpace.s2),
      await row(l10n.notesLabel, notes),
    ],
    pw.SizedBox(height: MmSpace.s2),
    pw.Divider(color: DocumentColors.rule, thickness: 0.5),
    // One paragraph, not two lines: a Nastaliq line is tall (D8).
    await writer.text(
      '${l10n.receiptFooter} ${l10n.documentMadeOn(words.date(setup.today))}',
      size: DocumentSize.caption,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
  ];
  final document =
      pw.Document(
        theme: writer.theme,
        title: l10n.receiptFileTitle(payment.receiptNumber),
        author: setup.issuer,
        creator: l10n.appName,
      )..addPage(
        // The rows flow on to another page when they do not fit (an Urdu
        // receipt's Nastaliq lines are tall, and a payment may settle many
        // dues), so nothing is cut off.
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: documentMargin,
            vertical: receiptMarginVertical,
          ),
          textDirection: pdfTextDirection(writer),
          footer: documentPageNumbers,
          build: (_) => children,
        ),
      );
  return await document.save();
}

/// "2 / 3" at the foot of a page of a document longer than one page.
pw.Widget documentPageNumbers(pw.Context context) => context.pagesCount < 2
    ? pw.SizedBox()
    : pw.Align(
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(
            fontSize: DocumentSize.caption,
            color: DocumentColors.muted,
          ),
        ),
      );

/// A tenant statement (LEDGER-09, the "dispute pack") as a PDF in
/// [setup]'s language: the tenancy, what was billed, paid, waived and is
/// owed, every due and every payment with its receipt number, and the
/// deposit.
Future<Uint8List> statementPdf(
  LedgerStatement statement,
  DocumentSetup setup,
) async {
  final words = await DocumentWords.load(setup);
  final l10n = words.l10n;
  final money = words.money;
  final writer = await PdfTextWriter.load(
    direction: words.direction,
    bundle: setup.bundle,
  );
  const format = PdfPageFormat.a4;
  final width = format.width - 2 * documentMargin;
  final lease = statement.lease;
  final live = [
    for (final c in statement.charges)
      if (!c.voided) c,
  ];
  final received = [
    for (final p in statement.payments)
      if (!p.voided) p,
  ];

  Future<pw.Widget> row(String label, String value) =>
      documentRow(writer, label, value, width: width);

  Future<List<pw.Widget>> table(
    String heading,
    List<int> flex,
    List<List<String>> rows, {
    bool header = false,
  }) => documentTable(
    writer,
    heading,
    flex,
    rows,
    width: width,
    header: header,
    // Amounts line up on the end edge.
    end: (column) => column >= flex.length - 3 && column > 1,
  );

  final end = lease.movedOutOn ?? setup.today;
  final billed = Money.sum([for (final c in live) c.amount]);
  final paid = Money.sum([for (final c in live) c.paidAmount]);
  final waived = Money.sum([for (final c in live) c.waivedAmount]);
  final today = setup.today;

  String state(Charge charge) => switch (charge.stateOn(today)) {
    ChargeState.voided => l10n.chargeVoided,
    ChargeState.paid => l10n.chargePaid,
    ChargeState.waived => l10n.chargeWaived,
    ChargeState.overdue => l10n.overdueDays(
      today.differenceInDays(charge.dueDate),
    ),
    ChargeState.dueSoon ||
    ChargeState.notDue => l10n.dueOn(words.date(charge.dueDate)),
  };

  final children = <pw.Widget>[
    await writer.text(
      setup.issuer,
      size: DocumentSize.headline,
      maxWidth: width,
    ),
    await writer.text(
      l10n.statementDocumentTitle,
      size: DocumentSize.title,
      color: DocumentColors.muted,
    ),
    pw.SizedBox(height: MmSpace.s3),
    await row(l10n.tenantLabel, lease.tenantName),
    await row(
      l10n.receiptForLabel,
      l10n.unitAtProperty(lease.unitLabel, lease.propertyName),
    ),
    await row(
      l10n.statementPeriodLabel,
      l10n.dateRange(words.date(lease.terms.startDate), words.date(end)),
    ),
    await row(l10n.monthlyRentLabel, money.format(lease.terms.monthlyRent)),
    pw.SizedBox(height: MmSpace.s3),
    await writer.text(l10n.statementSummaryHeading, size: DocumentSize.title),
    await row(l10n.totalBilledLabel, money.format(billed)),
    await row(l10n.totalPaidLabel, money.format(paid)),
    if (waived.isPositive)
      await row(l10n.totalWaivedLabel, money.format(waived)),
    await row(l10n.balanceOwedLabel, money.format(statement.outstanding)),
    if (statement.credit.isPositive)
      await row(l10n.creditLabel, money.format(statement.credit)),
    await row(l10n.depositHeldLabel, money.format(statement.deposit.held)),
    pw.SizedBox(height: MmSpace.s3),
    ...await table(
      l10n.statementDuesHeading,
      [3, 5, 3, 3, 3],
      [
        [
          l10n.dueDateLabel,
          l10n.chargeForLabel,
          l10n.amountLabel,
          l10n.paidLabel,
          l10n.chargeStateLabel,
        ],
        for (final charge in statement.charges)
          [
            words.date(charge.dueDate),
            [
              words.charge(charge.kind, charge.periodMonth),
              ?charge.description,
            ].join(' · '),
            money.format(charge.amount),
            money.format(charge.paidAmount),
            state(charge),
          ],
      ],
      header: true,
    ),
    pw.SizedBox(height: MmSpace.s3),
    if (statement.payments.isEmpty) ...[
      await writer.text(
        l10n.statementPaymentsHeading,
        size: DocumentSize.title,
      ),
      pw.SizedBox(height: MmSpace.s1),
      await writer.text(
        l10n.noPaymentsYet,
        size: DocumentSize.small,
        color: DocumentColors.muted,
      ),
    ] else
      ...await table(
        l10n.statementPaymentsHeading,
        [3, 4, 4, 3, 3],
        [
          [
            l10n.receivedOnLabel,
            l10n.receiptNumberLabel,
            l10n.paidByLabel,
            l10n.taxWithheldLabel,
            l10n.amountLabel,
          ],
          for (final payment in statement.payments)
            [
              words.date(payment.paidOn),
              if (payment.voided)
                l10n.voidedReceipt(payment.receiptNumber)
              else
                payment.receiptNumber,
              l10n.paymentMethod(payment.method),
              money.format(payment.taxWithheld),
              money.format(payment.amount),
            ],
        ],
        header: true,
      ),
    pw.SizedBox(height: MmSpace.s3),
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          await writer.text(l10n.depositSection, size: DocumentSize.title),
          await row(
            l10n.depositAgreedLabel,
            money.format(statement.deposit.agreed),
          ),
        ],
      ),
    ),
    await row(
      l10n.depositReceivedLabel,
      money.format(statement.deposit.received),
    ),
    await row(
      l10n.depositAppliedLabel,
      money.format(statement.deposit.applied),
    ),
    await row(
      l10n.depositRefundedLabel,
      money.format(statement.deposit.refunded),
    ),
    await row(l10n.depositHeldLabel, money.format(statement.deposit.held)),
    pw.SizedBox(height: MmSpace.s4),
    await writer.text(
      l10n.statementFooter(received.length),
      size: DocumentSize.caption,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
    await writer.text(
      l10n.documentMadeOn(words.date(setup.today)),
      size: DocumentSize.caption,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
  ];
  final document =
      pw.Document(
        theme: writer.theme,
        title: l10n.statementFileTitle(lease.tenantName),
        author: setup.issuer,
        creator: l10n.appName,
      )..addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(documentMargin),
          textDirection: pdfTextDirection(writer),
          // Each table row is a child of its own, so a statement of many
          // years flows across as many pages as it needs: `maxPages` only
          // bounds how many pages one child may span.
          footer: documentPageNumbers,
          build: (_) => children,
        ),
      );
  return await document.save();
}

pw.TextDirection pdfTextDirection(PdfTextWriter writer) =>
    writer.rightToLeft ? pw.TextDirection.rtl : pw.TextDirection.ltr;

/// A table's rows, the header first, each its own widget so a long table
/// flows across pages; [heading] is kept on one page with the header and
/// the first row, never left alone at the foot of a page. The columns
/// share [width] as [flex] says; [end] says which columns (amounts) line
/// up on the end edge.
Future<List<pw.Widget>> documentTable(
  PdfTextWriter writer,
  String heading,
  List<int> flex,
  List<List<String>> rows, {
  required double width,
  required bool Function(int column) end,
  bool header = false,
}) async {
  final total = flex.reduce((a, b) => a + b);
  final lines = <pw.Widget>[];
  for (final (index, cells) in rows.indexed) {
    final head = header && index == 0;
    lines.add(
      pw.Container(
        color: head ? DocumentColors.sunken : null,
        padding: const pw.EdgeInsets.symmetric(
          vertical: MmSpace.s1,
          horizontal: MmSpace.sHalf,
        ),
        decoration: head
            ? null
            : pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: DocumentColors.rule, width: 0.5),
                ),
              ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // The cells of a row stand on one baseline, whichever face
            // draws them.
            for (final (column, cell) in PdfTextWriter.onBaseline([
              for (final (column, cell) in cells.indexed)
                await writer.cell(
                  cell,
                  size: DocumentSize.caption,
                  color: head ? DocumentColors.muted : DocumentColors.ink,
                  maxWidth: width * flex[column] / total - MmSpace.s1,
                  end: end(column),
                  fill: true,
                ),
            ]).indexed)
              pw.Expanded(
                flex: flex[column],
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: MmSpace.sHalf,
                  ),
                  child: cell,
                ),
              ),
          ],
        ),
      ),
    );
  }
  final title = await writer.text(heading, size: DocumentSize.title);
  final lead = lines.take(header ? 2 : 1).toList();
  return [
    // Kept together: what it holds moves to the next page as one.
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          title,
          pw.SizedBox(height: MmSpace.s1),
          ...lead,
        ],
      ),
    ),
    ...lines.skip(lead.length),
  ];
}

/// A label and its value on one line: the label at the start edge, the
/// value at the end edge.
Future<pw.Widget> documentRow(
  PdfTextWriter writer,
  String label,
  String value, {
  required double width,
}) async {
  // The label and the value stand on one baseline, whichever face draws
  // them.
  final [labelCell, valueCell] = PdfTextWriter.onBaseline([
    await writer.cell(
      label,
      size: DocumentSize.small,
      color: DocumentColors.muted,
      maxWidth: width * 2 / 5,
      fill: true,
    ),
    await writer.cell(value, maxWidth: width * 3 / 5, end: true, fill: true),
  ]);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: MmSpace.sHalf),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 2, child: labelCell),
        pw.Expanded(flex: 3, child: valueCell),
      ],
    ),
  );
}

/// The name a document file is saved under: Latin letters, figures and
/// dashes only, so every phone and computer keeps it, with [extension].
String documentFileName(String title, {String extension = 'pdf'}) {
  final safe = title
      .replaceAll(RegExp('[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${safe.isEmpty ? 'document' : safe}.$extension';
}
