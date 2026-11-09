import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';

/// A member's role in a portfolio (`public.member_role`).
enum MemberRole {
  owner,
  manager,
  accountant,
  viewer;

  /// May add, edit and archive properties, units, tenants, tenancies and
  /// utility connections, change rent and end tenancies, and add, edit and
  /// delete maintenance requests (docs/architecture/permissions.md).
  bool get runsProperties => this == owner || this == manager;

  /// May delete properties, units, tenants, tenancies and utility
  /// connections added by mistake.
  bool get deletesRecords => this == owner;

  /// May upload documents and rename them.
  bool get recordsDocuments => this != viewer;

  /// May delete documents.
  bool get deletesDocuments => this == owner || this == manager;

  /// May record payments, add and edit charges, log reminders and record
  /// cash handovers (docs/architecture/permissions.md, Money).
  bool get recordsMoney => this != viewer;

  /// May void payments, void or waive charges, and apply or refund the
  /// security deposit.
  bool get correctsMoney => this == owner || this == manager;

  /// May void a deposit refund, and confirm or void cash handovers.
  bool get approvesMoney => this == owner;

  /// May add and edit expenses, utility bills and meter readings, and bill
  /// a utility to a tenant (docs/architecture/permissions.md, Operations).
  bool get recordsOperations => this != viewer;

  /// May delete expenses, utility bills and meter readings.
  bool get deletesOperations => this == owner || this == manager;

  /// The role named [name]; throws [FormatException] for any other.
  static MemberRole parse(String name) =>
      values.asNameMap()[name] ??
      (throw FormatException('unknown member role', name));
}

/// A portfolio the signed-in user belongs to, with their role in it.
@immutable
final class PortfolioMembership {
  const new({required this.id, required this.name, required this.role});

  /// Reads a `portfolio_members` row selected with
  /// [PortfolioMembership.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'membership');
    final portfolio = row.object('portfolio');
    return PortfolioMembership(
      id: portfolio.string('id'),
      name: portfolio.string('name'),
      role: MemberRole.parse(row.string('role')),
    );
  }

  /// The columns [PortfolioMembership.fromRow] reads, the portfolio embedded
  /// as `portfolio`.
  static const columns = 'role,portfolio:portfolios!inner(id,name)';

  /// The longest name the database accepts.
  static const maxNameLength = 80;

  final String id;
  final String name;
  final MemberRole role;

  /// The row [PortfolioMembership.fromRow] reads back (for the offline
  /// cache).
  Map<String, Object?> toRow() => {
    'role': role.name,
    'portfolio': {'id': id, 'name': name},
  };

  @override
  bool operator ==(Object other) =>
      other is PortfolioMembership &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}
