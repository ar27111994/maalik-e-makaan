import 'dart:typed_data';

import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover_repository.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger_repository.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder_repository.dart';
import 'package:mm_core/mm_core.dart';

import 'fakes.dart';

const _created = '2026-11-01T05:00:00+00:00';

Charge _rent(int month, {Money paid = Money.zero, String id = ''}) => Charge(
  id: id.isEmpty ? 'ch-rent-$month' : id,
  leaseId: aliLease.id,
  kind: ChargeKind.rent,
  source: ChargeSource.autoRent,
  periodMonth: MonthPeriod(2026, month),
  dueDate: CalendarDate(2026, month, 5),
  amount: const Money.fromRupees(85000),
  paidAmount: paid,
  createdAt: '2026-${month.toString().padLeft(2, '0')}-01T00:05:00+00:00',
);

/// Ali Raza's dues: the deposit and September's rent paid, October's
/// partly paid with its late fee owed, November's owed, an electricity bill
/// due in three days, a plumber visit waived and a charge voided.
List<Charge> aliCharges() => [
  Charge(
    id: 'ch-deposit',
    leaseId: aliLease.id,
    kind: ChargeKind.securityDeposit,
    source: ChargeSource.deposit,
    dueDate: CalendarDate(2026, 1, 15),
    amount: const Money.fromRupees(170000),
    paidAmount: const Money.fromRupees(170000),
    createdAt: '2026-01-10T07:00:00+00:00',
  ),
  _rent(9, paid: const Money.fromRupees(85000)),
  _rent(10, paid: const Money.fromRupees(60000)),
  Charge(
    id: 'ch-fee-10',
    leaseId: aliLease.id,
    kind: ChargeKind.lateFee,
    source: ChargeSource.autoLateFee,
    dueDate: CalendarDate(2026, 10, 11),
    amount: const Money.fromRupees(5000),
    relatedChargeId: 'ch-rent-10',
    createdAt: '2026-10-11T00:05:00+00:00',
  ),
  Charge(
    id: 'ch-plumber',
    leaseId: aliLease.id,
    kind: ChargeKind.maintenance,
    source: ChargeSource.manual,
    dueDate: CalendarDate(2026, 10, 20),
    amount: const Money.fromRupees(2000),
    waivedAmount: const Money.fromRupees(2000),
    description: 'Plumber, kitchen tap',
    waiveReason: 'Our fault: old pipe',
    createdAt: '2026-10-20T06:00:00+00:00',
  ),
  Charge(
    id: 'ch-other',
    leaseId: aliLease.id,
    kind: ChargeKind.other,
    source: ChargeSource.manual,
    dueDate: CalendarDate(2026, 10, 25),
    amount: const Money.fromRupees(1500),
    description: 'Gate key',
    voidedAt: DateTime.utc(2026, 10, 26, 6),
    voidReason: 'Entered for the wrong tenant',
    createdAt: '2026-10-25T06:00:00+00:00',
  ),
  _rent(11),
  Charge(
    id: 'ch-electricity',
    leaseId: aliLease.id,
    kind: ChargeKind.electricity,
    source: ChargeSource.manual,
    periodMonth: MonthPeriod(2026, 10),
    dueDate: CalendarDate(2026, 11, 10),
    amount: const Money.fromRupees(7450),
    description: 'LESCO, October',
    createdAt: _created,
  ),
];

/// Ali Raza's payments: September's rent in cash, part of October's by
/// bank transfer, and a payment voided as entered twice.
List<Payment> aliPayments() => [
  Payment(
    id: 'pay-deposit',
    leaseId: aliLease.id,
    amount: const Money.fromRupees(170000),
    paidOn: CalendarDate(2026, 1, 15),
    method: PaymentMethod.bankTransfer,
    receiptNumber: 'MM-2026-00002',
    allocatedAmount: const Money.fromRupees(170000),
    allocations: const [
      Allocation(chargeId: 'ch-deposit', amount: Money.fromRupees(170000)),
    ],
    createdAt: '2026-01-15T07:00:00+00:00',
  ),
  Payment(
    id: 'pay-sep',
    leaseId: aliLease.id,
    amount: const Money.fromRupees(85000),
    paidOn: CalendarDate(2026, 9, 4),
    method: PaymentMethod.cash,
    receiptNumber: 'MM-2026-00035',
    allocatedAmount: const Money.fromRupees(85000),
    allocations: const [
      Allocation(chargeId: 'ch-rent-9', amount: Money.fromRupees(85000)),
    ],
    createdAt: '2026-09-04T07:00:00+00:00',
  ),
  Payment(
    id: 'pay-twice',
    leaseId: aliLease.id,
    amount: const Money.fromRupees(10000),
    paidOn: CalendarDate(2026, 9, 20),
    method: PaymentMethod.cash,
    receiptNumber: 'MM-2026-00038',
    voidedAt: DateTime.utc(2026, 9, 21, 6),
    voidReason: 'Entered twice',
    createdAt: '2026-09-20T07:00:00+00:00',
  ),
  Payment(
    id: 'pay-oct',
    leaseId: aliLease.id,
    amount: const Money.fromRupees(60000),
    paidOn: CalendarDate(2026, 10, 6),
    method: PaymentMethod.bankTransfer,
    reference: 'IBFT 778812',
    receiptNumber: 'MM-2026-00041',
    allocatedAmount: const Money.fromRupees(60000),
    allocations: const [
      Allocation(chargeId: 'ch-rent-10', amount: Money.fromRupees(60000)),
    ],
    createdAt: '2026-10-06T07:00:00+00:00',
  ),
];

/// Indus Tech's tenancy of a shop: rent not yet due, tax withheld last
/// month.
const techLeaseId = '0192d0c4-5555-7000-8000-000000000003';

/// A [LedgerRepository] over in-memory dues and payments that settles them
/// as the database does (chosen dues first, then the oldest).
final class FakeLedgerRepository implements LedgerRepository {
  new() {
    chargesOf[aliLease.id] = aliCharges();
    paymentsOf[aliLease.id] = aliPayments();
    chargesOf[endedLease.id] = [];
    paymentsOf[endedLease.id] = [
      Payment(
        id: 'pay-hamid',
        leaseId: endedLease.id,
        amount: const Money.fromRupees(15000),
        paidOn: CalendarDate(2026, 8, 25),
        method: PaymentMethod.raast,
        receiptNumber: 'MM-2026-00030',
        createdAt: '2026-08-25T07:00:00+00:00',
      ),
    ];
  }

  final Map<String, List<Charge>> chargesOf = {};
  final Map<String, List<Payment>> paymentsOf = {};
  final Map<String, List<DepositRefund>> refunds = {};
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;

  /// Refusals the next writes meet, in turn.
  final writeFailures = <AppFailure>[];

  /// Writes, by name, that are made but whose answer is lost on the way
  /// back (a [NetworkFailure] after the change).
  final lostAnswers = <String>{};

  /// Throws a [NetworkFailure] when the answer of the write [name] is lost.
  void _answer(String name) {
    if (lostAnswers.remove(name)) throw const NetworkFailure();
  }

  int pageLimit = pageSize;
  int _receipt = 41;

  /// The leases this ledger knows, by id.
  final Map<String, Lease> leases = {
    aliLease.id: aliLease,
    endedLease.id: endedLease,
  };

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
    if (!read && writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
  }

  Lease _lease(String id) => leases[id] ?? (throw const NotFoundFailure());

  List<Charge> _charges(String leaseId) => chargesOf[leaseId] ??= [];
  List<Payment> _payments(String leaseId) => paymentsOf[leaseId] ??= [];

  Charge _charge(String id) => chargesOf.values
      .expand((list) => list)
      .firstWhere((c) => c.id == id, orElse: () => throw const Forbidden());

  void _replaceCharge(Charge charge) {
    final list = _charges(charge.leaseId);
    list[list.indexWhere((c) => c.id == charge.id)] = charge;
  }

  Charge _with(
    Charge c, {
    Money? amount,
    Money? paid,
    Money? waived,
    CalendarDate? due,
    String? description,
    bool clearDescription = false,
    String? waiveReason,
    DateTime? voidedAt,
    String? voidReason,
  }) => Charge(
    id: c.id,
    leaseId: c.leaseId,
    kind: c.kind,
    source: c.source,
    periodMonth: c.periodMonth,
    dueDate: due ?? c.dueDate,
    amount: amount ?? c.amount,
    paidAmount: paid ?? c.paidAmount,
    waivedAmount: waived ?? c.waivedAmount,
    description: clearDescription ? null : description ?? c.description,
    waiveReason: waiveReason ?? c.waiveReason,
    voidedAt: voidedAt ?? c.voidedAt,
    voidReason: voidReason ?? c.voidReason,
    createdAt: c.createdAt,
  );

  LeaseBalance balanceOf(String leaseId, CalendarDate today) {
    final open = [
      for (final c in _charges(leaseId))
        if (c.open) c,
    ];
    final overdue = [
      for (final c in open)
        if (c.dueDate.isBefore(today)) c,
    ];
    final oldest = overdue.isEmpty
        ? null
        : overdue.map((c) => c.dueDate).reduce(CalendarDate.min);
    final paid = [
      for (final p in _payments(leaseId))
        if (!p.voided && p.method != PaymentMethod.depositAdjustment) p.paidOn,
    ];
    return LeaseBalance(
      outstanding: Money.sum(open.map((c) => c.outstanding)),
      overdue: Money.sum(overdue.map((c) => c.outstanding)),
      credit: Money.sum(_payments(leaseId).map((p) => p.unallocated)),
      oldestOverdueDueDate: oldest,
      daysOverdue: oldest == null ? null : today.differenceInDays(oldest),
      lastPaidOn: paid.isEmpty ? null : paid.reduce(CalendarDate.max),
    );
  }

  DepositPosition _deposit(String leaseId) {
    final lease = _lease(leaseId);
    final received = Money.sum([
      for (final c in _charges(leaseId))
        if (c.kind == ChargeKind.securityDeposit && !c.voided) c.paidAmount,
    ]);
    final applied = Money.sum([
      for (final p in _payments(leaseId))
        if (p.method == PaymentMethod.depositAdjustment && !p.voided) p.amount,
    ]);
    final refunded = Money.sum([
      for (final r in refunds[leaseId] ?? const <DepositRefund>[])
        if (!r.voided) r.amount,
    ]);
    return DepositPosition(
      agreed: lease.terms.securityDeposit,
      received: received,
      applied: applied,
      refunded: refunded,
      held: received - applied - refunded,
    );
  }

  static final _today = CalendarDate(2026, 11, 7);

  Paged<T> _page<T>(
    List<T> newestFirst,
    PageCursor? before,
    PageCursor Function(T) cursor,
  ) {
    var start = 0;
    if (before != null) {
      start = newestFirst.indexWhere((x) => cursor(x) == before) + 1;
    }
    final items = newestFirst.skip(start).take(pageLimit).toList();
    return Paged(
      items,
      next: start + items.length < newestFirst.length
          ? cursor(items.last)
          : null,
    );
  }

  List<Charge> _newestCharges(String leaseId) =>
      [..._charges(leaseId)]..sort((a, b) {
        final at = b.createdAt.compareTo(a.createdAt);
        return at != 0 ? at : b.id.compareTo(a.id);
      });

  List<Payment> _newestPayments(String leaseId) =>
      [..._payments(leaseId)]..sort((a, b) {
        final at = b.createdAt.compareTo(a.createdAt);
        return at != 0 ? at : b.id.compareTo(a.id);
      });

  @override
  Future<TenancyLedger> ledger(String leaseId) async {
    await _call('ledger', [leaseId], read: true);
    return TenancyLedger(
      lease: _lease(leaseId),
      balance: balanceOf(leaseId, _today),
      openCharges: [
        for (final c in _charges(leaseId))
          if (c.open) c,
      ]..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
      charges: _page(_newestCharges(leaseId), null, (c) => c.cursor),
      payments: _page(_newestPayments(leaseId), null, (p) => p.cursor),
      deposit: _deposit(leaseId),
      refunds: [...?refunds[leaseId]].reversed.toList(),
    );
  }

  @override
  Future<Paged<Charge>> charges(String leaseId, {PageCursor? before}) async {
    await _call('charges', [leaseId, before], read: true);
    return _page(_newestCharges(leaseId), before, (c) => c.cursor);
  }

  @override
  Future<Paged<Payment>> payments(String leaseId, {PageCursor? before}) async {
    await _call('payments', [leaseId, before], read: true);
    return _page(_newestPayments(leaseId), before, (p) => p.cursor);
  }

  /// Tenancies the who-owes-what list shows beside those this ledger
  /// holds.
  final extraReceivables = <Receivable>[
    Receivable(
      leaseId: techLeaseId,
      active: true,
      tenantId: techCorp.id,
      tenantName: 'Indus Tech (Pvt) Ltd',
      tenantPhone: PhoneNumber.fromE164('+924235000000'),
      unitId: 'unit-shop-1',
      unitLabel: 'Shop 1',
      propertyId: 'property-plaza',
      propertyName: 'Saddar Plaza',
      monthlyRent: const Money.fromRupees(150000),
      balance: LeaseBalance(
        outstanding: const Money.fromRupees(150000),
        lastPaidOn: CalendarDate(2026, 10, 3),
      ),
    ),
  ];

  @override
  Future<List<Receivable>> receivables(String portfolioId) async {
    await _call('receivables', [portfolioId], read: true);
    if (portfolioId != gulberg.id) return [];
    final list = [
      for (final lease in leases.values)
        Receivable(
          leaseId: lease.id,
          active: lease.active,
          tenantId: lease.tenantId,
          tenantName: lease.tenantName,
          tenantPhone: lease.id == aliLease.id ? aliRaza.phone : null,
          unitId: lease.unitId,
          unitLabel: lease.unitLabel,
          propertyId: lease.propertyId,
          propertyName: lease.propertyName,
          monthlyRent: lease.terms.monthlyRent,
          balance: balanceOf(lease.id, _today),
        ),
      ...extraReceivables,
    ];
    return list..sort((a, b) => b.balance.overdue.compareTo(a.balance.overdue));
  }

  int syncs = 0;

  @override
  Future<int> syncBilling(String portfolioId) async {
    await _call('syncBilling', [portfolioId]);
    syncs++;
    return 0;
  }

  Payment _allocate(Payment payment, List<String>? chosen) {
    final leaseId = payment.leaseId;
    final open = [
      for (final c in _charges(leaseId))
        if (c.open) c,
    ];
    final plan = planFifoAllocation(
      payment.unallocated,
      [
        for (final c in open)
          OpenCharge(
            id: c.id,
            dueDate: c.dueDate,
            outstanding: c.outstanding,
            isSecurityDeposit: c.kind == ChargeKind.securityDeposit,
          ),
      ],
      chosenChargeIds: chosen ?? const [],
      depositAdjustment: payment.method == PaymentMethod.depositAdjustment,
    );
    for (final slice in plan.allocations) {
      final c = _charge(slice.chargeId);
      _replaceCharge(_with(c, paid: c.paidAmount + slice.amount));
    }
    return Payment.fromRow(
      payment.toRow(),
      allocations: [
        ...payment.allocations,
        for (final a in plan.allocations)
          Allocation(chargeId: a.chargeId, amount: a.amount),
      ],
    )._withAllocated(payment.allocatedAmount + plan.allocated);
  }

  PaymentResult _result(Payment payment) {
    final lease = payment.leaseId;
    return PaymentResult(
      payment: payment,
      settled: [
        for (final a in payment.allocations)
          SettledCharge(
            chargeId: a.chargeId,
            amount: a.amount,
            kind: _charge(a.chargeId).kind,
            periodMonth: _charge(a.chargeId).periodMonth,
            dueDate: _charge(a.chargeId).dueDate,
          ),
      ],
      leaseOutstanding: balanceOf(lease, _today).outstanding,
      leaseCredit: balanceOf(lease, _today).credit,
    );
  }

  final _byKey = <String, Payment>{};

  @override
  Future<PaymentResult> recordPayment(PaymentDraft draft) async {
    await _call('recordPayment', [draft]);
    final existing = _byKey[draft.idempotencyKey];
    if (existing != null) return _result(existing);
    var payment = Payment(
      id: 'pay-${calls.length}',
      leaseId: draft.leaseId,
      amount: draft.amount,
      taxWithheld: draft.taxWithheld,
      paidOn: draft.paidOn,
      method: draft.method,
      reference: sanitizeOptional(draft.reference),
      taxCertificateNo: sanitizeOptional(draft.taxCertificateNo),
      notes: sanitizeOptional(draft.notes),
      receiptNumber: 'MM-2026-${(++_receipt).toString().padLeft(5, '0')}',
      createdAt:
          '2026-11-07T10:00:${calls.length.toString().padLeft(2, '0')}+00:00',
    );
    payment = _allocate(payment, draft.chargeIds);
    _payments(draft.leaseId).add(payment);
    _byKey[draft.idempotencyKey] = payment;
    return _result(payment);
  }

  @override
  Future<PaymentDetail> payment(String paymentId) async {
    await _call('payment', [paymentId], read: true);
    final payment = paymentsOf.values
        .expand((list) => list)
        .firstWhere(
          (p) => p.id == paymentId,
          orElse: () => throw const NotFoundFailure(),
        );
    return PaymentDetail(
      payment: payment,
      lease: _lease(payment.leaseId),
      settled: [
        for (final a in payment.allocations)
          SettledCharge(
            chargeId: a.chargeId,
            amount: a.amount,
            kind: _charge(a.chargeId).kind,
            periodMonth: _charge(a.chargeId).periodMonth,
            dueDate: _charge(a.chargeId).dueDate,
            description: _charge(a.chargeId).description,
          ),
      ],
    );
  }

  @override
  Future<void> voidPayment(String paymentId, String reason) async {
    await _call('voidPayment', [paymentId, reason]);
    for (final list in paymentsOf.values) {
      final index = list.indexWhere((p) => p.id == paymentId);
      if (index < 0) continue;
      final payment = list[index];
      for (final a in payment.allocations) {
        final c = _charge(a.chargeId);
        _replaceCharge(_with(c, paid: c.paidAmount - a.amount));
      }
      list[index] = Payment.fromRow({
        ...payment.toRow(),
        'voided_at': '2026-11-07T10:00:00+00:00',
        'void_reason': reason,
        'allocated_amount': 0,
        'allocations': const <Object?>[],
      });
    }
  }

  @override
  Future<Charge> addCharge({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ChargeDraft draft,
  }) async {
    await _call('addCharge', [id, portfolioId, leaseId, draft]);
    final charge = Charge(
      id: id,
      leaseId: leaseId,
      kind: draft.kind,
      source: ChargeSource.manual,
      periodMonth: draft.periodMonth,
      dueDate: draft.dueDate,
      amount: draft.amount,
      description: sanitizeOptional(draft.description),
      createdAt: '2026-11-07T10:00:00+00:00',
    );
    _charges(leaseId).add(charge);
    return charge;
  }

  @override
  Future<Charge> updateCharge(
    String chargeId, {
    Money? amount,
    CalendarDate? dueDate,
    String? description,
  }) async {
    await _call('updateCharge', [chargeId, amount, dueDate, description]);
    final c = _charge(chargeId);
    if (c.voided) throw const RejectedFailure('charge_voided');
    if (amount != null && !c.amountEditable) {
      throw const RejectedFailure('charge_not_editable');
    }
    final saved = _with(
      c,
      amount: amount,
      due: dueDate,
      description: description,
      clearDescription: description != null && description.isEmpty,
    );
    _replaceCharge(saved);
    return saved;
  }

  @override
  Future<Charge> waiveCharge(
    String chargeId, {
    required String reason,
    Money? amount,
  }) async {
    await _call('waiveCharge', [chargeId, reason, amount]);
    final c = _charge(chargeId);
    final waived = _with(
      c,
      waived: c.waivedAmount + (amount ?? c.outstanding),
      waiveReason: reason,
    );
    _replaceCharge(waived);
    return waived;
  }

  @override
  Future<Charge> voidCharge(String chargeId, String reason) async {
    await _call('voidCharge', [chargeId, reason]);
    final c = _charge(chargeId);
    if (c.paidAmount.isPositive) {
      throw const RejectedFailure('charge_has_payments');
    }
    final voided = _with(
      c,
      voidedAt: DateTime.utc(2026, 11, 7, 10),
      voidReason: reason,
    );
    _replaceCharge(voided);
    return voided;
  }

  @override
  Future<PaymentResult> applyDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate appliedOn,
    required String idempotencyKey,
    String? notes,
  }) async {
    await _call('applyDeposit', [leaseId, amount, appliedOn, idempotencyKey]);
    final existing = _byKey[idempotencyKey];
    if (existing != null) return _result(existing);
    final payment = _allocate(
      Payment(
        id: 'pay-deposit-${calls.length}',
        leaseId: leaseId,
        amount: amount,
        paidOn: appliedOn,
        method: PaymentMethod.depositAdjustment,
        notes: notes,
        receiptNumber: 'MM-2026-${(++_receipt).toString().padLeft(5, '0')}',
        createdAt: '2026-11-07T10:00:00+00:00',
      ),
      null,
    );
    _payments(leaseId).add(payment);
    _byKey[idempotencyKey] = payment;
    return _result(payment);
  }

  @override
  Future<DepositRefund> refundDeposit({
    required String leaseId,
    required Money amount,
    required CalendarDate refundedOn,
    required PaymentMethod method,
    String? reference,
    String? notes,
  }) async {
    await _call('refundDeposit', [leaseId, amount, refundedOn, method]);
    final refund = DepositRefund(
      id: 'refund-${calls.length}',
      leaseId: leaseId,
      amount: amount,
      refundedOn: refundedOn,
      method: method,
      reference: sanitizeOptional(reference),
      notes: sanitizeOptional(notes),
      createdAt: '2026-11-07T10:00:00+00:00',
    );
    (refunds[leaseId] ??= []).add(refund);
    _answer('refundDeposit');
    return refund;
  }

  @override
  Future<DepositRefund> voidDepositRefund(
    String refundId,
    String reason,
  ) async {
    await _call('voidDepositRefund', [refundId, reason]);
    for (final list in refunds.values) {
      final index = list.indexWhere((r) => r.id == refundId);
      if (index < 0) continue;
      return list[index] = DepositRefund.fromRow({
        ...list[index].toRow(),
        'voided_at': '2026-11-07T10:00:00+00:00',
        'void_reason': reason,
      });
    }
    throw const Forbidden();
  }

  @override
  Future<LedgerStatement> statement(String leaseId) async {
    await _call('statement', [leaseId], read: true);
    return LedgerStatement(
      lease: _lease(leaseId),
      charges: [..._charges(leaseId)]
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
      payments: [..._payments(leaseId)]
        ..sort((a, b) => a.paidOn.compareTo(b.paidOn)),
      deposit: _deposit(leaseId),
      refunds: [...?refunds[leaseId]],
    );
  }
}

extension on Payment {
  Payment _withAllocated(Money allocated) =>
      Payment.fromRow({...toRow(), 'allocated_amount': allocated.toJson()});
}

/// Members of [gulberg] with cash: the owner, and a caretaker who collected
/// rent and handed some on.
const caretakerId = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91';

/// A [HandoverRepository] over in-memory handovers and positions.
final class FakeHandoverRepository implements HandoverRepository {
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;
  final writeFailures = <AppFailure>[];

  List<CashPosition> positions = [
    const CashPosition(
      userId: caretakerId,
      fullName: 'Bilal Ahmed',
      role: MemberRole.manager,
      collected: Money.fromRupees(255000),
      handedOver: Money.fromRupees(170000),
      spent: Money.fromRupees(4500),
      inHand: Money.fromRupees(80500),
    ),
    const CashPosition(
      userId: testUserId,
      fullName: 'Ayesha Khan',
      role: MemberRole.owner,
      collected: Money.fromRupees(85000),
      handedOver: Money.zero,
      spent: Money.zero,
      inHand: Money.fromRupees(85000),
    ),
  ];

  final handoverList = <CashHandover>[
    CashHandover(
      id: 'ho-2',
      fromUserId: caretakerId,
      toUserId: testUserId,
      amount: const Money.fromRupees(85000),
      handedOverOn: CalendarDate(2026, 11, 6),
      method: PaymentMethod.cash,
      createdAt: '2026-11-06T09:00:00+00:00',
    ),
    CashHandover(
      id: 'ho-1',
      fromUserId: caretakerId,
      toUserId: testUserId,
      amount: const Money.fromRupees(85000),
      handedOverOn: CalendarDate(2026, 10, 7),
      method: PaymentMethod.raast,
      reference: 'RAAST 55102',
      confirmedAt: DateTime.utc(2026, 10, 7, 12),
      createdAt: '2026-10-07T09:00:00+00:00',
    ),
    CashHandover(
      id: 'ho-0',
      fromUserId: caretakerId,
      toUserId: testUserId,
      amount: const Money.fromRupees(5000),
      handedOverOn: CalendarDate(2026, 9, 7),
      method: PaymentMethod.cash,
      voidedAt: DateTime.utc(2026, 9, 8, 6),
      voidReason: 'Was an expense',
      createdAt: '2026-09-07T09:00:00+00:00',
    ),
  ];
  int pageLimit = pageSize;

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
    if (!read && writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
  }

  Paged<CashHandover> _page(PageCursor? before) {
    var start = 0;
    if (before != null) {
      start = handoverList.indexWhere((h) => h.cursor == before) + 1;
    }
    final items = handoverList.skip(start).take(pageLimit).toList();
    return Paged(
      items,
      next: start + items.length < handoverList.length
          ? items.last.cursor
          : null,
    );
  }

  @override
  Future<CashBook> cashBook(String portfolioId) async {
    await _call('cashBook', [portfolioId], read: true);
    return CashBook(positions: positions, handovers: _page(null));
  }

  @override
  Future<Paged<CashHandover>> handovers(
    String portfolioId, {
    PageCursor? before,
  }) async {
    await _call('handovers', [portfolioId, before], read: true);
    return _page(before);
  }

  @override
  Future<CashHandover> record({
    required String id,
    required String portfolioId,
    required HandoverDraft draft,
  }) async {
    await _call('record', [id, portfolioId, draft]);
    final handover = CashHandover.fromRow({
      ...draft.toWrite(),
      'id': id,
      'confirmed_at': null,
      'voided_at': null,
      'void_reason': null,
      'created_at': '2026-11-07T10:00:00+00:00',
    });
    handoverList.insert(0, handover);
    return handover;
  }

  CashHandover _update(String id, Map<String, Object?> fields) {
    final index = handoverList.indexWhere((h) => h.id == id);
    return handoverList[index] = CashHandover.fromRow({
      ...handoverList[index].toRow(),
      ...fields,
    });
  }

  @override
  Future<CashHandover> confirm(String handoverId) async {
    await _call('confirm', [handoverId]);
    return _update(handoverId, {'confirmed_at': '2026-11-07T10:00:00+00:00'});
  }

  @override
  Future<CashHandover> voidHandover(String handoverId, String reason) async {
    await _call('voidHandover', [handoverId, reason]);
    return _update(handoverId, {
      'voided_at': '2026-11-07T10:00:00+00:00',
      'void_reason': reason,
    });
  }
}

/// A [ReminderRepository] over an in-memory log.
final class FakeReminderRepository implements ReminderRepository {
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;
  final writeFailures = <AppFailure>[];
  final logs = <ReminderLog>[
    ReminderLog(
      id: 'rem-1',
      leaseId: aliLease.id,
      channel: ReminderChannel.whatsapp,
      template: ReminderTemplate.overdue,
      language: ReminderLanguage.urdu,
      messagePreview: 'السلام علیکم',
      sentAt: DateTime.utc(2026, 10, 15, 6),
    ),
  ];

  @override
  Future<List<ReminderLog>> recent(String leaseId) async {
    calls.add(('recent', [leaseId]));
    await gate.pass();
    final failure = readFailure;
    if (failure != null) throw failure;
    return [
      for (final log in logs.reversed)
        if (log.leaseId == leaseId) log,
    ].take(ReminderRepository.recentLimit).toList();
  }

  @override
  Future<ReminderLog> log({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ReminderTemplate template,
    required ReminderLanguage language,
    required String message,
    ReminderChannel channel = ReminderChannel.whatsapp,
  }) async {
    calls.add(('log', [id, portfolioId, leaseId, template, language, message]));
    await gate.pass();
    if (writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
    final log = ReminderLog(
      id: id,
      leaseId: leaseId,
      channel: channel,
      template: template,
      language: language,
      messagePreview: reminderPreview(message),
      sentAt: DateTime.utc(2026, 11, 7, 10),
    );
    logs.add(log);
    return log;
  }
}

/// A [NotificationRepository] over an in-memory inbox: one of each kind.
final class FakeNotificationRepository implements NotificationRepository {
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;
  final writeFailures = <AppFailure>[];
  int pageLimit = pageSize;

  final inbox = <AppNotification>[
    AppNotification(
      id: 'n-1',
      kind: NotificationKind.rentOverdue,
      params: {
        'lease_id': aliLease.id,
        'tenant_name': 'Ali Raza',
        'unit_label': 'Ground floor',
        'property_name': 'Gulberg House',
        'amount': 25000,
        'due_date': '2026-10-05',
        'days_overdue': 33,
      },
      entityType: 'charge',
      entityId: 'ch-rent-10',
      createdAt: '2026-11-07T01:00:00+00:00',
    ),
    AppNotification(
      id: 'n-2',
      kind: NotificationKind.policePending,
      params: {
        'lease_id': aliLease.id,
        'tenant_name': 'Ali Raza',
        'unit_label': 'Ground floor',
        'deadline': '2026-01-30',
        'statutory': true,
      },
      createdAt: '2026-11-06T01:00:00+00:00',
    ),
    AppNotification(
      id: 'n-3',
      kind: NotificationKind.cnicExpiring,
      params: {
        'tenant_id': aliRaza.id,
        'tenant_name': 'Ali Raza',
        'cnic_expiry': '2026-12-01',
      },
      readAt: DateTime.utc(2026, 11, 5, 8),
      createdAt: '2026-11-05T01:00:00+00:00',
    ),
    AppNotification(
      id: 'n-4',
      kind: NotificationKind.invitationAccepted,
      params: const {'email': 'bilal.ahmed@example.com', 'role': 'manager'},
      readAt: DateTime.utc(2026, 11, 2, 8),
      createdAt: '2026-11-02T01:00:00+00:00',
    ),
  ];

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
    if (!read && writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
  }

  @override
  Future<Paged<AppNotification>> notifications(
    String portfolioId, {
    PageCursor? before,
  }) async {
    await _call('notifications', [portfolioId, before], read: true);
    if (portfolioId != gulberg.id) return const Paged([]);
    var start = 0;
    if (before != null) start = inbox.indexWhere((n) => n.cursor == before) + 1;
    final items = inbox.skip(start).take(pageLimit).toList();
    return Paged(
      items,
      next: start + items.length < inbox.length ? items.last.cursor : null,
    );
  }

  @override
  Future<int> unreadCount(String portfolioId) async {
    await _call('unreadCount', [portfolioId], read: true);
    return portfolioId == gulberg.id ? inbox.where((n) => n.unread).length : 0;
  }

  void _read(bool Function(AppNotification) which) {
    for (final (index, n) in inbox.indexed) {
      if (which(n) && n.unread) {
        inbox[index] = n.read(DateTime.utc(2026, 11, 7, 10));
      }
    }
  }

  @override
  Future<void> markRead(List<String> ids) async {
    await _call('markRead', [ids]);
    _read((n) => ids.contains(n.id));
  }

  @override
  Future<void> markAllRead(String portfolioId) async {
    await _call('markAllRead', [portfolioId]);
    _read((_) => true);
  }

  @override
  Future<void> delete(String notificationId) async {
    await _call('delete', [notificationId]);
    inbox.removeWhere((n) => n.id == notificationId);
  }
}

/// A sharer that keeps what it was given.
final class FakeSharer {
  final shared = <SharedDocument>[];
  AppFailure? failure;

  Future<void> share(SharedDocument document) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    shared.add(document);
  }
}

/// A document maker's stand-in: the bytes of a tiny PDF.
final Uint8List fakePdf = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);
