import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A tenancy's money: dues, payments, the deposit, and the portfolio's
/// who-owes-what list. Every method throws [AppFailure].
///
/// Money changes go through the database's functions
/// (`docs/architecture/permissions.md`): owners, managers and accountants
/// record payments, add charges and edit them (`update_charge`; clients
/// cannot `UPDATE` charges); owners and managers void payments, void or
/// waive charges and apply or refund the deposit; only owners void a
/// refund.
abstract interface class LedgerRepository {
  /// A tenancy's balance, open dues, latest dues and payments, deposit and
  /// refunds.
  Future<TenancyLedger> ledger(String leaseId);

  /// The page of a tenancy's dues (every state) before [before], newest
  /// first.
  Future<Paged<Charge>> charges(String leaseId, {PageCursor? before});

  /// The page of a tenancy's payments before [before], newest first.
  Future<Paged<Payment>> payments(String leaseId, {PageCursor? before});

  /// Every tenancy of [portfolioId] that runs, owes or holds credit, the
  /// most overdue first (`get_receivables`).
  Future<List<Receivable>> receivables(String portfolioId);

  /// Generates the rent and late fees the daily job may have missed
  /// (`sync_portfolio_billing`; owners, managers and accountants) and says
  /// how many dues it added.
  Future<int> syncBilling(String portfolioId);

  /// Records [draft] (`record_payment`). A retry with the same idempotency
  /// key answers the payment it recorded. Refusals: `invalid_amount`,
  /// `invalid_tax_withheld`, `invalid_method`, `invalid_date`,
  /// `invalid_charge_selection`, `idempotency_key_reused`.
  Future<PaymentResult> recordPayment(PaymentDraft draft);

  /// One payment with its tenancy and the dues it settled.
  Future<PaymentDetail> payment(String paymentId);

  /// Voids a payment with [reason] (`void_payment`); the dues it settled are
  /// owed again. Refusals: `reason_required`, `deposit_already_used`.
  Future<void> voidPayment(String paymentId, String reason);

  /// Adds a charge by hand, under the id chosen for this attempt.
  Future<Charge> addCharge({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ChargeDraft draft,
  });

  /// Changes a charge's amount (charges added by hand only), due date or
  /// note (`update_charge`); a null argument keeps the value, an empty
  /// [description] clears the note. Refusals: `charge_voided`,
  /// `charge_not_editable`, `invalid_amount`.
  Future<Charge> updateCharge(
    String chargeId, {
    Money? amount,
    CalendarDate? dueDate,
    String? description,
  });

  /// Forgives [amount] (all that is owed when null) of a charge
  /// (`waive_charge`). Refusals: `reason_required`, `charge_voided`,
  /// `invalid_amount`, `amount_exceeds_outstanding`.
  Future<Charge> waiveCharge(
    String chargeId, {
    required String reason,
    Money? amount,
  });

  /// Cancels a charge no money paid (`void_charge`), with its unpaid
  /// automatic late fee. Refusals: `reason_required`, `charge_has_payments`.
  Future<Charge> voidCharge(String chargeId, String reason);

  /// Settles dues from the deposit held (`apply_deposit`). Refusals:
  /// `invalid_amount`, `invalid_date`, `insufficient_deposit`,
  /// `amount_exceeds_outstanding`, `idempotency_key_reused`.
  Future<PaymentResult> applyDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate appliedOn,
    required String idempotencyKey,
    String? notes,
  });

  /// Pays deposit money back to the tenant (`refund_deposit`). Refusals:
  /// `invalid_amount`, `invalid_method`, `invalid_date`,
  /// `insufficient_deposit`.
  Future<DepositRefund> refundDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate refundedOn,
    required PaymentMethod method,
    String? reference,
    String? notes,
  });

  /// Voids a refund recorded by mistake (`void_deposit_refund`; owners).
  Future<DepositRefund> voidDepositRefund(String refundId, String reason);

  /// Every due and payment of a tenancy, oldest first, for its statement.
  Future<LedgerStatement> statement(String leaseId);
}

/// [LedgerRepository] over `charges`, `payments`, `deposit_refunds`,
/// `lease_balances` and the ledger functions.
final class SupabaseLedgerRepository implements LedgerRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<TenancyLedger> ledger(String leaseId) => _guard(() async {
    final (lease, balance, open, charges, payments, deposit, refunds) = await (
      _client.from('leases').select(Lease.columns).eq('id', leaseId).single(),
      _client
          .from('lease_balances')
          .select(LeaseBalance.columns)
          .eq('lease_id', leaseId)
          .maybeSingle(),
      _client
          .from('charges')
          .select(Charge.columns)
          .eq('lease_id', leaseId)
          .isFilter('voided_at', null)
          .gt('outstanding', 0)
          .order('due_date', ascending: true)
          .order('id', ascending: true),
      _chargePage(leaseId, null),
      _paymentPage(leaseId, null),
      _client.rpc<Object?>(
        'get_deposit_position',
        params: {'p_lease_id': leaseId},
      ),
      _client
          .from('deposit_refunds')
          .select(DepositRefund.columns)
          .eq('lease_id', leaseId)
          .order('created_at', ascending: false)
          .order('id', ascending: false),
    ).wait;
    return TenancyLedger(
      lease: Lease.fromRow(lease),
      balance: balance == null
          ? const LeaseBalance()
          : LeaseBalance.fromRow(balance),
      openCharges: open.map(Charge.fromRow).toList(),
      charges: charges,
      payments: payments,
      deposit: deposit == null
          ? DepositPosition.none
          : DepositPosition.fromJson(deposit),
      refunds: refunds.map(DepositRefund.fromRow).toList(),
    );
  });

  Future<Paged<Charge>> _chargePage(String leaseId, PageCursor? before) async {
    final rows = await _client
        .from('charges')
        .select(Charge.columns)
        .eq('lease_id', leaseId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(Charge.fromRow).toList(), (c) => c.cursor);
  }

  Future<Paged<Payment>> _paymentPage(
    String leaseId,
    PageCursor? before,
  ) async {
    final rows = await _client
        .from('payments')
        .select(Payment.columns)
        .eq('lease_id', leaseId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(Payment.fromRow).toList(), (p) => p.cursor);
  }

  @override
  Future<Paged<Charge>> charges(String leaseId, {PageCursor? before}) =>
      _guard(() => _chargePage(leaseId, before));

  @override
  Future<Paged<Payment>> payments(String leaseId, {PageCursor? before}) =>
      _guard(() => _paymentPage(leaseId, before));

  @override
  Future<List<Receivable>> receivables(String portfolioId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_receivables',
      params: {'p_portfolio_id': portfolioId},
    );
    return rows.map(Receivable.fromRow).toList();
  });

  @override
  Future<int> syncBilling(String portfolioId) => _guard(() async {
    final created = await _client.rpc<Object?>(
      'sync_portfolio_billing',
      params: {'p_portfolio_id': portfolioId},
    );
    if (created is! int) throw FormatException('not a count', created);
    return created;
  });

  @override
  Future<PaymentResult> recordPayment(PaymentDraft draft) => _guard(() async {
    final result = await _client.rpc<Object?>(
      'record_payment',
      params: draft.toParams(),
    );
    return PaymentResult.fromJson(result);
  });

  @override
  Future<PaymentDetail> payment(String paymentId) => _guard(() async {
    final row = await _client
        .from('payments')
        .select(PaymentDetail.columns)
        .eq('id', paymentId)
        .single();
    return PaymentDetail.fromRow(row);
  });

  @override
  Future<void> voidPayment(String paymentId, String reason) => _guard(() async {
    await _client.rpc<Object?>(
      'void_payment',
      params: {'p_payment_id': paymentId, 'p_reason': _reason(reason)},
    );
  });

  @override
  Future<Charge> addCharge({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ChargeDraft draft,
  }) => _guard(() async {
    try {
      final row = await _client
          .from('charges')
          .insert({
            'id': id,
            'portfolio_id': portfolioId,
            'lease_id': leaseId,
            ...draft.toWrite(),
          })
          .select(Charge.columns)
          .single();
      return Charge.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A retry of an insert that reached the server: the charge exists.
      final row = await _client
          .from('charges')
          .select(Charge.columns)
          .eq('id', id)
          .single();
      return Charge.fromRow(row);
    }
  });

  @override
  Future<Charge> updateCharge(
    String chargeId, {
    Money? amount,
    CalendarDate? dueDate,
    String? description,
  }) => _guard(() async {
    final row = await _client.rpc<Object?>(
      'update_charge',
      params: {
        'p_charge_id': chargeId,
        'p_amount': amount?.toJson(),
        'p_due_date': dueDate?.toJson(),
        // Empty clears the note; null keeps it.
        'p_description': description == null
            ? null
            : singleLineWithin(description, Charge.maxDescriptionLength),
      },
    );
    return Charge.fromRow(row);
  });

  @override
  Future<Charge> waiveCharge(
    String chargeId, {
    required String reason,
    Money? amount,
  }) => _guard(() async {
    final row = await _client.rpc<Object?>(
      'waive_charge',
      params: {
        'p_charge_id': chargeId,
        'p_reason': _reason(reason),
        'p_amount': amount?.toJson(),
      },
    );
    return Charge.fromRow(row);
  });

  @override
  Future<Charge> voidCharge(String chargeId, String reason) => _guard(() async {
    final row = await _client.rpc<Object?>(
      'void_charge',
      params: {'p_charge_id': chargeId, 'p_reason': _reason(reason)},
    );
    return Charge.fromRow(row);
  });

  @override
  Future<PaymentResult> applyDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate appliedOn,
    required String idempotencyKey,
    String? notes,
  }) => _guard(() async {
    final result = await _client.rpc<Object?>(
      'apply_deposit',
      params: {
        'p_lease_id': leaseId,
        'p_amount': amount.toJson(),
        'p_applied_on': appliedOn.toJson(),
        'p_idempotency_key': idempotencyKey,
        'p_notes': optionalText(notes, Payment.maxNotesLength),
      },
    );
    return PaymentResult.fromJson(result);
  });

  @override
  Future<DepositRefund> refundDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate refundedOn,
    required PaymentMethod method,
    String? reference,
    String? notes,
  }) => _guard(() async {
    final row = await _client.rpc<Object?>(
      'refund_deposit',
      params: {
        'p_lease_id': leaseId,
        'p_amount': amount.toJson(),
        'p_refunded_on': refundedOn.toJson(),
        'p_method': method.db,
        'p_reference': optionalText(reference, Payment.maxReferenceLength),
        'p_notes': optionalText(notes, Payment.maxNotesLength),
      },
    );
    return DepositRefund.fromRow(row);
  });

  @override
  Future<DepositRefund> voidDepositRefund(String refundId, String reason) =>
      _guard(() async {
        final row = await _client.rpc<Object?>(
          'void_deposit_refund',
          params: {'p_refund_id': refundId, 'p_reason': _reason(reason)},
        );
        return DepositRefund.fromRow(row);
      });

  @override
  Future<LedgerStatement> statement(String leaseId) => _guard(() async {
    final ledger = await this.ledger(leaseId);
    var charges = ledger.charges;
    for (var next = charges.next; next != null; next = charges.next) {
      charges = charges.followedBy(await _chargePage(leaseId, next));
    }
    var payments = ledger.payments;
    for (var next = payments.next; next != null; next = payments.next) {
      payments = payments.followedBy(await _paymentPage(leaseId, next));
    }
    int byDay(CalendarDate a, CalendarDate b, String idA, String idB) {
      final day = a.compareTo(b);
      return day != 0 ? day : idA.compareTo(idB);
    }

    return LedgerStatement(
      lease: ledger.lease,
      charges: [...charges.items]
        ..sort((a, b) => byDay(a.dueDate, b.dueDate, a.id, b.id)),
      payments: [...payments.items]
        ..sort((a, b) => byDay(a.paidOn, b.paidOn, a.id, b.id)),
      deposit: ledger.deposit,
      refunds: ledger.refunds.reversed.toList(),
    );
  });

  static String _reason(String reason) =>
      singleLineWithin(reason, Charge.maxReasonLength);
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => SupabaseLedgerRepository(ref.watch(supabaseClientProvider)),
);
