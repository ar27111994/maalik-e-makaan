import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';

/// What a notification is about (`public.notification_kind`), with
/// [unknown] for a kind a newer server sends that this app does not know.
enum NotificationKind with DbEnum {
  rentDueSoon('rent_due_soon'),
  rentOverdue('rent_overdue'),
  leaseExpiring('lease_expiring'),
  incrementDue('increment_due'),
  policePending('police_registration_pending'),
  policeOverdue('police_registration_overdue'),
  cnicExpiring('cnic_expiring'),
  utilityBillDue('utility_bill_due'),
  invitationAccepted('invitation_accepted'),
  unknown('unknown');

  new(this.db);

  @override
  final String db;

  /// The kind named [name], or [unknown].
  static NotificationKind parse(String name) {
    for (final kind in values) {
      if (kind.db == name && kind != unknown) return kind;
    }
    return unknown;
  }
}

/// One entry of a member's inbox (REM-03): a [kind] and the [params] the
/// daily job filled in, which the app turns into words.
@immutable
final class AppNotification {
  const new({
    required this.id,
    required this.kind,
    required this.params,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.readAt,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'notification');
    final params = row.object('params');
    return AppNotification(
      id: row.string('id'),
      kind: NotificationKind.parse(row.string('kind')),
      params: Map.unmodifiable(params as Map<String, Object?>),
      entityType: row.optionalString('entity_type'),
      entityId: row.optionalString('entity_id'),
      readAt: row.optionalTimestamp('read_at'),
      createdAt: row.string('created_at'),
    );
  }

  static const columns =
      'id,kind,params,entity_type,entity_id,read_at,created_at';

  final String id;
  final NotificationKind kind;
  final Map<String, Object?> params;
  final String? entityType;
  final String? entityId;
  final DateTime? readAt;

  /// The timestamp exactly as PostgREST wrote it.
  final String createdAt;

  bool get unread => readAt == null;

  DateTime get created => JsonRow({'at': createdAt}).timestamp('at');

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// The string parameter [name], or null when it is missing or not text.
  String? text(String name) => switch (params[name]) {
    final String value => value,
    _ => null,
  };

  AppNotification read(DateTime at) => AppNotification(
    id: id,
    kind: kind,
    params: params,
    entityType: entityType,
    entityId: entityId,
    readAt: at,
    createdAt: createdAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind == NotificationKind.unknown ? 'unknown' : kind.db,
    'params': params,
    'entity_type': entityType,
    'entity_id': entityId,
    'read_at': readAt?.toIso8601String(),
    'created_at': createdAt,
  };

  @override
  bool operator ==(Object other) =>
      other is AppNotification &&
      other.id == id &&
      other.kind == kind &&
      mapEquals(other.params, params) &&
      other.entityType == entityType &&
      other.entityId == entityId &&
      other.readAt == readAt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, kind, entityType, entityId, readAt);
}
