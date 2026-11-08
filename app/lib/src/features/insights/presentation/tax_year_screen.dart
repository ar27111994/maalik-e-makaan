import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/statement_sheets.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The tax-year statement (RPT-01): for a tax year (July to June), each
/// property's gross rent, the tax tenants withheld, the one-fifth repairs
/// allowance, the rent after it and the expenses recorded, with the
/// totals; shared as a PDF or a CSV file. It says first that it is not tax
/// advice, and works out no tax.
class TaxYearScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// How many tax years back the landlord can choose from.
  static const yearsShown = 6;

  @override
  ConsumerState<TaxYearScreen> createState() => _TaxYearScreenState();
}

class _TaxYearScreenState extends ConsumerState<TaxYearScreen>
    with CommandState {
  late final TaxYear _current = TaxYear.containing(today(context));
  late TaxYear _year = _current;

  Future<void> _shareCsv(TaxYearStatement statement) =>
      runCommand(() => shareTaxYearCsv(context, ref, statement));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final provider = portfolio == null
        ? null
        : taxYearProvider((portfolioId: portfolio.id, taxYear: _year));
    final statement = provider == null
        ? null
        : ref.watch(provider).value?.value;
    final failure = this.failure;
    return MmPage(
      title: l10n.taxYearTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          MmBanner(
            tone: MmBannerTone.info,
            title: l10n.notTaxAdviceTitle,
            message: l10n.notTaxAdviceBody,
          ),
          const SizedBox(height: MmSpace.s4),
          MmSelectField<TaxYear>(
            label: l10n.taxYearLabel,
            options: [
              for (var back = 0; back < TaxYearScreen.yearsShown; back++)
                MmOption(
                  value: TaxYear(_current.endYear - back),
                  label: l10n.taxYearOption(
                    '${_current.endYear - back}',
                    '${_current.endYear - back - 1}',
                  ),
                ),
            ],
            value: _year,
            onChanged: (year) => setState(() => _year = year),
          ),
          const SizedBox(height: MmSpace.s6),
          if (provider != null)
            SnapshotView(
              state: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              loadingLabel: l10n.loadingTaxYear,
              failedTitle: l10n.taxYearLoadFailedTitle,
              builder: (statement) => _Statement(statement: statement),
            ),
        ],
      ),
      bottomBar: statement == null || statement.properties.isEmpty
          ? null
          : MmActionBar(
              primary: MmButton(
                label: l10n.shareDocumentAction,
                icon: MmIcons.share,
                onPressed: () => shareTaxYearPdf(context, ref, statement),
              ),
              secondary: MmButton(
                label: l10n.shareCsvAction,
                icon: MmIcons.spreadsheet,
                variant: MmButtonVariant.secondary,
                busy: busy,
                onPressed: () => _shareCsv(statement),
              ),
            ),
    );
  }
}

class _Statement extends StatelessWidget {
  const new({required this.statement});

  final TaxYearStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    if (statement.properties.isEmpty) {
      return MmEmptyState(
        icon: MmIcons.receiptText,
        title: l10n.taxYearEmpty,
        message: l10n.taxYearSummary,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final property in statement.properties) ...[
          _Figures(
            title: property.propertyName,
            userData: true,
            gross: property.grossRent,
            tax: property.taxWithheld,
            allowance: property.repairsAllowance,
            net: property.netAfterRepairsAllowance,
            spent: property.expensesByCategory,
            expenses: property.expensesTotal,
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        if (statement.properties.length > 1) ...[
          _Figures(
            title: l10n.allPropertiesLabel,
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
          const SizedBox(height: MmSpace.s3),
        ],
        Text(
          l10n.deductibleNote,
          style: text.bodyMedium!.copyWith(color: context.mm.colors.inkMuted),
        ),
      ],
    );
  }
}

/// One property's (or every property's) figures for the tax year.
class _Figures extends StatelessWidget {
  const new({
    required this.title,
    required this.gross,
    required this.tax,
    required this.allowance,
    required this.net,
    required this.spent,
    required this.expenses,
    this.userData = false,
  });

  final String title;
  final bool userData;
  final Money gross;
  final Money tax;
  final Money allowance;
  final Money net;
  final Map<ExpenseCategory, Money> spent;
  final Money expenses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleMedium!;
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: userData ? context.mm.styleFor(title, style) : style,
            ),
          ),
          const SizedBox(height: MmSpace.s2),
          MmDetailRow.amount(label: l10n.grossRentLabel, amount: gross),
          MmDetailRow.amount(label: l10n.taxWithheldLabel, amount: tax),
          MmDetailRow.amount(
            label: l10n.repairsAllowanceLabel,
            amount: allowance,
          ),
          MmDetailRow.amount(
            label: l10n.netAfterAllowanceLabel,
            amount: net,
            emphasized: true,
          ),
          if (spent.isNotEmpty) ...[
            const SizedBox(height: MmSpace.s2),
            const Divider(height: MmSize.hairline),
            for (final category in ExpenseCategory.values)
              if (spent[category] case final amount?)
                MmDetailRow.amount(
                  label: l10n.expenseCategory(category),
                  amount: amount,
                ),
          ],
          MmDetailRow.amount(
            label: l10n.expensesRecordedLabel,
            amount: expenses,
          ),
        ],
      ),
    );
  }
}
