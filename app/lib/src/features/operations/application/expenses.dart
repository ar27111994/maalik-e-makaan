import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';

/// Which expenses a list shows: a portfolio's, or those of one maintenance
/// job (`requestId`).
typedef ExpenseList = ({String portfolioId, String? requestId});

/// A portfolio's (or a job's) expenses, the latest recorded first, the
/// saved copy first, 50 at a time.
final StreamNotifierProviderFamily<
  ExpensesController,
  Snapshot<Paged<Expense>>,
  ExpenseList
>
expensesProvider = StreamNotifierProvider.autoDispose
    .family<ExpensesController, Snapshot<Paged<Expense>>, ExpenseList>(
      ExpensesController.new,
    );

/// Every change to an expense changes the lists of expenses and, for cash
/// spent, the cash the member who paid holds.
void _expensesChanged(Ref ref) => ref
  ..invalidate(expensesProvider)
  ..invalidate(cashBookProvider);

/// Reads a list of expenses and adds new ones. Commands throw
/// [AppFailure].
final class ExpensesController extends SwrNotifier<Paged<Expense>> {
  new(this.list);

  final ExpenseList list;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'expenses.${list.portfolioId}.${list.requestId ?? 'all'}';

  @override
  Stream<Snapshot<Paged<Expense>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<Expense>> fetch() => _repository.expenses(
    list.portfolioId,
    maintenanceRequestId: list.requestId,
  );

  @override
  Paged<Expense> decode(Object? json) => Paged.fromJson(json, Expense.fromRow);

  @override
  Object? encode(Paged<Expense> value) => value.toJson((e) => e.toRow());

  /// Reads the next page and shows it after the rows already shown.
  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.expenses(
      list.portfolioId,
      maintenanceRequestId: list.requestId,
      before: next,
    );
    await show(current.followedBy(more));
  }

  /// Adds [draft] ([id] names this attempt: keep it for retries).
  Future<Expense> create(String id, ExpenseDraft draft) async {
    final created = await _repository.createExpense(
      id: id,
      portfolioId: list.portfolioId,
      draft: draft,
    );
    _expensesChanged(ref);
    return created;
  }
}

/// One expense, the saved copy first.
final StreamNotifierProviderFamily<ExpenseController, Snapshot<Expense>, String>
expenseProvider = StreamNotifierProvider.autoDispose
    .family<ExpenseController, Snapshot<Expense>, String>(
      ExpenseController.new,
    );

/// Reads an expense, saves and deletes it. Commands throw [AppFailure].
final class ExpenseController extends SwrNotifier<Expense> {
  new(this.expenseId);

  final String expenseId;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'expense.$expenseId';

  @override
  Stream<Snapshot<Expense>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<Expense> fetch() => _repository.expense(expenseId);

  @override
  Expense decode(Object? json) => Expense.fromRow(json);

  @override
  Object? encode(Expense value) => value.toRow();

  Future<Expense> save(ExpenseDraft draft) async {
    final saved = await _repository.updateExpense(expenseId, draft);
    _expensesChanged(ref);
    await show(saved);
    return saved;
  }

  /// Deletes the expense (owners and managers, for mistakes).
  Future<void> delete() async {
    await _repository.deleteExpense(expenseId);
    _expensesChanged(ref);
  }
}
