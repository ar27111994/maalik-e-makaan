import 'dart:typed_data';

import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_labels.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/pdf_text.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The rental income of a tax year per property (RPT-01) as a PDF in
/// [setup]'s language, for the landlord's tax adviser: gross rent, tax
/// withheld, the one-fifth repairs allowance, the rent after it and the
/// expenses recorded by category, then the totals. It says plainly that it
/// is not tax advice and works out no tax.
Future<Uint8List> taxYearPdf(
  TaxYearStatement statement,
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
  final year = statement.taxYear;

  Future<pw.Widget> row(String label, Money amount) =>
      documentRow(writer, label, money.format(amount), width: width);

  Future<List<pw.Widget>> figures({
    required Money gross,
    required Money tax,
    required Money allowance,
    required Money net,
    required Map<ExpenseCategory, Money> spent,
    required Money expenses,
  }) async => [
    await row(l10n.grossRentLabel, gross),
    await row(l10n.taxWithheldLabel, tax),
    await row(l10n.repairsAllowanceLabel, allowance),
    await row(l10n.netAfterAllowanceLabel, net),
    for (final category in ExpenseCategory.values)
      if (spent[category] case final amount?)
        await row(l10n.expenseCategory(category), amount),
    await row(l10n.expensesRecordedLabel, expenses),
  ];

  Future<pw.Widget> heading(String text) async => pw.Padding(
    padding: const pw.EdgeInsets.only(top: MmSpace.s3, bottom: MmSpace.s1),
    child: await writer.text(
      text,
      size: DocumentSize.title,
      maxWidth: width,
      bold: true,
    ),
  );

  final children = <pw.Widget>[
    await writer.text(
      setup.issuer,
      size: DocumentSize.headline,
      maxWidth: width,
      bold: true,
    ),
    await writer.text(
      l10n.taxYearDocumentTitle('${year.endYear}'),
      size: DocumentSize.title,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
    await writer.text(
      l10n.dateRange(words.date(year.start), words.date(year.end)),
      size: DocumentSize.small,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
    pw.SizedBox(height: MmSpace.s3),
    pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(MmSpace.s2),
      color: DocumentColors.sunken,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          await writer.text(
            l10n.notTaxAdviceTitle,
            bold: true,
            maxWidth: width - 2 * MmSpace.s2,
          ),
          await writer.text(
            l10n.notTaxAdviceBody,
            size: DocumentSize.small,
            maxWidth: width - 2 * MmSpace.s2,
          ),
        ],
      ),
    ),
    if (statement.properties.isEmpty) ...[
      pw.SizedBox(height: MmSpace.s3),
      await writer.text(l10n.taxYearEmpty, maxWidth: width),
    ],
    for (final property in statement.properties)
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            await heading(property.propertyName),
            ...await figures(
              gross: property.grossRent,
              tax: property.taxWithheld,
              allowance: property.repairsAllowance,
              net: property.netAfterRepairsAllowance,
              spent: property.expensesByCategory,
              expenses: property.expensesTotal,
            ),
          ],
        ),
      ),
    if (statement.properties.length > 1)
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            await heading(l10n.allPropertiesLabel),
            ...await figures(
              gross: statement.grossRent,
              tax: statement.taxWithheld,
              allowance: statement.repairsAllowance,
              net: statement.netAfterRepairsAllowance,
              spent: {
                for (final category in ExpenseCategory.values)
                  if (statement.properties.any(
                    (p) => p.expensesByCategory.containsKey(category),
                  ))
                    category: Money.sum([
                      for (final p in statement.properties)
                        p.expensesByCategory[category] ?? Money.zero,
                    ]),
              },
              expenses: statement.expensesTotal,
            ),
          ],
        ),
      ),
    pw.SizedBox(height: MmSpace.s4),
    pw.Divider(color: DocumentColors.rule, thickness: 0.5),
    await writer.text(
      l10n.deductibleNote,
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
        title: l10n.taxYearFileTitle('${year.endYear}'),
        author: setup.issuer,
        creator: l10n.appName,
      )..addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(documentMargin),
          textDirection: pdfTextDirection(writer),
          footer: documentPageNumbers,
          build: (_) => children,
        ),
      );
  return await document.save();
}

/// A month's owner statement (RPT-02) as a PDF in [setup]'s language, for
/// an owner who lives away: the money received and what it paid, the tax
/// withheld, the money paid out and the month's net; each property's
/// income and expenses; and, as of the day it is made, what tenants owe
/// and the cash each member holds. Informational, not an audited account.
Future<Uint8List> ownerStatementPdf(
  OwnerStatement statement,
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
  final flow = statement.flow;
  final allocated = flow.rent + flow.deposits + flow.other;
  final credit = flow.received + flow.taxWithheld - allocated;
  final owed = statement.outstanding;
  final asOf = words.date(statement.asOf);

  Future<pw.Widget> row(String label, Money amount) =>
      documentRow(writer, label, money.format(amount), width: width);

  Future<pw.Widget> heading(String text) async => pw.Padding(
    padding: const pw.EdgeInsets.only(top: MmSpace.s3, bottom: MmSpace.s1),
    child: await writer.text(
      text,
      size: DocumentSize.title,
      maxWidth: width,
      bold: true,
    ),
  );

  Future<pw.Widget> section(String title, List<pw.Widget> rows) async =>
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [await heading(title), ...rows],
        ),
      );

  final children = <pw.Widget>[
    await writer.text(
      setup.issuer,
      size: DocumentSize.headline,
      maxWidth: width,
      bold: true,
    ),
    await writer.text(
      l10n.ownerStatementFileTitle(words.month(statement.month)),
      size: DocumentSize.title,
      color: DocumentColors.muted,
      maxWidth: width,
    ),
    if (statement.portfolioName != setup.issuer)
      await writer.text(
        statement.portfolioName,
        size: DocumentSize.small,
        color: DocumentColors.muted,
        maxWidth: width,
      ),
    await section(l10n.moneyReceivedHeading, [
      await row(l10n.rentAndFeesLabel, flow.rent),
      await row(l10n.depositsReceivedLabel, flow.deposits),
      await row(l10n.otherDuesLabel, flow.other),
      if (credit.isPositive) await row(l10n.unallocatedLabel, credit),
      await row(l10n.taxWithheldLabel, flow.taxWithheld),
      await row(l10n.amountReceivedLabel, flow.received),
    ]),
    await section(l10n.moneyPaidOutHeading, [
      await row(l10n.propertyExpensesLabel, flow.expenses),
      await row(l10n.depositRefundsLabel, flow.depositRefunds),
      await row(l10n.netCashLabel, flow.net),
    ]),
    if (statement.properties.isNotEmpty) ...[
      pw.SizedBox(height: MmSpace.s3),
      ...await documentTable(
        writer,
        l10n.navProperties,
        [5, 3, 3, 3, 3],
        [
          [
            l10n.propertyLabel,
            l10n.rentIncomeLabel,
            l10n.otherIncomeLabel,
            l10n.propertyExpensesLabel,
            l10n.netLabel,
          ],
          for (final p in statement.properties)
            [
              p.propertyName,
              money.format(p.rentIncome),
              money.format(p.otherIncome),
              money.format(p.expenses),
              money.format(p.netOperatingIncome),
            ],
        ],
        width: width,
        header: true,
        end: (column) => column > 0,
      ),
    ],
    await section(l10n.owedOnHeading(asOf), [
      await row(l10n.totalOwedLabel, owed.total),
      await row(l10n.ageNotDue, owed.notDue),
      await row(l10n.age1to30, owed.days1to30),
      await row(l10n.age31to60, owed.days31to60),
      await row(l10n.age61to90, owed.days61to90),
      await row(l10n.ageOver90, owed.over90),
    ]),
    if (statement.arrears.isNotEmpty) ...[
      pw.SizedBox(height: MmSpace.s3),
      ...await documentTable(
        writer,
        l10n.owingMostSection,
        [4, 4, 3, 2],
        [
          [
            l10n.tenantLabel,
            l10n.unitLabel,
            l10n.totalOverdueLabel,
            l10n.daysOverdueLabel,
          ],
          for (final a in statement.arrears)
            [
              a.tenantName,
              l10n.unitAtProperty(a.unitLabel, a.propertyName),
              money.format(a.overdue),
              '${a.daysOverdue}',
            ],
        ],
        width: width,
        header: true,
        end: (column) => column > 1,
      ),
    ],
    if (statement.cash.isNotEmpty)
      await section(l10n.cashHeldOnHeading(asOf), [
        for (final position in statement.cash)
          await row(holderName(l10n, position), position.inHand),
      ]),
    pw.SizedBox(height: MmSpace.s4),
    pw.Divider(color: DocumentColors.rule, thickness: 0.5),
    await writer.text(
      l10n.ownerStatementFooter,
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
        title: l10n.ownerStatementFileTitle(words.month(statement.month)),
        author: setup.issuer,
        creator: l10n.appName,
      )..addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(documentMargin),
          textDirection: pdfTextDirection(writer),
          footer: documentPageNumbers,
          build: (_) => children,
        ),
      );
  return await document.save();
}
