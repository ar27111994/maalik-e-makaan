import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// What kind of repair (`public.maintenance_category`).
enum MaintenanceCategory with DbEnum {
  plumbing('plumbing'),
  electrical('electrical'),
  carpentry('carpentry'),
  painting('painting'),
  seepage('seepage'),
  appliance('appliance'),
  pestControl('pest_control'),
  cleaning('cleaning'),
  structural('structural'),
  waterSupply('water_supply'),
  other('other');

  new(this.db);

  @override
  final String db;

  static MaintenanceCategory parse(String name) => parseDbEnum(values, name);
}

/// How soon a repair is needed (`public.maintenance_priority`).
enum MaintenancePriority with DbEnum {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  new(this.db);

  @override
  final String db;

  static MaintenancePriority parse(String name) => parseDbEnum(values, name);
}

/// Where a repair stands (`public.maintenance_status`).
enum MaintenanceStatus with DbEnum {
  open('open'),
  inProgress('in_progress'),
  onHold('on_hold'),
  resolved('resolved'),
  cancelled('cancelled');

  new(this.db);

  @override
  final String db;

  static MaintenanceStatus parse(String name) => parseDbEnum(values, name);

  /// Still to be done: open, in progress or on hold.
  bool get pending => this == open || this == inProgress || this == onHold;

  /// The statuses still to be done, or the closed ones.
  static List<MaintenanceStatus> where({required bool pending}) => [
    for (final status in values)
      if (status.pending == pending) status,
  ];
}

/// A repair or maintenance job (MAINT-01): what and where, how urgent,
/// where it stands, who does it and for how much, and how it was resolved.
@immutable
final class MaintenanceRequest {
  const new({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.reportedOn,
    this.propertyName = '',
    this.category = MaintenanceCategory.other,
    this.priority = MaintenancePriority.medium,
    this.status = MaintenanceStatus.open,
    this.unitId,
    this.unitLabel,
    this.leaseId,
    this.tenantName,
    this.description,
    this.reportedBy,
    this.assignedTo,
    this.vendorPhone,
    this.estimatedCost,
    this.resolvedOn,
    this.resolutionNote,
    this.createdAt = '',
  });

  /// Reads a `maintenance_requests` row selected with
  /// [MaintenanceRequest.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'maintenance request');
    final phone = row.optionalString('vendor_phone');
    return MaintenanceRequest(
      id: row.string('id'),
      propertyId: row.string('property_id'),
      propertyName: row.object('property').string('name'),
      unitId: row.optionalString('unit_id'),
      unitLabel: row.optionalObject('unit')?.string('label'),
      leaseId: row.optionalString('lease_id'),
      tenantName: row
          .optionalObject('lease')
          ?.object('tenant')
          .string('full_name'),
      title: row.string('title'),
      description: row.optionalString('description'),
      category: row.choice('category', MaintenanceCategory.parse),
      priority: row.choice('priority', MaintenancePriority.parse),
      status: row.choice('status', MaintenanceStatus.parse),
      reportedBy: row.optionalString('reported_by'),
      reportedOn: row.date('reported_on'),
      assignedTo: row.optionalString('assigned_to'),
      vendorPhone: phone == null ? null : PhoneNumber.fromE164(phone),
      estimatedCost: row.optionalMoney('estimated_cost'),
      resolvedOn: row.optionalDate('resolved_on'),
      resolutionNote: row.optionalString('resolution_note'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [MaintenanceRequest.fromRow] reads, with the property,
  /// unit and tenant embedded through their composite foreign keys.
  static const columns =
      'id,property_id,unit_id,lease_id,title,description,category,priority,'
      'status,reported_by,reported_on,assigned_to,vendor_phone,'
      'estimated_cost,resolved_on,resolution_note,created_at,'
      'property:properties!maintenance_requests_property_fkey(name),'
      'unit:units!maintenance_requests_unit_fkey(label),'
      'lease:leases!maintenance_requests_lease_fkey'
      '(tenant:tenants!leases_tenant_fkey(full_name))';

  static const maxTitleLength = 120;
  static const maxDescriptionLength = 2000;
  static const maxNameLength = 120;
  static const maxResolutionLength = 1000;

  final String id;
  final String propertyId;
  final String propertyName;

  /// The unit it is in; null for the property as a whole.
  final String? unitId;
  final String? unitLabel;

  /// The tenancy it was reported in, and its tenant.
  final String? leaseId;
  final String? tenantName;
  final String title;
  final String? description;
  final MaintenanceCategory category;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final String? reportedBy;
  final CalendarDate reportedOn;

  /// The vendor or worker doing it.
  final String? assignedTo;
  final PhoneNumber? vendorPhone;
  final Money? estimatedCost;
  final CalendarDate? resolvedOn;
  final String? resolutionNote;
  final String createdAt;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  Map<String, Object?> toRow() => {
    'id': id,
    'property_id': propertyId,
    'property': {'name': propertyName},
    'unit_id': unitId,
    'unit': unitLabel == null ? null : {'label': unitLabel},
    'lease_id': leaseId,
    'lease': tenantName == null
        ? null
        : {
            'tenant': {'full_name': tenantName},
          },
    'title': title,
    'description': description,
    'category': category.db,
    'priority': priority.db,
    'status': status.db,
    'reported_by': reportedBy,
    'reported_on': reportedOn.toJson(),
    'assigned_to': assignedTo,
    'vendor_phone': vendorPhone?.e164,
    'estimated_cost': estimatedCost?.toJson(),
    'resolved_on': resolvedOn?.toJson(),
    'resolution_note': resolutionNote,
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    propertyId,
    propertyName,
    unitId,
    unitLabel,
    leaseId,
    tenantName,
    title,
    description,
    category,
    priority,
    status,
    reportedBy,
    reportedOn,
    assignedTo,
    vendorPhone?.e164,
    estimatedCost,
    resolvedOn,
    resolutionNote,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is MaintenanceRequest && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// A request to add or save (`maintenance_requests` grants: its property
/// is fixed once added).
@immutable
final class MaintenanceDraft {
  const new({
    required this.propertyId,
    required this.title,
    required this.reportedOn,
    this.category = MaintenanceCategory.other,
    this.priority = MaintenancePriority.medium,
    this.status = MaintenanceStatus.open,
    this.unitId,
    this.leaseId,
    this.description,
    this.reportedBy,
    this.assignedTo,
    this.vendorPhone,
    this.estimatedCost,
    this.resolvedOn,
    this.resolutionNote,
  });

  /// [request]'s editable fields.
  factory of(MaintenanceRequest request) => MaintenanceDraft(
    propertyId: request.propertyId,
    unitId: request.unitId,
    leaseId: request.leaseId,
    title: request.title,
    description: request.description,
    category: request.category,
    priority: request.priority,
    status: request.status,
    reportedBy: request.reportedBy,
    reportedOn: request.reportedOn,
    assignedTo: request.assignedTo,
    vendorPhone: request.vendorPhone,
    estimatedCost: request.estimatedCost,
    resolvedOn: request.resolvedOn,
    resolutionNote: request.resolutionNote,
  );

  final String propertyId;
  final String? unitId;
  final String? leaseId;
  final String title;
  final String? description;
  final MaintenanceCategory category;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final String? reportedBy;
  final CalendarDate reportedOn;
  final String? assignedTo;
  final PhoneNumber? vendorPhone;
  final Money? estimatedCost;

  /// When it was resolved: kept only while it is resolved
  /// (`maintenance_requests_resolved_check` needs it then).
  final CalendarDate? resolvedOn;
  final String? resolutionNote;

  /// The columns a client may update.
  Map<String, Object?> toWrite() => {
    'unit_id': unitId,
    'lease_id': leaseId,
    'title': fitCodePoints(
      sanitizeSingleLine(title),
      MaintenanceRequest.maxTitleLength,
    ),
    'description': optionalLines(
      description,
      MaintenanceRequest.maxDescriptionLength,
    ),
    'category': category.db,
    'priority': priority.db,
    'reported_by': optionalText(reportedBy, MaintenanceRequest.maxNameLength),
    'reported_on': reportedOn.toJson(),
    'assigned_to': optionalText(assignedTo, MaintenanceRequest.maxNameLength),
    'vendor_phone': vendorPhone?.e164,
    'estimated_cost': estimatedCost?.toJson(),
    ...MaintenanceMove(
      status,
      resolvedOn: resolvedOn,
      resolutionNote: resolutionNote,
    ).toWrite(),
  };

  /// The columns of a new request.
  Map<String, Object?> toInsert() => {'property_id': propertyId, ...toWrite()};

  @override
  bool operator ==(Object other) =>
      other is MaintenanceDraft && mapEquals(other.toInsert(), toInsert());

  @override
  int get hashCode => Object.hashAll(toInsert().values);
}

/// Moving a request along its workflow (start, hold, resume, resolve,
/// cancel, reopen): all it writes is the status and, when resolved, when
/// and how, so the request's other details keep what is stored, whatever
/// copy of it the screen showed.
@immutable
final class MaintenanceMove {
  const new(this.status, {this.resolvedOn, this.resolutionNote});

  final MaintenanceStatus status;

  /// When it was resolved: kept only while it is resolved
  /// (`maintenance_requests_resolved_check` needs it then).
  final CalendarDate? resolvedOn;
  final String? resolutionNote;

  Map<String, Object?> toWrite() {
    final resolved = status == MaintenanceStatus.resolved;
    return {
      'status': status.db,
      'resolved_on': resolved ? resolvedOn?.toJson() : null,
      'resolution_note': resolved
          ? optionalLines(
              resolutionNote,
              MaintenanceRequest.maxResolutionLength,
            )
          : null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MaintenanceMove && mapEquals(other.toWrite(), toWrite());

  @override
  int get hashCode => Object.hashAll(toWrite().values);
}
