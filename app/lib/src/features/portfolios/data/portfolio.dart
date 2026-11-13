import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

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

  /// May answer "Does the owner of these properties live abroad?" while
  /// nobody has (`set_owner_abroad`).
  bool get answersOwnerAbroad => this == owner || this == manager;

  /// May change that answer once given.
  bool get changesOwnerAbroad => this == owner;

  /// May name or clear the portfolio's caretaker (`set_caretaker`).
  bool get namesCaretaker => this == owner;

  /// May be named the caretaker: the caretaker is always a manager.
  bool get canBeCaretaker => this == manager;

  /// The role named [name]; throws [FormatException] for any other.
  static MemberRole parse(String name) =>
      values.asNameMap()[name] ??
      (throw FormatException('unknown member role', name));
}

/// A portfolio the signed-in user belongs to, with their role in it and
/// the portfolio's answer to "Does the owner of these properties live
/// abroad?".
@immutable
final class PortfolioMembership {
  const new({
    required this.id,
    required this.name,
    required this.role,
    this.ownerAbroad = OwnerAbroad.notAnswered,
  });

  /// Reads a `portfolio_members` row selected with
  /// [PortfolioMembership.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'membership');
    final portfolio = row.object('portfolio');
    return PortfolioMembership(
      id: portfolio.string('id'),
      name: portfolio.string('name'),
      role: MemberRole.parse(row.string('role')),
      ownerAbroad: OwnerAbroad.fromJson(
        portfolio.optionalBoolean('owner_abroad'),
      ),
    );
  }

  /// The columns [PortfolioMembership.fromRow] reads, the portfolio embedded
  /// as `portfolio`. There is exactly one relationship between
  /// `portfolio_members` and `portfolios` (01_schema_security pins it), so
  /// the embed needs no hint, as in the released 1.0 apps.
  static const columns =
      'role,portfolio:portfolios!inner(id,name,owner_abroad)';

  /// The longest name the database accepts.
  static const maxNameLength = 80;

  final String id;
  final String name;
  final MemberRole role;

  /// The portfolio's answer; the overseas-owner rules run only when it is
  /// [OwnerAbroad.abroad].
  final OwnerAbroad ownerAbroad;

  /// Whether the app asks this user the question on opening the portfolio:
  /// nobody has answered, and they are an owner or a manager.
  bool get asksOwnerAbroad =>
      ownerAbroad.needsAnswer && role.answersOwnerAbroad;

  /// This membership with the portfolio's answer [ownerAbroad].
  PortfolioMembership withOwnerAbroad(OwnerAbroad ownerAbroad) =>
      PortfolioMembership(
        id: id,
        name: name,
        role: role,
        ownerAbroad: ownerAbroad,
      );

  /// The row [PortfolioMembership.fromRow] reads back (for the offline
  /// cache).
  Map<String, Object?> toRow() => {
    'role': role.name,
    'portfolio': {'id': id, 'name': name, 'owner_abroad': ownerAbroad.toJson()},
  };

  @override
  bool operator ==(Object other) =>
      other is PortfolioMembership &&
      other.id == id &&
      other.name == name &&
      other.role == role &&
      other.ownerAbroad == ownerAbroad;

  @override
  int get hashCode => Object.hash(id, name, role, ownerAbroad);
}
