import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/money_fakes.dart';
import '../../../../support/supabase.dart';

/// A `charges` row as PostgREST returns it: amounts as JSON numbers.
final Map<String, Object?> _chargeRow = {
  'id': 'ch-rent-10',
  'lease_id': aliLease.id,
  'kind': 'rent',
  'source': 'auto_rent',
  'period_month': '2026-10-01',
  'due_date': '2026-10-05',
  'amount': 85000,
  'paid_amount': 60000.0,
  'waived_amount': 0,
  'outstanding': 25000,
  'description': null,
  'related_charge_id': null,
  'waive_reason': null,
  'voided_at': null,
  'void_reason': null,
  'created_at': '2026-10-01T00:05:00+00:00',
};

final Map<String, Object?> _paymentRow = {
  'id': 'pay-oct',
  'lease_id': aliLease.id,
  'amount': 60000,
  'tax_withheld': 0,
  'allocated_amount': 60000,
  'paid_on': '2026-10-06',
  'method': 'bank_transfer',
  'reference': 'IBFT 778812',
  'tax_certificate_no': null,
  'notes': null,
  'receipt_number': 'MM-2026-00041',
  'voided_at': null,
  'void_reason': null,
  'created_at': '2026-10-06T07:00:00+00:00',
  'allocations': [
    {'charge_id': 'ch-rent-10', 'amount': 60000},
  ],
};

/// `record_payment`'s answer: the whole payment row, the dues it settled,
/// and the tenancy's balance after it.
final Map<String, Object?> _paymentResult = {
  'payment': {
    ...(Map.of(_paymentRow)..remove('allocations')),
    'portfolio_id': gulberg.id,
    'applied_amount': 60000,
    'unallocated_amount': 0,
    'received_by': testUserId,
    'idempotency_key': 'key-1',
    'voided_by': null,
    'updated_at': '2026-10-06T07:00:00+00:00',
  },
  'allocations': [
    {
      'charge_id': 'ch-rent-10',
      'amount': 60000,
      'kind': 'rent',
      'period_month': '2026-10-01',
      'due_date': '2026-10-05',
    },
  ],
  'lease_outstanding': 117450,
  'lease_credit': 0,
};

final Map<String, Object?> _balanceRow = {
  'outstanding': 122450,
  'overdue': 115000,
  'credit': 0,
  'oldest_overdue_due_date': '2026-10-05',
  'days_overdue': 33,
  'last_paid_on': '2026-10-06',
  'last_reminded_at': '2026-10-15T06:00:00+00:00',
};

final Map<String, Object?> _refundRow = {
  'id': 'refund-1',
  'lease_id': endedLease.id,
  'amount': 50000,
  'refunded_on': '2026-09-01',
  'method': 'cash',
  'reference': null,
  'notes': 'Half now',
  'voided_at': null,
  'void_reason': null,
  'created_at': '2026-09-01T07:00:00+00:00',
};

const Map<String, Object?> _deposit = {
  'agreed': 170000,
  'received': 170000,
  'applied': 0,
  'refunded': 0,
  'held': 170000,
};

final Map<String, Object?> _receivableRow = {
  'lease_id': aliLease.id,
  'lease_status': 'active',
  'tenant_id': aliRaza.id,
  'tenant_name': 'Ali Raza',
  'tenant_phone': '+923001112233',
  'unit_id': groundFloor.id,
  'unit_label': 'Ground floor',
  'property_id': gulbergHouse.id,
  'property_name': 'Gulberg House',
  'monthly_rent': 85000,
  ..._balanceRow,
};

void main() {
  late MockSupabase supabase;
  late SupabaseLedgerRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async {
      final path = request.url.path;
      final single =
          request.headers['accept'] == 'application/vnd.pgrst.object+json';
      if (path.endsWith('/leases')) {
        return jsonResponse(single ? aliLease.toRow() : [aliLease.toRow()]);
      }
      if (path.endsWith('/lease_balances')) {
        return jsonResponse(single ? _balanceRow : [_balanceRow]);
      }
      if (path.endsWith('/charges')) {
        return jsonResponse(single ? _chargeRow : [_chargeRow]);
      }
      if (path.endsWith('/payments')) {
        return jsonResponse(single ? _paymentRow : [_paymentRow]);
      }
      if (path.endsWith('/deposit_refunds')) return jsonResponse([_refundRow]);
      if (path.endsWith('/get_deposit_position')) {
        return jsonResponse(_deposit);
      }
      if (path.endsWith('/get_receivables')) {
        return jsonResponse([_receivableRow]);
      }
      if (path.endsWith('/record_payment') || path.endsWith('/apply_deposit')) {
        return jsonResponse(_paymentResult);
      }
      if (path.endsWith('/sync_portfolio_billing')) return jsonResponse(2);
      if (path.endsWith('/refund_deposit') ||
          path.endsWith('/void_deposit_refund')) {
        return jsonResponse(_refundRow);
      }
      if (path.endsWith('/update_charge') ||
          path.endsWith('/waive_charge') ||
          path.endsWith('/void_charge')) {
        return jsonResponse(_chargeRow);
      }
      return jsonResponse(null);
    });
    repository = SupabaseLedgerRepository(supabase.client);
  });

  group('models', () {
    test('a charge reads its amounts and stands where its date says', () {
      final charge = Charge.fromRow(_chargeRow);
      expect(charge, aliCharges()[2]);
      expect(charge.hashCode, aliCharges()[2].hashCode);
      expect(Charge.fromRow(charge.toRow()), charge);
      expect(charge.outstanding, const Money.fromRupees(25000));
      expect(charge.open, isTrue);
      expect(charge.amountEditable, isFalse);
      expect(charge.periodMonth, MonthPeriod(2026, 10));
      final today = CalendarDate(2026, 11, 7);
      expect(charge.stateOn(today), ChargeState.overdue);
      expect(charge.stateOn(CalendarDate(2026, 10, 2)), ChargeState.dueSoon);
      expect(charge.stateOn(CalendarDate(2026, 10, 1)), ChargeState.notDue);
      final charges = {for (final c in aliCharges()) c.id: c};
      expect(charges['ch-rent-9']!.stateOn(today), ChargeState.paid);
      expect(charges['ch-plumber']!.stateOn(today), ChargeState.waived);
      expect(charges['ch-other']!.stateOn(today), ChargeState.voided);
      expect(charges['ch-electricity']!.stateOn(today), ChargeState.dueSoon);
      expect(charges['ch-plumber']!.amountEditable, isTrue);
    });

    test('malformed rows are refused', () {
      for (final row in <Object?>[
        null,
        {..._chargeRow}..remove('due_date'),
        {..._chargeRow, 'kind': 'rates'},
        {..._chargeRow, 'source': 'magic'},
        // The database's own sum must agree.
        {..._chargeRow, 'outstanding': 1},
      ]) {
        expect(
          () => Charge.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
      expect(
        () => Payment.fromRow({..._paymentRow, 'method': 'gold'}),
        throwsFormatException,
      );
      expect(
        () => DepositPosition.fromJson({..._deposit}..remove('held')),
        throwsFormatException,
      );
      expect(
        () => Receivable.fromRow({..._receivableRow, 'lease_status': 'x'}),
        throwsFormatException,
      );
    });

    test('a payment reads its allocations, credit and tax', () {
      final payment = Payment.fromRow(_paymentRow);
      expect(payment, aliPayments()[3]);
      expect(payment.hashCode, aliPayments()[3].hashCode);
      expect(Payment.fromRow(payment.toRow()), payment);
      expect(payment.applied, const Money.fromRupees(60000));
      expect(payment.unallocated, Money.zero);
      expect(payment.voided, isFalse);
      final taxed = Payment.fromRow({
        ..._paymentRow,
        'tax_withheld': 7500,
        'allocated_amount': 60000,
      });
      expect(taxed.applied, const Money.fromRupees(67500));
      expect(taxed.unallocated, const Money.fromRupees(7500));
      expect(aliPayments()[2].unallocated, Money.zero);
    });

    test('a recorded payment answers what it settled and what is owed', () {
      final result = PaymentResult.fromJson(_paymentResult);
      expect(result.payment.receiptNumber, 'MM-2026-00041');
      expect(result.payment.allocations.single.chargeId, 'ch-rent-10');
      expect(result.settled.single.kind, ChargeKind.rent);
      expect(result.settled.single.periodMonth, MonthPeriod(2026, 10));
      expect(result.leaseOutstanding, const Money.fromRupees(117450));
      expect(result.leaseCredit, Money.zero);
    });

    test('every database value has a case', () {
      for (final kind in ChargeKind.values) {
        expect(ChargeKind.parse(kind.db), kind);
      }
      for (final source in ChargeSource.values) {
        expect(ChargeSource.parse(source.db), source);
      }
      for (final method in PaymentMethod.values) {
        expect(PaymentMethod.parse(method.db), method);
      }
      expect(ChargeKind.manual, isNot(contains(ChargeKind.rent)));
      expect(
        PaymentMethod.received,
        isNot(contains(PaymentMethod.depositAdjustment)),
      );
    });

    test('a draft sends record_payment its arguments, tidied', () {
      final draft = PaymentDraft(
        leaseId: aliLease.id,
        amount: const Money.fromRupees(60000),
        paidOn: CalendarDate(2026, 11, 6),
        method: PaymentMethod.cheque,
        idempotencyKey: 'key-1',
        taxWithheld: const Money.fromRupees(4500),
        taxCertificateNo: '  CPR-11\u202E2 ',
        reference: ' ',
        notes: 'Line one\n\nLine two',
        chargeIds: const ['ch-rent-11'],
      );
      expect(draft.toParams(), {
        'p_lease_id': aliLease.id,
        'p_amount': '60000.00',
        'p_paid_on': '2026-11-06',
        'p_method': 'cheque',
        'p_idempotency_key': 'key-1',
        'p_reference': null,
        'p_notes': 'Line one\n\nLine two',
        'p_tax_withheld': '4500.00',
        'p_tax_certificate_no': 'CPR-112',
        'p_charge_ids': ['ch-rent-11'],
      });
      expect(
        draft,
        PaymentDraft(
          leaseId: aliLease.id,
          amount: const Money.fromRupees(60000),
          paidOn: CalendarDate(2026, 11, 6),
          method: PaymentMethod.cheque,
          idempotencyKey: 'key-1',
          taxWithheld: const Money.fromRupees(4500),
          taxCertificateNo: '  CPR-11\u202E2 ',
          reference: ' ',
          notes: 'Line one\n\nLine two',
          chargeIds: const ['ch-rent-11'],
        ),
      );
      expect(draft.hashCode, isA<int>());
      final draftCharge = ChargeDraft(
        kind: ChargeKind.water,
        amount: const Money.fromRupees(900),
        dueDate: CalendarDate(2026, 11, 20),
        periodMonth: MonthPeriod(2026, 10),
        description: ' WASA ',
      );
      expect(draftCharge.toWrite(), {
        'kind': 'water',
        'amount': '900.00',
        'due_date': '2026-11-20',
        'period_month': '2026-10-01',
        'description': 'WASA',
      });
      expect(
        draftCharge,
        ChargeDraft(
          kind: ChargeKind.water,
          amount: const Money.fromRupees(900),
          dueDate: CalendarDate(2026, 11, 20),
          periodMonth: MonthPeriod(2026, 10),
          description: 'WASA',
        ),
      );
      expect(draftCharge.hashCode, isA<int>());
    });

    test('a ledger, a payment detail and the list survive the cache', () {
      final ledger = TenancyLedger(
        lease: aliLease,
        balance: LeaseBalance.fromRow(_balanceRow),
        openCharges: [Charge.fromRow(_chargeRow)],
        charges: Paged([Charge.fromRow(_chargeRow)]),
        payments: Paged([Payment.fromRow(_paymentRow)]),
        deposit: DepositPosition.fromJson(_deposit),
        refunds: [DepositRefund.fromRow(_refundRow)],
      );
      expect(TenancyLedger.fromJson(ledger.toJson()), ledger);
      expect(TenancyLedger.fromJson(ledger.toJson()).hashCode, ledger.hashCode);
      expect(ledger.copyWith(), ledger);
      final receivable = Receivable.fromRow(_receivableRow);
      expect(Receivable.fromRow(receivable.toRow()), receivable);
      expect(
        Receivable.fromRow(receivable.toRow()).hashCode,
        receivable.hashCode,
      );
      expect(receivable.balance.daysOverdue, 33);
      expect(receivable.tenantPhone, aliRaza.phone);
      // A number the app cannot dial costs its row the number, not the
      // whole list of who owes what.
      expect(
        Receivable.fromRow({..._receivableRow, 'tenant_phone': '+92300123456'})
            .tenantPhone,
        isNull,
      );
      final refund = DepositRefund.fromRow(_refundRow);
      expect(refund.hashCode, DepositRefund.fromRow(_refundRow).hashCode);
      expect(refund.voided, isFalse);
      expect(
        DepositPosition.fromJson(_deposit).hashCode,
        DepositPosition.fromJson(_deposit).hashCode,
      );
      expect(
        LeaseBalance.fromRow(_balanceRow).hashCode,
        LeaseBalance.fromRow(_balanceRow).hashCode,
      );
      expect(
        const Allocation(chargeId: 'a', amount: Money.zero).hashCode,
        const Allocation(chargeId: 'a', amount: Money.zero).hashCode,
      );
    });

    test('a statement adds up what is owed and held', () {
      final statement = LedgerStatement(
        lease: aliLease,
        charges: aliCharges(),
        payments: aliPayments(),
        deposit: DepositPosition.none,
        refunds: const [],
      );
      expect(statement.outstanding, const Money.fromRupees(122450));
      expect(statement.credit, Money.zero);
    });
  });

  group('requests', () {
    test('a ledger reads its parts at once', () async {
      final ledger = await repository.ledger(aliLease.id);
      expect(ledger.lease, aliLease);
      expect(ledger.balance.overdue, const Money.fromRupees(115000));
      expect(ledger.openCharges.single.id, 'ch-rent-10');
      expect(ledger.payments.items.single.receiptNumber, 'MM-2026-00041');
      expect(ledger.deposit.held, const Money.fromRupees(170000));
      expect(ledger.refunds.single.notes, 'Half now');
      final byPath = {
        for (final r in supabase.requests)
          [
            r.url.pathSegments.last,
            if (r.url.queryParameters.containsKey('limit')) 'page',
          ].join('+'): r,
      };
      expect(byPath['charges']!.url.queryParameters, {
        'select': Charge.columns,
        'lease_id': 'eq.${aliLease.id}',
        'voided_at': 'is.null',
        'outstanding': 'gt.0',
        'order': 'due_date.asc.nullslast,id.asc.nullslast',
      });
      expect(byPath['charges+page']!.url.queryParameters, {
        'select': Charge.columns,
        'lease_id': 'eq.${aliLease.id}',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      expect(byPath['payments+page']!.url.queryParameters, {
        'select': Payment.columns,
        'lease_id': 'eq.${aliLease.id}',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      expect(byPath['deposit_refunds']!.url.queryParameters, {
        'select': DepositRefund.columns,
        'lease_id': 'eq.${aliLease.id}',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
      });
      expect(byPath['leases']!.url.queryParameters, {
        'select': Lease.columns,
        'id': 'eq.${aliLease.id}',
      });
      expect(bodyOf(byPath['get_deposit_position']!), {
        'p_lease_id': aliLease.id,
      });
      expect(byPath['lease_balances']!.url.queryParameters, {
        'select': LeaseBalance.columns,
        'lease_id': 'eq.${aliLease.id}',
      });
    });

    test('a ledger without a balance row or deposit reads as none', () async {
      supabase.respond = (request) async {
        final path = request.url.path;
        if (path.endsWith('/leases')) return jsonResponse(aliLease.toRow());
        if (path.endsWith('/lease_balances')) return jsonResponse(null);
        if (path.endsWith('/get_deposit_position')) return jsonResponse(null);
        return jsonResponse(<Object?>[]);
      };
      final ledger = await repository.ledger(aliLease.id);
      expect(ledger.balance, const LeaseBalance());
      expect(ledger.deposit, DepositPosition.none);
    });

    test('pages read on from their cursor', () async {
      const cursor = PageCursor(
        createdAt: '2026-10-01T00:05:00+00:00',
        id: 'c',
      );
      await repository.charges(aliLease.id, before: cursor);
      expect(
        supabase.request.url.queryParameters['or'],
        '(created_at.lt."${cursor.createdAt}",'
        'and(created_at.eq."${cursor.createdAt}",id.lt."c"))',
      );
      await repository.payments(aliLease.id, before: cursor);
      expect(supabase.requests.last.url.path, endsWith('/payments'));
    });

    test('the list of what is owed and the billing sync', () async {
      final list = await repository.receivables(gulberg.id);
      expect(list.single.tenantName, 'Ali Raza');
      expect(bodyOf(supabase.request), {'p_portfolio_id': gulberg.id});
      expect(await repository.syncBilling(gulberg.id), 2);
      supabase.respond = (_) async => jsonResponse('two');
      await expectLater(
        repository.syncBilling(gulberg.id),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('recording a payment sends the draft and reads the answer', () async {
      final draft = PaymentDraft(
        leaseId: aliLease.id,
        amount: const Money.fromRupees(60000),
        paidOn: CalendarDate(2026, 10, 6),
        method: PaymentMethod.bankTransfer,
        idempotencyKey: 'key-1',
      );
      final result = await repository.recordPayment(draft);
      expect(result.payment.id, 'pay-oct');
      expect(supabase.request.url.path, endsWith('/rpc/record_payment'));
      // The literal parameters `record_payment` takes, not the draft's own
      // map: a misspelt key would pass a comparison with itself.
      expect(bodyOf(supabase.request), {
        'p_lease_id': aliLease.id,
        'p_amount': '60000.00',
        'p_paid_on': '2026-10-06',
        'p_method': 'bank_transfer',
        'p_idempotency_key': 'key-1',
        'p_reference': null,
        'p_notes': null,
        'p_tax_withheld': '0.00',
        'p_tax_certificate_no': null,
        'p_charge_ids': null,
      });
    });

    test('every refusal of a payment keeps its reason', () async {
      for (final reason in [
        'invalid_amount',
        'invalid_tax_withheld',
        'invalid_method',
        'invalid_date',
        'invalid_charge_selection',
        'idempotency_key_reused',
      ]) {
        supabase.respond = (_) async =>
            postgrestError('22023', message: reason);
        await expectLater(
          repository.recordPayment(
            PaymentDraft(
              leaseId: aliLease.id,
              amount: const Money.fromRupees(1),
              paidOn: CalendarDate(2026, 10, 6),
              method: PaymentMethod.cash,
              idempotencyKey: 'k',
            ),
          ),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
      supabase.respond = (_) async =>
          postgrestError('rate_limited', status: 429, hint: '20');
      await expectLater(
        repository.voidPayment('p', 'x'),
        throwsA(isA<RateLimited>()),
      );
    });

    test('a receipt reads the payment, its dues and its tenancy', () async {
      supabase.respond = (_) async => jsonResponse({
        ...(Map.of(_paymentRow)..remove('allocations')),
        'settled': [
          {
            'amount': 60000,
            'charge': {
              'id': 'ch-rent-10',
              'kind': 'rent',
              'period_month': '2026-10-01',
              'due_date': '2026-10-05',
              'description': null,
            },
          },
        ],
        'lease': aliLease.toRow(),
      });
      final detail = await repository.payment('pay-oct');
      expect(detail.lease, aliLease);
      expect(detail.settled.single.amount, const Money.fromRupees(60000));
      expect(detail.payment.allocations.single.chargeId, 'ch-rent-10');
      expect(PaymentDetail.fromRow(detail.toJson()), detail);
      expect(PaymentDetail.fromRow(detail.toJson()).hashCode, detail.hashCode);
      expect(supabase.request.url.queryParameters, {
        'select': PaymentDetail.columns,
        'id': 'eq.pay-oct',
      });
    });

    test(
      'voiding a payment and changing charges call their functions',
      () async {
        await repository.voidPayment('pay-oct', '  Bounced cheque ');
        expect(bodyOf(supabase.request), {
          'p_payment_id': 'pay-oct',
          'p_reason': 'Bounced cheque',
        });
        final updated = await repository.updateCharge(
          'ch-rent-10',
          dueDate: CalendarDate(2026, 10, 7),
          description: ' ',
        );
        expect(updated.id, 'ch-rent-10');
        expect(bodyOf(supabase.requests.last), {
          'p_charge_id': 'ch-rent-10',
          'p_amount': null,
          'p_due_date': '2026-10-07',
          'p_description': '',
        });
        await repository.updateCharge(
          'ch-plumber',
          amount: const Money.fromRupees(2500),
        );
        expect(bodyOf(supabase.requests.last), {
          'p_charge_id': 'ch-plumber',
          'p_amount': '2500.00',
          'p_due_date': null,
          'p_description': null,
        });
        await repository.waiveCharge('ch-fee-10', reason: 'Goodwill');
        expect(bodyOf(supabase.requests.last), {
          'p_charge_id': 'ch-fee-10',
          'p_reason': 'Goodwill',
          'p_amount': null,
        });
        await repository.voidCharge('ch-other', 'Wrong tenant');
        expect(supabase.requests.last.url.path, endsWith('/rpc/void_charge'));
      },
    );

    test('a charge added by hand; a retry reads it back', () async {
      final draft = ChargeDraft(
        kind: ChargeKind.water,
        amount: const Money.fromRupees(900),
        dueDate: CalendarDate(2026, 11, 20),
      );
      await repository.addCharge(
        id: 'ch-new',
        portfolioId: gulberg.id,
        leaseId: aliLease.id,
        draft: draft,
      );
      expect(bodyOf(supabase.request), {
        'id': 'ch-new',
        'portfolio_id': gulberg.id,
        'lease_id': aliLease.id,
        ...draft.toWrite(),
      });
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(_chargeRow);
      final charge = await repository.addCharge(
        id: 'ch-rent-10',
        portfolioId: gulberg.id,
        leaseId: aliLease.id,
        draft: draft,
      );
      expect(charge.id, 'ch-rent-10');
      supabase.respond = (_) async => postgrestError('42501', status: 403);
      await expectLater(
        repository.addCharge(
          id: 'x',
          portfolioId: gulberg.id,
          leaseId: aliLease.id,
          draft: draft,
        ),
        throwsA(isA<Forbidden>()),
      );
    });

    test('the deposit is applied, refunded and a refund voided', () async {
      final applied = await repository.applyDeposit(
        leaseId: aliLease.id,
        amount: const Money.fromRupees(30000),
        appliedOn: CalendarDate(2026, 11, 7),
        idempotencyKey: 'key-2',
        notes: ' Move-out ',
      );
      expect(applied.payment.id, 'pay-oct');
      expect(bodyOf(supabase.request), {
        'p_lease_id': aliLease.id,
        'p_amount': '30000.00',
        'p_applied_on': '2026-11-07',
        'p_idempotency_key': 'key-2',
        'p_notes': 'Move-out',
      });
      final refund = await repository.refundDeposit(
        leaseId: endedLease.id,
        amount: const Money.fromRupees(50000),
        refundedOn: CalendarDate(2026, 9, 1),
        method: PaymentMethod.cash,
        notes: 'Half now',
      );
      expect(refund.amount, const Money.fromRupees(50000));
      expect(bodyOf(supabase.requests.last), {
        'p_lease_id': endedLease.id,
        'p_amount': '50000.00',
        'p_refunded_on': '2026-09-01',
        'p_method': 'cash',
        'p_reference': null,
        'p_notes': 'Half now',
      });
      await repository.voidDepositRefund('refund-1', 'Typo');
      expect(bodyOf(supabase.requests.last), {
        'p_refund_id': 'refund-1',
        'p_reason': 'Typo',
      });
    });

    test('a statement reads every page, oldest first', () async {
      var page = 0;
      supabase.respond = (request) async {
        final path = request.url.path;
        final answer = switch (path.split('/').last) {
          'leases' => aliLease.toRow(),
          'lease_balances' => _balanceRow,
          'get_deposit_position' => _deposit,
          'deposit_refunds' => [_refundRow],
          'payments' => [_paymentRow],
          _ => null,
        };
        if (answer != null) return jsonResponse(answer);
        if (path.endsWith('/charges')) {
          if (!request.url.queryParameters.containsKey('limit')) {
            return jsonResponse(<Object?>[]);
          }
          // A full first page, then the last one.
          page++;
          return jsonResponse([
            for (var i = 0; i < (page == 1 ? 50 : 2); i++)
              {
                ..._chargeRow,
                'id': 'c-$page-$i',
                'due_date':
                    '2026-${(i % 12 + 1).toString().padLeft(2, '0')}-05',
              },
          ]);
        }
        return jsonResponse(null);
      };
      final statement = await repository.statement(aliLease.id);
      expect(statement.charges, hasLength(52));
      expect(
        statement.charges.first.dueDate.isOnOrBefore(
          statement.charges.last.dueDate,
        ),
        isTrue,
      );
      expect(statement.payments.single.id, 'pay-oct');
      expect(statement.refunds.single.id, 'refund-1');
    });

    test('a malformed answer is a server failure', () async {
      supabase.respond = (_) async => jsonResponse({'payment': null});
      await expectLater(
        repository.recordPayment(
          PaymentDraft(
            leaseId: aliLease.id,
            amount: const Money.fromRupees(1),
            paidOn: CalendarDate(2026, 10, 6),
            method: PaymentMethod.cash,
            idempotencyKey: 'k',
          ),
        ),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
