import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:mm_core/mm_core.dart';

/// One month of money in and out (`public.get_cashflow`): what was
/// received (and what it paid: rent and late fees, deposits, other dues),
/// the tax tenants withheld, the expenses and the deposits refunded.
@immutable
final class CashflowMonth {
  const new({
    required this.month,
    required this.received,
    required this.rent,
    required this.deposits,
    required this.other,
    required this.taxWithheld,
    required this.expenses,
    required this.depositRefunds,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'cash flow month');
    return CashflowMonth(
      month: MonthPeriod.of(row.date('month')),
      received: row.money('cash_received'),
      rent: row.money('rent_collected'),
      deposits: row.money('deposits_collected'),
      other: row.money('other_collected'),
      taxWithheld: row.money('tax_withheld'),
      expenses: row.money('expenses'),
      depositRefunds: row.money('deposit_refunds'),
    );
  }

  final MonthPeriod month;

  /// Cash received in the month (deposit adjustments are not cash).
  final Money received;

  /// What of it (and of the tax withheld) paid rent and late fees.
  final Money rent;
  final Money deposits;
  final Money other;
  final Money taxWithheld;
  final Money expenses;
  final Money depositRefunds;

  /// Money in less money out: received, less expenses and refunds.
  Money get net => received - expenses - depositRefunds;

  Map<String, Object?> toRow() => {
    'month': month.first.toIso(),
    'cash_received': received.toJson(),
    'rent_collected': rent.toJson(),
    'deposits_collected': deposits.toJson(),
    'other_collected': other.toJson(),
    'tax_withheld': taxWithheld.toJson(),
    'expenses': expenses.toJson(),
    'deposit_refunds': depositRefunds.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is CashflowMonth && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// A property's money over a period (`public.get_property_performance`):
/// its units and how many are let today, rent (with late fees) and other
/// income received, its expenses, the net operating income, and the gross
/// and net yields a year on its estimated value.
@immutable
final class PropertyPerformance {
  const new({
    required this.propertyId,
    required this.propertyName,
    required this.units,
    required this.occupiedUnits,
    required this.rentIncome,
    required this.otherIncome,
    required this.expenses,
    required this.netOperatingIncome,
    this.estimatedValue,
    this.grossYield,
    this.netYield,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'property performance');
    final map = json! as Map;
    return PropertyPerformance(
      propertyId: row.string('property_id'),
      propertyName: row.string('property_name'),
      units: row.integer('units'),
      occupiedUnits: row.integer('occupied_units'),
      rentIncome: row.money('rent_income'),
      otherIncome: row.money('other_income'),
      expenses: row.money('expenses'),
      netOperatingIncome: row.money('net_operating_income'),
      estimatedValue: row.optionalMoney('estimated_value'),
      grossYield: ratioBasisPoints(map['gross_yield'], 'gross_yield'),
      netYield: ratioBasisPoints(map['net_yield'], 'net_yield'),
    );
  }

  final String propertyId;
  final String propertyName;
  final int units;
  final int occupiedUnits;
  final Money rentIncome;
  final Money otherIncome;
  final Money expenses;
  final Money netOperatingIncome;
  final Money? estimatedValue;

  /// Rent a year over the estimated value, in basis points; null without
  /// a value.
  final int? grossYield;

  /// Net operating income a year over the estimated value.
  final int? netYield;

  /// Let units over units, in basis points; null without units.
  int? get occupancy =>
      units == 0 ? null : (occupiedUnits * 10000 / units).round();

  Map<String, Object?> toRow() => {
    'property_id': propertyId,
    'property_name': propertyName,
    'units': units,
    'occupied_units': occupiedUnits,
    'rent_income': rentIncome.toJson(),
    'other_income': otherIncome.toJson(),
    'expenses': expenses.toJson(),
    'net_operating_income': netOperatingIncome.toJson(),
    'estimated_value': estimatedValue?.toJson(),
    'gross_yield': ratioToJson(grossYield),
    'net_yield': ratioToJson(netYield),
  };

  @override
  bool operator ==(Object other) =>
      other is PropertyPerformance && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// A rent due that fell due in the last year, and when it was settled
/// (`public.get_payment_facts`): what payment scores are made of.
@immutable
final class PaymentFact {
  const new({
    required this.leaseId,
    required this.tenantId,
    required this.chargeId,
    required this.dueDate,
    required this.amount,
    required this.waived,
    required this.outstanding,
    required this.graceDays,
    required this.monthlyRent,
    this.settledOn,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'payment fact');
    return PaymentFact(
      leaseId: row.string('lease_id'),
      tenantId: row.string('tenant_id'),
      chargeId: row.string('charge_id'),
      dueDate: row.date('due_date'),
      amount: row.money('amount'),
      waived: row.money('waived'),
      outstanding: row.money('outstanding'),
      settledOn: row.optionalDate('settled_on'),
      graceDays: row.integer('grace_days'),
      monthlyRent: row.money('monthly_rent'),
    );
  }

  final String leaseId;
  final String tenantId;
  final String chargeId;
  final CalendarDate dueDate;
  final Money amount;
  final Money waived;
  final Money outstanding;

  /// The day of the payment that settled it, once nothing is owed.
  final CalendarDate? settledOn;
  final int graceDays;

  /// The tenancy's rent today.
  final Money monthlyRent;

  Map<String, Object?> toRow() => {
    'lease_id': leaseId,
    'tenant_id': tenantId,
    'charge_id': chargeId,
    'due_date': dueDate.toIso(),
    'amount': amount.toJson(),
    'waived': waived.toJson(),
    'outstanding': outstanding.toJson(),
    'settled_on': settledOn?.toIso(),
    'grace_days': graceDays,
    'monthly_rent': monthlyRent.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PaymentFact && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// A property's rental income in a tax year, for the landlord's
/// accountant (`public.get_tax_year_statement`): rent and late fees
/// settled in the year (cash plus tax withheld), the tax tenants withheld,
/// the one-fifth repairs allowance, the expenses by category, and the
/// income after the allowance. Informational: not tax advice.
@immutable
final class TaxYearProperty {
  const new({
    required this.propertyId,
    required this.propertyName,
    required this.grossRent,
    required this.taxWithheld,
    required this.repairsAllowance,
    required this.expensesByCategory,
    required this.expensesTotal,
    required this.netAfterRepairsAllowance,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'tax year property');
    final categories = row.object('expenses_by_category');
    return TaxYearProperty(
      propertyId: row.string('property_id'),
      propertyName: row.string('property_name'),
      grossRent: row.money('gross_rent'),
      taxWithheld: row.money('tax_withheld'),
      repairsAllowance: row.money('repairs_allowance'),
      expensesByCategory: {
        for (final name
            in ((json! as Map)['expenses_by_category']! as Map).keys
                .cast<String>())
          ExpenseCategory.parse(name): categories.money(name),
      },
      expensesTotal: row.money('expenses_total'),
      netAfterRepairsAllowance: row.money('net_after_repairs_allowance'),
    );
  }

  final String propertyId;
  final String propertyName;
  final Money grossRent;
  final Money taxWithheld;

  /// One fifth of [grossRent] (s.15A).
  final Money repairsAllowance;
  final Map<ExpenseCategory, Money> expensesByCategory;
  final Money expensesTotal;

  /// [grossRent] less [repairsAllowance]. The server does not take other
  /// expenses off: which are deductible is for the accountant.
  final Money netAfterRepairsAllowance;

  Map<String, Object?> toRow() => {
    'property_id': propertyId,
    'property_name': propertyName,
    'gross_rent': grossRent.toJson(),
    'tax_withheld': taxWithheld.toJson(),
    'repairs_allowance': repairsAllowance.toJson(),
    'expenses_by_category': {
      for (final entry in expensesByCategory.entries)
        entry.key.db: entry.value.toJson(),
    },
    'expenses_total': expensesTotal.toJson(),
    'net_after_repairs_allowance': netAfterRepairsAllowance.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is TaxYearProperty &&
      other.propertyId == propertyId &&
      other.propertyName == propertyName &&
      other.grossRent == grossRent &&
      other.taxWithheld == taxWithheld &&
      other.repairsAllowance == repairsAllowance &&
      mapEquals(other.expensesByCategory, expensesByCategory) &&
      other.expensesTotal == expensesTotal &&
      other.netAfterRepairsAllowance == netAfterRepairsAllowance;

  @override
  int get hashCode => Object.hash(
    propertyId,
    propertyName,
    grossRent,
    taxWithheld,
    repairsAllowance,
    Object.hashAllUnordered(
      expensesByCategory.entries.map((e) => (e.key, e.value)),
    ),
    expensesTotal,
    netAfterRepairsAllowance,
  );
}

/// A tax year's statement: one row per property with income or expenses
/// in the year.
@immutable
final class TaxYearStatement {
  const new({required this.taxYear, required this.properties});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'tax year statement');
    return TaxYearStatement(
      taxYear: TaxYear(row.integer('tax_year')),
      properties: [
        for (final item in row.list('properties'))
          TaxYearProperty.fromRow(item),
      ],
    );
  }

  final TaxYear taxYear;
  final List<TaxYearProperty> properties;

  Money get grossRent => Money.sum([for (final p in properties) p.grossRent]);
  Money get taxWithheld =>
      Money.sum([for (final p in properties) p.taxWithheld]);
  Money get repairsAllowance =>
      Money.sum([for (final p in properties) p.repairsAllowance]);
  Money get expensesTotal =>
      Money.sum([for (final p in properties) p.expensesTotal]);
  Money get netAfterRepairsAllowance =>
      Money.sum([for (final p in properties) p.netAfterRepairsAllowance]);

  Map<String, Object?> toJson() => {
    'tax_year': taxYear.endYear,
    'properties': [for (final p in properties) p.toRow()],
  };

  @override
  bool operator ==(Object other) =>
      other is TaxYearStatement &&
      other.taxYear == taxYear &&
      listEquals(other.properties, properties);

  @override
  int get hashCode => Object.hash(taxYear, Object.hashAll(properties));
}

/// What a search result is.
enum SearchKind with DbEnum {
  property('property'),
  unit('unit'),
  tenant('tenant');

  new(this.db);

  @override
  final String db;

  static SearchKind parse(String name) => parseDbEnum(values, name);
}

/// A property, unit or tenant matching a search (`public.search_portfolio`):
/// its name and a line about it (a property's locality and city, a
/// unit's property, a tenant's phone). A unit carries its property's id,
/// which its screen's address needs.
@immutable
final class SearchResult {
  const new({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.propertyId,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'search result');
    final subtitle = row.optionalString('subtitle');
    return SearchResult(
      kind: row.choice('entity_type', SearchKind.parse),
      id: row.string('entity_id'),
      title: row.string('title'),
      subtitle: subtitle == null || subtitle.trim().isEmpty ? null : subtitle,
    );
  }

  final SearchKind kind;
  final String id;
  final String title;
  final String? subtitle;

  /// The property of a unit (null for the others, and for a unit whose
  /// property could not be read).
  final String? propertyId;

  /// This result with its unit's [propertyId].
  SearchResult inProperty(String? propertyId) => SearchResult(
    kind: kind,
    id: id,
    title: title,
    subtitle: subtitle,
    propertyId: propertyId,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchResult &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.propertyId == propertyId;

  @override
  int get hashCode => Object.hash(kind, id, title, subtitle, propertyId);
}
