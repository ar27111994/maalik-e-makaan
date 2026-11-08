import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Expenses (EXP-01): what was spent on the portfolio, its properties and
/// units, the latest recorded first, 50 at a time, each leading to its
/// details and receipts. Owners, managers and accountants add them.
class ExpensesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    return MmPage(
      title: l10n.expensesTitle,
      body: portfolio == null
          ? const SizedBox.shrink()
          : ExpensesList(
              list: (portfolioId: portfolio.id, requestId: null),
              empty: MmEmptyState(
                icon: MmIcons.receiptText,
                title: l10n.expensesEmptyTitle,
                message: l10n.expensesEmptyBody,
              ),
            ),
      bottomBar: portfolio != null && portfolio.role.recordsOperations
          ? MmActionBar(
              primary: MmButton(
                label: l10n.addExpenseAction,
                icon: MmIcons.add,
                onPressed: () => context.go(Routes.newExpense()),
              ),
            )
          : null,
    );
  }
}

/// A list of expenses read a page at a time, or [empty] when there are
/// none.
class ExpensesList extends ConsumerWidget {
  const new({required this.list, required this.empty, super.key});

  final ExpenseList list;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = expensesProvider(list);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingExpenses,
      failedTitle: l10n.expensesLoadFailedTitle,
      builder: (page) => page.items.isEmpty
          ? empty
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListCard(
                  children: [
                    for (final expense in page.items)
                      ExpenseTile(expense: expense),
                  ],
                ),
                if (page.hasMore)
                  LoadMoreButton(
                    onLoad: () => ref.read(provider.notifier).loadMore(),
                  ),
              ],
            ),
    );
  }
}

/// An expense in a list: what it was for, then when, where and to whom,
/// with its amount at the end edge, where a list of money lines its
/// figures up (DESIGN.md, Layout). The amount always sits under the text
/// ([BelowText]): beside a short title and under a long one, the figures
/// of one list would not share a column.
class ExpenseTile extends StatelessWidget {
  const new({required this.expense, super.key});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final property = expense.propertyName;
    return MmListTile(
      leading: const Icon(MmIcons.receiptText),
      title: l10n.expenseCategory(expense.category),
      subtitle: appText(
        detailLine([
          dateInLine(context, expense.spentOn),
          if (property != null)
            placeLabel(context, property, expense.unitLabel)
          else
            l10n.wholePortfolioOption,
          if (expense.payee case final payee?) inSentence(payee, direction),
        ]),
        direction,
      ),
      subtitleMaxLines: null,
      trailing: BelowText(child: MmAmount(amount: expense.amount)),
      onTap: () => context.go(Routes.expense(expense.id)),
    );
  }
}

/// One expense: its amount, what, when, where and to whom it was paid,
/// the maintenance job it paid for, its receipts ([extras]), and for the
/// roles that may, editing and deleting it.
class ExpenseDetailScreen extends ConsumerWidget {
  const new({required this.expenseId, this.extras, super.key});

  final String expenseId;

  /// Content from other features (the expense's receipts).
  final Widget Function(Expense expense)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(expenseProvider(expenseId));
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final extras = this.extras;
    return MmPage(
      title: l10n.expenseTitle,
      actions: [
        if (state.hasValue && (role?.recordsOperations ?? false))
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editExpense(expenseId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(expenseProvider(expenseId)),
        loadingLabel: l10n.loadingExpense,
        failedTitle: l10n.expenseLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (expense) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Details(expense: expense),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(expense),
            ],
            if (role != null && role.deletesOperations) ...[
              const SizedBox(height: MmSpace.s8),
              _DeleteExpense(expense: expense),
            ],
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const new({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final property = expense.propertyName;
    final request = expense.maintenanceRequestId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmAmount(amount: expense.amount, size: MmAmountSize.large),
        const SizedBox(height: MmSpace.s2),
        Text(
          l10n.expenseCategory(expense.category),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MmSpace.s4),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.spentOnLabel,
                value: dateLabel(context, expense.spentOn),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.propertyLabel,
                value: property ?? l10n.wholePortfolioOption,
                userData: property != null,
              ),
              if (expense.unitLabel case final unit?)
                MmDetailRow(label: l10n.unitLabel, value: unit),
              if (expense.payee case final payee?)
                MmDetailRow(label: l10n.payeeLabel, value: payee),
              MmDetailRow(
                label: l10n.paidWithLabel,
                value: l10n.paymentMethod(expense.method),
                userData: false,
              ),
              if (expense.reference case final reference?)
                MmDetailRow(
                  label: l10n.paymentReferenceLabel,
                  value: reference,
                ),
              if (expense.notes case final notes?)
                MmDetailRow.prose(label: l10n.notesLabel, value: notes),
            ],
          ),
        ),
        if (request != null) ...[
          const SizedBox(height: MmSpace.s3),
          ListCard(
            children: [
              MmListTile(
                leading: const Icon(MmIcons.maintenance),
                title: l10n.paidForJobLabel,
                subtitle: expense.maintenanceTitle,
                subtitleMaxLines: 4,
                chevron: true,
                onTap: () => context.go(Routes.maintenanceRequest(request)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeleteExpense extends ConsumerStatefulWidget {
  const new({required this.expense});

  final Expense expense;

  @override
  ConsumerState<_DeleteExpense> createState() => _DeleteExpenseState();
}

class _DeleteExpenseState extends ConsumerState<_DeleteExpense>
    with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteExpenseTitle,
      message: l10n.deleteExpenseBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref.read(expenseProvider(widget.expense.id).notifier).delete(),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.expenseDeleted,
        tone: MmBannerTone.success,
      ),
    );
    final request = widget.expense.maintenanceRequestId;
    context.go(
      request == null ? Routes.expenses : Routes.maintenanceRequest(request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmButton(
          label: l10n.deleteAction,
          icon: MmIcons.delete,
          // It asks first (or opens the flow that does): the filled red
          // button is at the point of no return.
          variant: MmButtonVariant.destructiveOutlined,
          busy: busy,
          onPressed: _delete,
        ),
      ],
    );
  }
}
