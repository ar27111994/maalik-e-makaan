import 'package:meta/meta.dart';
import 'package:mm_core/src/money/money.dart';
import 'package:mm_core/src/time/calendar_date.dart';

/// A charge that still has an outstanding balance.
@immutable
final class OpenCharge {
  /// Creates an open charge.
  new({
    required this.id,
    required this.dueDate,
    required this.outstanding,
    this.isSecurityDeposit = false,
  }) {
    if (!outstanding.isPositive) {
      throw ArgumentError.value(outstanding, 'outstanding', 'must be > 0');
    }
  }

  /// The charge's identifier (UUIDv7, so it also sorts by creation time).
  final String id;

  /// When the charge falls due.
  final CalendarDate dueDate;

  /// Amount still owed on the charge.
  final Money outstanding;

  /// Whether this is the lease's security deposit due, which a deposit
  /// adjustment (using the deposit to settle dues) never pays.
  final bool isSecurityDeposit;
}

/// One slice of a payment applied to a charge.
@immutable
final class ChargeAllocation {
  /// Creates an allocation of [amount] to the charge [chargeId].
  const new({required this.chargeId, required this.amount});

  /// The charge receiving the money.
  final String chargeId;

  /// How much of the payment is applied.
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is ChargeAllocation &&
      other.chargeId == chargeId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(chargeId, amount);

  @override
  String toString() => 'ChargeAllocation($chargeId, $amount)';
}

/// The result of applying a payment to open charges.
@immutable
final class AllocationPlan {
  /// Creates a plan.
  const new({required this.allocations, required this.unallocated});

  /// Slices of the payment applied to charges, oldest first.
  final List<ChargeAllocation> allocations;

  /// The part of the payment left over as tenant credit (advance).
  final Money unallocated;

  /// Total applied to charges.
  Money get allocated => Money.sum(allocations.map((a) => a.amount));

  /// Charges that this payment settles completely.
  Iterable<String> settledChargeIds(Iterable<OpenCharge> charges) {
    final byId = {for (final c in charges) c.id: c};
    return allocations
        .where((a) => byId[a.chargeId]?.outstanding == a.amount)
        .map((a) => a.chargeId);
  }
}

/// Applies [payment] to [charges]: the [chosenChargeIds] first, in the order
/// given, then the rest oldest-first (by due date, then id).
///
/// This mirrors the database's allocation (`private.allocate_payment`, used
/// by `record_payment` and `apply_deposit`) exactly — including that a
/// [depositAdjustment] never pays the security deposit itself — and is used
/// to preview what a payment will clear before it is saved. Every chosen id
/// must be one of [charges] (the database rejects others with
/// `invalid_charge_selection`).
AllocationPlan planFifoAllocation(
  Money payment,
  Iterable<OpenCharge> charges, {
  List<String> chosenChargeIds = const [],
  bool depositAdjustment = false,
}) {
  if (payment.isNegative) {
    throw ArgumentError.value(payment, 'payment', 'must be >= 0');
  }
  final open = charges.toList();
  final known = {for (final charge in open) charge.id};
  for (final id in chosenChargeIds) {
    if (!known.contains(id)) {
      throw ArgumentError.value(id, 'chosenChargeIds', 'not an open charge');
    }
  }
  // Like array_position: a charge chosen twice keeps its first position.
  int rank(OpenCharge charge) {
    final index = chosenChargeIds.indexOf(charge.id);
    return index < 0 ? chosenChargeIds.length : index;
  }

  final ordered =
      open
          .where((charge) => !(depositAdjustment && charge.isSecurityDeposit))
          .toList()
        ..sort((a, b) {
          final byChoice = rank(a).compareTo(rank(b));
          if (byChoice != 0) return byChoice;
          final byDue = a.dueDate.compareTo(b.dueDate);
          return byDue != 0 ? byDue : a.id.compareTo(b.id);
        });
  var remaining = payment;
  final allocations = <ChargeAllocation>[];
  for (final charge in ordered) {
    if (remaining.isZero) break;
    final applied = Money.min(remaining, charge.outstanding);
    allocations.add(ChargeAllocation(chargeId: charge.id, amount: applied));
    remaining -= applied;
  }
  return AllocationPlan(allocations: allocations, unallocated: remaining);
}
