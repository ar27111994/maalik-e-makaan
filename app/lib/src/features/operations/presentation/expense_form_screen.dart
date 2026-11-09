import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/place_fields.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Adding an expense, or editing one ([expenseId]) (EXP-01): what it was
/// for, how much, when, where, to whom and how it was paid. Opened from a
/// maintenance job ([requestId]), the expense is for that job, at its
/// property and unit.
class ExpenseFormScreen extends ConsumerWidget {
  const new({this.expenseId, this.requestId, super.key});

  /// The expense edited; null to add one.
  final String? expenseId;

  /// The maintenance job a new expense pays for.
  final String? requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = expenseId;
    final request = requestId;
    if (id != null) {
      final state = ref.watch(expenseProvider(id));
      if (state.value?.value case final expense?) {
        return _ExpenseForm(key: ValueKey(expense.id), expense: expense);
      }
      return MmPage(
        title: l10n.editExpenseTitle,
        body: SnapshotView(
          state: state,
          onRetry: () => ref.invalidate(expenseProvider(id)),
          loadingLabel: l10n.loadingExpense,
          failedTitle: l10n.expenseLoadFailedTitle,
          builder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    if (request != null) {
      final state = ref.watch(maintenanceRequestProvider(request));
      if (state.value?.value case final job?) {
        return _ExpenseForm(key: ValueKey(job.id), request: job);
      }
      return MmPage(
        title: l10n.newExpenseTitle,
        body: SnapshotView(
          state: state,
          onRetry: () => ref.invalidate(maintenanceRequestProvider(request)),
          loadingLabel: l10n.loadingMaintenanceRequest,
          failedTitle: l10n.maintenanceRequestLoadFailedTitle,
          builder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    return const _ExpenseForm();
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const new({this.expense, this.request, super.key});

  final Expense? expense;

  /// The job a new expense pays for.
  final MaintenanceRequest? request;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> with CommandState {
  late final Expense? _old = widget.expense;
  late final MaintenanceRequest? _job = widget.request;

  /// Names this attempt to add: a retry adds nothing more.
  final String _attempt = newUuid();

  late ExpenseCategory? _category =
      _old?.category ??
      (_job == null ? null : ExpenseCategory.repairsMaintenance);
  late Money? _amount = _old?.amount;
  late CalendarDate _spentOn = _old?.spentOn ?? dates.today(context);
  late PlaceChoice _place = (
    propertyId: _old?.propertyId ?? _job?.propertyId,
    unitId: _old?.unitId ?? _job?.unitId,
  );
  late String? _requestId = _old?.maintenanceRequestId ?? _job?.id;
  late PaymentMethod _method = _old?.method ?? PaymentMethod.cash;
  late final _payee = TextEditingController(text: _old?.payee);
  late final _reference = TextEditingController(text: _old?.reference);
  late final _notes = TextEditingController(text: _old?.notes);
  bool _tried = false;

  @override
  void dispose() {
    _payee.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _back() {
    final old = _old;
    if (old != null) return Routes.expense(old.id);
    final job = _job;
    return job == null ? Routes.expenses : Routes.maintenanceRequest(job.id);
  }

  Future<void> _save(String portfolioId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final category = _category;
    final amount = _amount;
    if (category == null || amount == null || !amount.isPositive) return;
    final draft = ExpenseDraft(
      category: category,
      amount: amount,
      spentOn: _spentOn,
      method: _method,
      propertyId: _place.propertyId,
      unitId: _place.unitId,
      maintenanceRequestId: _place.propertyId == null ? null : _requestId,
      payee: _payee.text,
      reference: _reference.text,
      notes: _notes.text,
    );
    late Expense saved;
    final old = _old;
    final done = await runCommand(() async {
      saved = old == null
          ? await ref
                .read(
                  expensesProvider((portfolioId: portfolioId, requestId: null))
                      .notifier,
                )
                .create(_attempt, draft)
          : await ref.read(expenseProvider(old.id).notifier).save(draft);
    });
    if (!done || !mounted) return;
    // A retry finds the expense its first try stored, which the connection
    // lost: fields changed since then were not saved.
    final earlier = old == null && ExpenseDraft.of(saved) != draft;
    unawaited(
      showMmSnackbar(
        context,
        message: earlier
            ? l10n.savedEarlierUnchanged
            : old == null
            ? l10n.expenseAdded
            : l10n.expenseSaved,
        tone: earlier ? MmBannerTone.warning : MmBannerTone.success,
      ),
    );
    context.go(Routes.expense(saved.id));
  }

  /// The jobs this expense may pay for: those still to be done at its
  /// property, and the one it pays for now.
  List<MmOption<String?>> _jobs(String portfolioId, String propertyId) {
    final l10n = AppLocalizations.of(context);
    final pending = ref
        .watch(
          maintenanceListProvider((portfolioId: portfolioId, pending: true)),
        )
        .value
        ?.value
        .items;
    final current = _requestId;
    final currentTitle = _job?.title ?? _old?.maintenanceTitle;
    return [
      MmOption(value: null, label: l10n.noJobOption),
      if (current != null &&
          currentTitle != null &&
          !(pending ?? const []).any((r) => r.id == current))
        MmOption(value: current, label: currentTitle),
      for (final request in pending ?? const <MaintenanceRequest>[])
        if (request.propertyId == propertyId)
          MmOption(value: request.id, label: request.title),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    // Keeps what this form changes read while it is open.
    if (_old case final old?) ref.listen(expenseProvider(old.id), (_, _) {});
    if (_old == null && portfolio != null) {
      ref.listen(
        expensesProvider((portfolioId: portfolio.id, requestId: null)),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final today = dates.today(context);
    final propertyId = _place.propertyId;
    return MmPage(
      title: _old == null ? l10n.newExpenseTitle : l10n.editExpenseTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          if (_job case final job?) ...[
            MmBanner(
              tone: MmBannerTone.info,
              icon: MmIcons.maintenance,
              message: l10n.expenseForJob(job.title),
            ),
            const SizedBox(height: MmSpace.s4),
          ],
          MmFormSection(
            title: l10n.expenseSectionWhat,
            children: [
              MmSelectField<ExpenseCategory>(
                label: l10n.expenseCategoryLabel,
                required: true,
                errorText: _tried && _category == null
                    ? l10n.validationRequired
                    : null,
                options: [
                  for (final category in ExpenseCategory.values)
                    MmOption(
                      value: category,
                      label: l10n.expenseCategory(category),
                    ),
                ],
                value: _category,
                onChanged: (category) => setState(() => _category = category),
              ),
              MmMoneyField(
                label: l10n.amountLabel,
                value: _amount,
                required: true,
                allowZero: false,
                invalidText: l10n.validationAmount,
                errorText: _tried && _amount == null
                    ? l10n.validationAmount
                    : null,
                onChanged: (amount) => setState(() => _amount = amount),
              ),
              MmDateField(
                label: l10n.spentOnLabel,
                value: _spentOn,
                required: true,
                firstDate: today.addYears(-10),
                lastDate: today,
                onChanged: (date) {
                  if (date != null) setState(() => _spentOn = date);
                },
              ),
            ],
          ),
          const SizedBox(height: MmSpace.s8),
          MmFormSection(
            title: l10n.expenseSectionWhere,
            children: [
              if (portfolio != null)
                PlaceFields(
                  portfolioId: portfolio.id,
                  value: _place,
                  propertyName: _old?.propertyName ?? _job?.propertyName,
                  unitLabel: _old?.unitLabel ?? _job?.unitLabel,
                  propertyHelper: l10n.expensePropertyHelp,
                  onChanged: (place) => setState(() {
                    if (place.propertyId != _place.propertyId) {
                      _requestId = null;
                    }
                    _place = place;
                  }),
                ),
              if (portfolio != null && propertyId != null)
                MmSelectField<String?>(
                  label: l10n.maintenanceJobLabel,
                  optional: true,
                  helper: l10n.maintenanceJobHelp,
                  options: _jobs(portfolio.id, propertyId),
                  value: _requestId,
                  onChanged: (id) => setState(() => _requestId = id),
                ),
            ],
          ),
          const SizedBox(height: MmSpace.s8),
          MmFormSection(
            title: l10n.expenseSectionPaid,
            children: [
              MmTextField(
                label: l10n.payeeLabel,
                controller: _payee,
                optional: true,
                helper: l10n.payeeHelp,
                maxLength: Expense.maxPayeeLength,
                inputFormatters: codePointLimit(Expense.maxPayeeLength),
                textCapitalization: TextCapitalization.words,
              ),
              MmSelectField<PaymentMethod>(
                label: l10n.paidWithLabel,
                required: true,
                helper: _method == PaymentMethod.cash
                    ? l10n.expenseCashHelp
                    : null,
                options: [
                  for (final method in PaymentMethod.received)
                    MmOption(value: method, label: l10n.paymentMethod(method)),
                ],
                value: _method,
                onChanged: (method) => setState(() => _method = method),
              ),
              MmTextField(
                label: l10n.paymentReferenceLabel,
                controller: _reference,
                optional: true,
                maxLength: Expense.maxReferenceLength,
                inputFormatters: codePointLimit(Expense.maxReferenceLength),
              ),
              MmTextField(
                label: l10n.notesLabel,
                controller: _notes,
                optional: true,
                minLines: 3,
                maxLines: 8,
                maxLength: Expense.maxNotesLength,
                inputFormatters: codePointLimit(Expense.maxNotesLength),
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ],
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: l10n.cancelAction,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => context.go(_back()),
        ),
        primary: MmButton(
          label: l10n.saveAction,
          busy: busy,
          onPressed: portfolio == null ? null : () => _save(portfolio.id),
        ),
      ),
    );
  }
}
