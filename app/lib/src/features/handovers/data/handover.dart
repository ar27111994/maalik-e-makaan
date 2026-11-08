import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

/// Cash a member passed on to another, usually a caretaker to the owner
/// (LEDGER-11). The owner confirms receiving it, or voids it.
@immutable
final class CashHandover {
  const new({
    required this.id,
    required this.amount,
    required this.handedOverOn,
    required this.method,
    this.fromUserId,
    this.toUserId,
    this.reference,
    this.notes,
    this.confirmedAt,
    this.voidedAt,
    this.voidReason,
    this.createdAt = '',
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'handover');
    return CashHandover(
      id: row.string('id'),
      fromUserId: row.optionalString('from_user_id'),
      toUserId: row.optionalString('to_user_id'),
      amount: row.money('amount'),
      handedOverOn: row.date('handed_over_on'),
      method: row.choice('method', PaymentMethod.parse),
      reference: row.optionalString('reference'),
      notes: row.optionalString('notes'),
      confirmedAt: row.optionalTimestamp('confirmed_at'),
      voidedAt: row.optionalTimestamp('voided_at'),
      voidReason: row.optionalString('void_reason'),
      createdAt: row.string('created_at'),
    );
  }

  static const columns =
      'id,from_user_id,to_user_id,amount,handed_over_on,method,reference,'
      'notes,confirmed_at,voided_at,void_reason,created_at';

  final String id;

  /// Who gave the cash; null once their account is deleted.
  final String? fromUserId;

  /// Who received it.
  final String? toUserId;
  final Money amount;
  final CalendarDate handedOverOn;
  final PaymentMethod method;
  final String? reference;
  final String? notes;
  final DateTime? confirmedAt;
  final DateTime? voidedAt;
  final String? voidReason;
  final String createdAt;

  bool get voided => voidedAt != null;
  bool get confirmed => confirmedAt != null;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  Map<String, Object?> toRow() => {
    'id': id,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'amount': amount.toJson(),
    'handed_over_on': handedOverOn.toJson(),
    'method': method.db,
    'reference': reference,
    'notes': notes,
    'confirmed_at': confirmedAt?.toIso8601String(),
    'voided_at': voidedAt?.toIso8601String(),
    'void_reason': voidReason,
    'created_at': createdAt,
  };

  @override
  bool operator ==(Object other) =>
      other is CashHandover && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// A handover to record (`cash_handovers` insert grant).
@immutable
final class HandoverDraft {
  const new({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.handedOverOn,
    this.method = PaymentMethod.cash,
    this.reference,
    this.notes,
  });

  final String fromUserId;
  final String toUserId;
  final Money amount;
  final CalendarDate handedOverOn;
  final PaymentMethod method;
  final String? reference;
  final String? notes;

  Map<String, Object?> toWrite() => {
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'amount': amount.toJson(),
    'handed_over_on': handedOverOn.toJson(),
    'method': method.db,
    'reference': sanitizeOptional(
      reference,
      maxLength: Payment.maxReferenceLength,
    ),
    'notes': sanitizeOptional(notes, maxLength: Payment.maxNotesLength),
  };

  @override
  bool operator ==(Object other) =>
      other is HandoverDraft && mapEquals(other.toWrite(), toWrite());

  @override
  int get hashCode => Object.hashAll(toWrite().values);
}

/// The cash a member holds (`get_cash_positions`): collected in cash, less
/// what they handed over and spent in cash.
@immutable
final class CashPosition {
  const new({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.collected,
    required this.handedOver,
    required this.spent,
    required this.inHand,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'cash position');
    return CashPosition(
      userId: row.string('user_id'),
      fullName: row.optionalString('full_name') ?? '',
      role: MemberRole.parse(row.string('role')),
      collected: row.money('cash_collected'),
      handedOver: row.money('handed_over'),
      spent: row.money('cash_expenses'),
      inHand: row.money('cash_in_hand'),
    );
  }

  final String userId;
  final String fullName;
  final MemberRole role;
  final Money collected;
  final Money handedOver;
  final Money spent;
  final Money inHand;

  Map<String, Object?> toRow() => {
    'user_id': userId,
    'full_name': fullName,
    'role': role.name,
    'cash_collected': collected.toJson(),
    'handed_over': handedOver.toJson(),
    'cash_expenses': spent.toJson(),
    'cash_in_hand': inHand.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is CashPosition && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// What the cash screen shows: who holds how much, and the handovers,
/// newest first.
@immutable
final class CashBook {
  const new({required this.positions, required this.handovers});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'cash book');
    return CashBook(
      positions: [
        for (final p in row.list('positions')) CashPosition.fromRow(p),
      ],
      handovers: Paged.fromJson(
        row.object('handovers') as Map<String, Object?>,
        CashHandover.fromRow,
      ),
    );
  }

  final List<CashPosition> positions;
  final Paged<CashHandover> handovers;

  /// The name of the member [userId], or null when unknown.
  String? nameOf(String? userId) {
    for (final position in positions) {
      if (position.userId == userId && position.fullName.isNotEmpty) {
        return position.fullName;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'positions': [for (final p in positions) p.toRow()],
    'handovers': handovers.toJson((h) => h.toRow()),
  };

  @override
  bool operator ==(Object other) =>
      other is CashBook &&
      listEquals(other.positions, positions) &&
      other.handovers == handovers;

  @override
  int get hashCode => Object.hash(Object.hashAll(positions), handovers);
}
