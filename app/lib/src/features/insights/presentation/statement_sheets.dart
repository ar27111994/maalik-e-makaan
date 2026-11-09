import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/csv.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/report_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Makes owner-statement PDFs; tests replace it.
final Provider<
  Future<Uint8List> Function(OwnerStatement statement, DocumentSetup setup)
>
ownerStatementMakerProvider = Provider((ref) => ownerStatementPdf);

/// Makes tax-year PDFs; tests replace it.
final Provider<
  Future<Uint8List> Function(TaxYearStatement statement, DocumentSetup setup)
>
taxYearMakerProvider = Provider((ref) => taxYearPdf);

/// Opens the owner statement (RPT-02): choose the month and the language,
/// then share the PDF.
Future<void> showOwnerStatement(
  BuildContext context,
  PortfolioMembership portfolio,
) => showMmSheet<void>(
  context,
  title: AppLocalizations.of(context).ownerStatementTitle,
  builder: (_) => OwnerStatementSheet(portfolio: portfolio),
);

/// The month and language of an owner statement, and sharing it.
class OwnerStatementSheet extends ConsumerStatefulWidget {
  const new({required this.portfolio, super.key});

  final PortfolioMembership portfolio;

  @override
  ConsumerState<OwnerStatementSheet> createState() =>
      _OwnerStatementSheetState();
}

class _OwnerStatementSheetState extends ConsumerState<OwnerStatementSheet>
    with CommandState {
  late final MonthPeriod _thisMonth = MonthPeriod.of(today(context));

  /// The last month in full, by default.
  late MonthPeriod _month = _thisMonth.previous;
  late DocumentLanguage _language = _languageOf(context);

  Future<void> _share() async {
    final setup = documentSetup(context, ref);
    final make = ref.read(ownerStatementMakerProvider);
    final share = ref.read(documentSharerProvider);
    final reader = ref.read(reportReaderProvider);
    final done = await runCommand(() async {
      final statement = await reader.ownerStatement(widget.portfolio, _month);
      final document = setup(_language);
      final words = lookupAppLocalizations(Locale(_language.code));
      final bytes = await _made(() => make(statement, document));
      await share((
        bytes: bytes,
        fileName: documentFileName('owner statement ${_month.toIso()}'),
        title: words.ownerStatementFileTitle(await _monthIn(_language, _month)),
      ));
    });
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmSelectField<MonthPeriod>(
          label: l10n.ownerStatementMonthLabel,
          options: [
            for (var back = 0; back < 12; back++)
              MmOption(
                value: _thisMonth.addMonths(-back),
                label: monthLabel(context, _thisMonth.addMonths(-back)),
              ),
          ],
          value: _month,
          onChanged: (month) => setState(() => _month = month),
        ),
        const SizedBox(height: MmSpace.s4),
        _LanguageChoice(
          value: _language,
          onChanged: (language) => setState(() => _language = language),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.shareDocumentAction,
          icon: MmIcons.share,
          busy: busy,
          onPressed: _share,
        ),
      ],
    );
  }
}

/// What can be exported (RPT-03).
enum ExportKind { ledger, payments, expenses }

/// A span to export, as the landlord names it.
typedef ExportPeriod = ({String label, CalendarDate from, CalendarDate to});

/// Opens the CSV export (RPT-03): choose what and which period, then share
/// the file.
Future<void> showExport(BuildContext context, PortfolioMembership portfolio) =>
    showMmSheet<void>(
      context,
      title: AppLocalizations.of(context).exportTitle,
      builder: (_) => ExportSheet(portfolio: portfolio),
    );

/// What to export and for which period, and sharing the CSV file.
class ExportSheet extends ConsumerStatefulWidget {
  const new({required this.portfolio, super.key});

  final PortfolioMembership portfolio;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> with CommandState {
  ExportKind _kind = ExportKind.ledger;
  int _period = 0;

  /// Set when the chosen period had nothing to export.
  bool _empty = false;

  /// This month, last month, this tax year and the one before.
  List<ExportPeriod> _periods(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = today(context);
    final month = MonthPeriod.of(day);
    final year = TaxYear.containing(day);
    ExportPeriod taxYear(TaxYear year) => (
      label: l10n.taxYearOption('${year.endYear}', '${year.endYear - 1}'),
      from: year.start,
      to: year.end,
    );
    return [
      (label: l10n.periodThisMonth, from: month.first, to: month.last),
      (
        label: l10n.periodLastMonth,
        from: month.previous.first,
        to: month.previous.last,
      ),
      taxYear(year),
      taxYear(year.previous),
    ];
  }

  String _kindLabel(AppLocalizations l10n, ExportKind kind) => switch (kind) {
    ExportKind.ledger => l10n.exportLedger,
    ExportKind.payments => l10n.exportPayments,
    ExportKind.expenses => l10n.exportExpenses,
  };

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final period = _periods(context)[_period];
    final reader = ref.read(reportReaderProvider);
    final share = ref.read(documentSharerProvider);
    final span = (
      portfolioId: widget.portfolio.id,
      from: period.from,
      to: period.to,
    );
    var empty = false;
    final done = await runCommand(() async {
      final rows = switch (_kind) {
        ExportKind.ledger => chargesTable(l10n, await reader.charges(span)),
        ExportKind.payments => paymentsTable(l10n, await reader.payments(span)),
        ExportKind.expenses => expensesTable(l10n, await reader.expenses(span)),
      };
      // Only the header: nothing to share.
      if (rows.length < 2) {
        empty = true;
        return;
      }
      await share((
        bytes: csvBytes(rows),
        fileName: documentFileName(
          '${_kind.name} ${period.from.toIso()} ${period.to.toIso()}',
          extension: 'csv',
        ),
        title: l10n.exportFileTitle(_kindLabel(l10n, _kind), period.label),
      ));
    });
    if (!mounted) return;
    setState(() => _empty = empty);
    if (done && !empty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final periods = _periods(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (_empty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
            child: MmBanner(tone: MmBannerTone.info, message: l10n.exportEmpty),
          ),
        MmRadioGroup<ExportKind>(
          label: l10n.exportWhatLabel,
          options: [
            for (final kind in ExportKind.values)
              MmOption(value: kind, label: _kindLabel(l10n, kind)),
          ],
          value: _kind,
          onChanged: (kind) {
            if (kind != null) {
              setState(() {
                _kind = kind;
                _empty = false;
              });
            }
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<int>(
          label: l10n.exportPeriodLabel,
          options: [
            for (final (index, period) in periods.indexed)
              MmOption(value: index, label: period.label),
          ],
          value: _period,
          onChanged: (index) => setState(() {
            _period = index;
            _empty = false;
          }),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.exportAction,
          icon: MmIcons.export,
          busy: busy,
          onPressed: _export,
        ),
      ],
    );
  }
}

/// The language a document is written in: the app's, unless chosen.
DocumentLanguage _languageOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ur'
    ? DocumentLanguage.urdu
    : DocumentLanguage.english;

/// [month] named in [language], as the document names it.
Future<String> _monthIn(DocumentLanguage language, MonthPeriod month) async {
  final words = await DocumentWords.load(
    DocumentSetup(language: language, issuer: '', today: month.first),
  );
  return words.month(month);
}

/// Runs a document maker, whose failures are not the server's.
Future<Uint8List> _made(Future<Uint8List> Function() make) async {
  try {
    return await make();
  } on Object catch (error) {
    throw UnexpectedFailure(error);
  }
}

/// Choosing the language of a document.
class _LanguageChoice extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final DocumentLanguage value;
  final ValueChanged<DocumentLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MmRadioGroup<DocumentLanguage>(
      label: l10n.documentLanguageLabel,
      options: [
        MmOption(value: DocumentLanguage.english, label: l10n.languageEnglish),
        MmOption(value: DocumentLanguage.urdu, label: l10n.languageUrdu),
      ],
      value: value,
      onChanged: (language) {
        if (language != null) onChanged(language);
      },
    );
  }
}

/// Shares [statement] as a PDF in the language the landlord picks (RPT-01).
Future<void> shareTaxYearPdf(
  BuildContext context,
  WidgetRef ref,
  TaxYearStatement statement,
) {
  final l10n = AppLocalizations.of(context);
  final setup = documentSetup(context, ref);
  final make = ref.read(taxYearMakerProvider);
  final year = '${statement.taxYear.endYear}';
  return showShareDocument(
    context,
    title: l10n.taxYearTitle,
    make: (language) async {
      final words = lookupAppLocalizations(Locale(language.code));
      return (
        bytes: await make(statement, setup(language)),
        fileName: documentFileName('tax year $year'),
        title: words.taxYearFileTitle(year),
      );
    },
  );
}

/// Shares [statement] as a CSV file, its headers in the app's language
/// (RPT-01).
Future<void> shareTaxYearCsv(
  BuildContext context,
  WidgetRef ref,
  TaxYearStatement statement,
) {
  final l10n = AppLocalizations.of(context);
  final year = '${statement.taxYear.endYear}';
  return ref.read(documentSharerProvider)((
    bytes: csvBytes(taxYearTable(l10n, statement)),
    fileName: documentFileName('tax year $year', extension: 'csv'),
    title: l10n.taxYearFileTitle(year),
  ));
}
