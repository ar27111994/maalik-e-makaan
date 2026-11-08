import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

/// The who-owes-what list of a portfolio (INS-02's data), the saved copy
/// first. The argument carries the member's role: owners, managers and
/// accountants first bring the portfolio's dues up to date.
final StreamNotifierProviderFamily<
  ReceivablesController,
  Snapshot<List<Receivable>>,
  PortfolioMembership
>
receivablesProvider = StreamNotifierProvider.autoDispose
    .family<
      ReceivablesController,
      Snapshot<List<Receivable>>,
      PortfolioMembership
    >(ReceivablesController.new);

/// Which portfolio's dues to bring up to date, on which day in Pakistan.
typedef BillingSync = ({String portfolioId, CalendarDate day});

/// Generates the dues the daily job may have missed (LEDGER-01: the app
/// heals missed runs), at most once per portfolio per day in Pakistan: an
/// app left open past midnight catches up on the next read of the list.
/// A failure is not kept: the next read of the list tries again.
final FutureProviderFamily<int, BillingSync> billingSyncProvider =
    FutureProvider.family<int, BillingSync>((ref, sync) async {
      // Once per signed-in user.
      ref.watch(currentUserIdProvider);
      try {
        return await ref
            .watch(ledgerRepositoryProvider)
            .syncBilling(sync.portfolioId);
      } on AppFailure {
        // The list is read anyway; the daily job runs regardless.
        unawaited(Future(ref.invalidateSelf));
        return 0;
      }
    });

/// Reads the who-owes-what list.
final class ReceivablesController extends SwrNotifier<List<Receivable>> {
  new(this.portfolio);

  final PortfolioMembership portfolio;

  @override
  String get query => 'receivables.${portfolio.id}';

  @override
  Stream<Snapshot<List<Receivable>>> build() {
    ref.watch(ledgerRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<Receivable>> fetch() async {
    if (portfolio.role.recordsMoney) {
      final day = ref.read(todayProvider);
      await ref.read(
        billingSyncProvider((portfolioId: portfolio.id, day: day)).future,
      );
    }
    return await ref.read(ledgerRepositoryProvider).receivables(portfolio.id);
  }

  @override
  List<Receivable> decode(Object? json) {
    final rows = JsonRow.of({'rows': json}).list('rows');
    return [for (final row in rows) Receivable.fromRow(row)];
  }

  @override
  Object? encode(List<Receivable> value) => [for (final r in value) r.toRow()];
}

/// A tenancy's money, the saved copy first.
final StreamNotifierProviderFamily<
  TenancyLedgerController,
  Snapshot<TenancyLedger>,
  String
>
tenancyLedgerProvider = StreamNotifierProvider.autoDispose
    .family<TenancyLedgerController, Snapshot<TenancyLedger>, String>(
      TenancyLedgerController.new,
    );

/// Reads a tenancy's money and changes it. Commands throw [AppFailure] and,
/// once the server has answered, show the ledger as it now is: money is
/// never shown as recorded before it is.
final class TenancyLedgerController extends SwrNotifier<TenancyLedger> {
  new(this.leaseId);

  final String leaseId;

  LedgerRepository get _repository => ref.read(ledgerRepositoryProvider);

  @override
  String get query => 'ledger.$leaseId';

  @override
  Stream<Snapshot<TenancyLedger>> build() {
    ref.watch(ledgerRepositoryProvider);
    return super.build();
  }

  @override
  Future<TenancyLedger> fetch() => _repository.ledger(leaseId);

  @override
  TenancyLedger decode(Object? json) => TenancyLedger.fromJson(json);

  @override
  Object? encode(TenancyLedger value) => value.toJson();

  /// Reads the next page of dues.
  Future<void> loadMoreCharges() async {
    final current = state.value?.value;
    final next = current?.charges.next;
    if (current == null || next == null) return;
    final more = await _repository.charges(leaseId, before: next);
    await show(current.copyWith(charges: current.charges.followedBy(more)));
  }

  /// Reads the next page of payments.
  Future<void> loadMorePayments() async {
    final current = state.value?.value;
    final next = current?.payments.next;
    if (current == null || next == null) return;
    final more = await _repository.payments(leaseId, before: next);
    await show(current.copyWith(payments: current.payments.followedBy(more)));
  }

  Future<void> _changed() async {
    ref
      ..invalidate(receivablesProvider)
      ..invalidate(paymentProvider);
    await reload();
  }

  /// Records a payment (LEDGER-03); keep [draft]'s idempotency key for
  /// retries of the same payment.
  Future<PaymentResult> recordPayment(PaymentDraft draft) async {
    final result = await _repository.recordPayment(draft);
    await _changed();
    return result;
  }

  Future<void> voidPayment(String paymentId, String reason) async {
    await _repository.voidPayment(paymentId, reason);
    await _changed();
  }

  /// Adds a charge by hand ([id] names this attempt: keep it for retries).
  Future<Charge> addCharge({
    required String id,
    required String portfolioId,
    required ChargeDraft draft,
  }) async {
    final charge = await _repository.addCharge(
      id: id,
      portfolioId: portfolioId,
      leaseId: leaseId,
      draft: draft,
    );
    await _changed();
    return charge;
  }

  Future<Charge> updateCharge(
    String chargeId, {
    Money? amount,
    CalendarDate? dueDate,
    String? description,
  }) async {
    final charge = await _repository.updateCharge(
      chargeId,
      amount: amount,
      dueDate: dueDate,
      description: description,
    );
    await _changed();
    return charge;
  }

  Future<Charge> waiveCharge(
    String chargeId, {
    required String reason,
    Money? amount,
  }) async {
    final charge = await _repository.waiveCharge(
      chargeId,
      reason: reason,
      amount: amount,
    );
    await _changed();
    return charge;
  }

  Future<Charge> voidCharge(String chargeId, String reason) async {
    final charge = await _repository.voidCharge(chargeId, reason);
    await _changed();
    return charge;
  }

  /// Settles dues from the deposit; keep [idempotencyKey] for retries.
  Future<PaymentResult> applyDeposit({
    required Money amount,
    required CalendarDate appliedOn,
    required String idempotencyKey,
    String? notes,
  }) async {
    final result = await _repository.applyDeposit(
      leaseId: leaseId,
      amount: amount,
      appliedOn: appliedOn,
      idempotencyKey: idempotencyKey,
      notes: notes,
    );
    await _changed();
    return result;
  }

  /// Pays deposit money back. The database takes no key for a refund, so
  /// after a lost connection the ledger is read again: a new refund of this
  /// amount, day and method there is the one sent, and is returned as
  /// recorded. Otherwise the [NetworkFailure] is rethrown, and the refund
  /// may still have been recorded (its answer and the read raced), so the
  /// caller must not send it again without the landlord checking.
  Future<DepositRefund> refundDeposit({
    required Money amount,
    required CalendarDate refundedOn,
    required PaymentMethod method,
    String? reference,
    String? notes,
  }) async {
    final before = {
      for (final r in state.value?.value.refunds ?? const <DepositRefund>[])
        r.id,
    };
    try {
      final refund = await _repository.refundDeposit(
        leaseId: leaseId,
        amount: amount,
        refundedOn: refundedOn,
        method: method,
        reference: reference,
        notes: notes,
      );
      await _changed();
      return refund;
    } on NetworkFailure {
      final fresh = await _readAgain();
      for (final refund in fresh?.refunds ?? const <DepositRefund>[]) {
        if (!before.contains(refund.id) &&
            !refund.voided &&
            refund.amount == amount &&
            refund.refundedOn == refundedOn &&
            refund.method == method) {
          ref.invalidate(receivablesProvider);
          return refund;
        }
      }
      rethrow;
    }
  }

  /// The ledger as the server now holds it, shown; null when it cannot be
  /// read (the query then starts over).
  Future<TenancyLedger?> _readAgain() async {
    try {
      final fresh = await fetch();
      await show(fresh);
      return fresh;
    } on AppFailure {
      if (ref.mounted) ref.invalidateSelf();
      return null;
    }
  }

  Future<void> voidRefund(String refundId, String reason) async {
    await _repository.voidDepositRefund(refundId, reason);
    await _changed();
  }

  /// Every due and payment, for the tenant statement.
  Future<LedgerStatement> statement() => _repository.statement(leaseId);
}

/// One payment with its tenancy and the dues it settled (its receipt), the
/// saved copy first.
final StreamNotifierProviderFamily<
  PaymentController,
  Snapshot<PaymentDetail>,
  String
>
paymentProvider = StreamNotifierProvider.autoDispose
    .family<PaymentController, Snapshot<PaymentDetail>, String>(
      PaymentController.new,
    );

/// Reads a payment for its receipt, and voids it.
final class PaymentController extends SwrNotifier<PaymentDetail> {
  new(this.paymentId);

  final String paymentId;

  LedgerRepository get _repository => ref.read(ledgerRepositoryProvider);

  @override
  String get query => 'payment.$paymentId';

  @override
  Stream<Snapshot<PaymentDetail>> build() {
    ref.watch(ledgerRepositoryProvider);
    return super.build();
  }

  @override
  Future<PaymentDetail> fetch() => _repository.payment(paymentId);

  @override
  PaymentDetail decode(Object? json) => PaymentDetail.fromRow(json);

  @override
  Object? encode(PaymentDetail value) => value.toJson();

  /// Voids the payment (LEDGER-06): the receipt stays, marked void.
  Future<void> voidPayment(String reason) async {
    final leaseId = state.value?.value.payment.leaseId;
    await _repository.voidPayment(paymentId, reason);
    ref.invalidate(receivablesProvider);
    if (leaseId != null) {
      ref
        ..invalidate(tenancyLedgerProvider(leaseId))
        ..invalidate(leaseProvider(leaseId));
    }
    await reload();
  }
}
