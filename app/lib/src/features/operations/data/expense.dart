import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';

/// What money was spent on (`public.expense_category`).
enum ExpenseCategory with DbEnum {
  repairsMaintenance('repairs_maintenance'),
  propertyTax('property_tax'),
  utilities('utilities'),
  societyCharges('society_charges'),
  insurance('insurance'),
  legalProfessional('legal_professional'),
  agentCommission('agent_commission'),
  staffSalaries('staff_salaries'),
  cleaningSecurity('cleaning_security'),
  renovation('renovation'),
  bankCharges('bank_charges'),
  loanInterest('loan_interest'),
  other('other');

  new(this.db);

  @override
  final String db;

  static ExpenseCategory parse(String name) => parseDbEnum(values, name);
}

/// [value] tidied as one line and kept within [max] code points, the way
/// the database counts a column's length; null when nothing is left.
String? optionalText(String? value, int max) {
  final tidy = sanitizeOptional(value);
  return tidy == null ? null : fitCodePoints(tidy, max);
}

/// [value] tidied as lines of text and kept within [max] code points; null
/// when nothing is left.
String? optionalLines(String? value, int max) {
  if (value == null) return null;
  final tidy = sanitizeMultiline(value);
  return tidy.isEmpty ? null : fitCodePoints(tidy, max);
}

/// Money spent on the portfolio, a property or a unit (EXP-01): repairs,
/// property tax, salaries… It may be linked to a maintenance job, and its
/// receipt is a document attached to it.
@immutable
final class Expense {
  const new({
    required this.id,
    required this.category,
    required this.amount,
    required this.spentOn,
    this.method = PaymentMethod.cash,
    this.propertyId,
    this.propertyName,
    this.unitId,
    this.unitLabel,
    this.maintenanceRequestId,
    this.maintenanceTitle,
    this.payee,
    this.reference,
    this.notes,
    this.paidBy,
    this.createdAt = '',
  });

  /// Reads an `expenses` row selected with [Expense.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'expense');
    return Expense(
      id: row.string('id'),
      propertyId: row.optionalString('property_id'),
      propertyName: row.optionalObject('property')?.string('name'),
      unitId: row.optionalString('unit_id'),
      unitLabel: row.optionalObject('unit')?.string('label'),
      maintenanceRequestId: row.optionalString('maintenance_request_id'),
      maintenanceTitle: row.optionalObject('request')?.string('title'),
      category: row.choice('category', ExpenseCategory.parse),
      amount: row.money('amount'),
      spentOn: row.date('spent_on'),
      payee: row.optionalString('payee'),
      method: row.choice('method', PaymentMethod.parse),
      reference: row.optionalString('reference'),
      notes: row.optionalString('notes'),
      paidBy: row.optionalString('paid_by'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [Expense.fromRow] reads, with the property, unit and
  /// maintenance job embedded through their composite foreign keys.
  static const columns =
      'id,property_id,unit_id,maintenance_request_id,category,amount,'
      'spent_on,payee,method,reference,notes,paid_by,created_at,'
      'property:properties!expenses_property_fkey(name),'
      'unit:units!expenses_unit_fkey(label),'
      'request:maintenance_requests!expenses_maintenance_fkey(title)';

  /// The longest payee, reference and note the database keeps.
  static const maxPayeeLength = 120;
  static const maxReferenceLength = 80;
  static const maxNotesLength = 1000;

  final String id;
  final ExpenseCategory category;
  final Money amount;
  final CalendarDate spentOn;
  final PaymentMethod method;

  /// The property it was spent on; null for the whole portfolio.
  final String? propertyId;
  final String? propertyName;

  /// The unit it was spent on, within [propertyId].
  final String? unitId;
  final String? unitLabel;

  /// The maintenance job it paid for.
  final String? maintenanceRequestId;
  final String? maintenanceTitle;

  /// Who was paid (a plumber, the excise office).
  final String? payee;
  final String? reference;
  final String? notes;

  /// The member who paid; a cash expense comes out of their cash in hand.
  final String? paidBy;
  final String createdAt;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// What [Expense.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    'property_id': propertyId,
    'property': propertyName == null ? null : {'name': propertyName},
    'unit_id': unitId,
    'unit': unitLabel == null ? null : {'label': unitLabel},
    'maintenance_request_id': maintenanceRequestId,
    'request': maintenanceTitle == null ? null : {'title': maintenanceTitle},
    'category': category.db,
    'amount': amount.toJson(),
    'spent_on': spentOn.toJson(),
    'payee': payee,
    'method': method.db,
    'reference': reference,
    'notes': notes,
    'paid_by': paidBy,
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    category,
    amount,
    spentOn,
    method,
    propertyId,
    propertyName,
    unitId,
    unitLabel,
    maintenanceRequestId,
    maintenanceTitle,
    payee,
    reference,
    notes,
    paidBy,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is Expense && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// An expense to add or save (`expenses` insert and update grants). Who
/// paid is not sent: the database records the member who adds it.
@immutable
final class ExpenseDraft {
  const new({
    required this.category,
    required this.amount,
    required this.spentOn,
    this.method = PaymentMethod.cash,
    this.propertyId,
    this.unitId,
    this.maintenanceRequestId,
    this.payee,
    this.reference,
    this.notes,
  });

  /// [expense]'s editable fields.
  factory of(Expense expense) => ExpenseDraft(
    category: expense.category,
    amount: expense.amount,
    spentOn: expense.spentOn,
    method: expense.method,
    propertyId: expense.propertyId,
    unitId: expense.unitId,
    maintenanceRequestId: expense.maintenanceRequestId,
    payee: expense.payee,
    reference: expense.reference,
    notes: expense.notes,
  );

  final ExpenseCategory category;
  final Money amount;
  final CalendarDate spentOn;
  final PaymentMethod method;
  final String? propertyId;
  final String? unitId;
  final String? maintenanceRequestId;
  final String? payee;
  final String? reference;
  final String? notes;

  Map<String, Object?> toWrite() => {
    'property_id': propertyId,
    // A unit belongs to a property (`expenses_unit_requires_property_check`).
    'unit_id': propertyId == null ? null : unitId,
    'maintenance_request_id': maintenanceRequestId,
    'category': category.db,
    'amount': amount.toJson(),
    'spent_on': spentOn.toJson(),
    'payee': optionalText(payee, Expense.maxPayeeLength),
    'method': method.db,
    'reference': optionalText(reference, Expense.maxReferenceLength),
    'notes': optionalLines(notes, Expense.maxNotesLength),
  };

  @override
  bool operator ==(Object other) =>
      other is ExpenseDraft && mapEquals(other.toWrite(), toWrite());

  @override
  int get hashCode => Object.hashAll(toWrite().values);
}
