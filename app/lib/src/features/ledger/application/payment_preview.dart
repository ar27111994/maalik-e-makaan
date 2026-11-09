import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';

/// What recording a payment will do to a tenancy's dues, worked out the
/// way `record_payment` does it, to show before it is saved.
@immutable
final class PaymentPreview {
  const new({required this.plan, this.cancelledFees = const []});

  /// The dues the money settles (the chosen first, then the oldest), and
  /// what is kept as credit.
  final AllocationPlan plan;

  /// The automatic late fees the payment cancels: each on a rent it
  /// settles in full within the rent's grace period.
  final List<Charge> cancelledFees;
}

/// Previews recording [applied] (the cash and the tax withheld) received on
/// [paidOn] against [open], the tenancy's open dues, settling [chosen]
/// first, under a lease with [graceDays] days of grace.
///
/// It mirrors `record_payment`: the money is allocated
/// (`planFifoAllocation`, as `allocate_payment`), then every rent it
/// settles in full on or before its due date plus the grace days has its
/// automatic late fee voided, when no other money was paid on that fee,
/// and the money is allocated again without it. The database does this
/// once, so a rent the second allocation settles keeps its fee.
PaymentPreview previewPayment({
  required Money applied,
  required List<Charge> open,
  required CalendarDate paidOn,
  required int graceDays,
  List<String> chosen = const [],
}) {
  OpenCharge openOf(Charge c) => OpenCharge(
    id: c.id,
    dueDate: c.dueDate,
    outstanding: c.outstanding,
    isSecurityDeposit: c.kind == ChargeKind.securityDeposit,
  );
  final first = planFifoAllocation(
    applied,
    open.map(openOf),
    chosenChargeIds: chosen,
  );
  final byId = {for (final c in open) c.id: c};
  final settledRents = {
    for (final a in first.allocations)
      if (byId[a.chargeId] case final rent?
          when rent.kind == ChargeKind.rent &&
              a.amount == rent.outstanding &&
              !paidOn.isAfter(rent.dueDate.addDays(graceDays)))
        rent.id,
  };
  final cancelled = [
    for (final fee in open)
      if (fee.kind == ChargeKind.lateFee &&
          fee.source == ChargeSource.autoLateFee &&
          !fee.paidAmount.isPositive &&
          settledRents.contains(fee.relatedChargeId))
        fee,
  ];
  if (cancelled.isEmpty) return PaymentPreview(plan: first);
  final gone = {for (final fee in cancelled) fee.id};
  return PaymentPreview(
    plan: planFifoAllocation(
      applied,
      [
        for (final c in open)
          if (!gone.contains(c.id)) openOf(c),
      ],
      chosenChargeIds: [
        for (final id in chosen)
          if (!gone.contains(id)) id,
      ],
    ),
    cancelledFees: cancelled,
  );
}
