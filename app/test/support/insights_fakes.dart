import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/insights_repository.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:mm_core/mm_core.dart';

import 'fakes.dart';
import 'money_fakes.dart';
import 'operations_fakes.dart';

/// A tenancy of Sana Iqbal in Islamabad, where no law sets a deadline for
/// police registration.
const sanaLeaseId = '0192d0c4-5555-7000-8000-000000000009';

/// `get_dashboard`'s answer for [gulberg] on 7 November 2026, as the
/// server writes it: a month part paid, rent overdue in every bucket, a
/// vacant unit, tenancies ending, increases due and missed, police
/// registrations (one past the law's deadline, one only the app's
/// reminder), a CNIC expiring, deposits short of the arrears, an unpaid
/// bill in the landlord's name, a meter over 200 units and expenses up.
Map<String, Object?> dashboardJson() => {
  'as_of': '2026-11-07',
  'month': {
    'period': '2026-11-01',
    'expected': 245000.00,
    'paid': 160000,
    'collection_rate': 0.6531,
    'cash_received': 175000,
    'tax_withheld': 5000.00,
    'by_method': {'cash': 95000, 'bank_transfer': 80000.00},
  },
  'outstanding': {
    'total': 185000,
    'overdue': 130000,
    'aging': {
      'not_due': 55000,
      'd1_30': 45000,
      'd31_60': 40000,
      'd61_90': 20000,
      'd90_plus': 25000,
    },
  },
  'occupancy': {
    'units': 6,
    'occupied': 4,
    'vacant': 1,
    'unavailable': 1,
    'rate': 0.8,
    'vacant_asking_rent': 40000,
  },
  'vacant_units': [
    {
      'unit_id': annexe.id,
      'unit_label': 'Annexe room',
      'property_id': gulbergHouse.id,
      'property_name': 'Gulberg House',
      'asking_rent': 40000,
      'vacant_since': '2026-09-23',
      'vacant_days': 45,
    },
  ],
  'top_arrears': [
    {
      'lease_id': aliLease.id,
      'tenant_id': aliRaza.id,
      'tenant_name': 'Ali Raza',
      'tenant_phone': '+923001112233',
      'unit_label': 'Ground floor',
      'property_name': 'Gulberg House',
      'monthly_rent': 85000,
      'outstanding': 130000,
      'overdue': 85000,
      'oldest_overdue_due_date': '2026-08-01',
      'days_overdue': 98,
      'last_paid_on': '2026-09-05',
      'last_reminded_at': '2026-11-01T05:30:00+00:00',
    },
    {
      'lease_id': techLeaseId,
      'tenant_id': techCorp.id,
      'tenant_name': 'Indus Tech (Pvt) Ltd',
      'tenant_phone': null,
      'unit_label': 'Shop 3',
      'property_name': 'Saddar Plaza',
      'monthly_rent': 120000,
      'outstanding': 45000,
      'overdue': 45000,
      'oldest_overdue_due_date': '2026-10-01',
      'days_overdue': 37,
      'last_paid_on': null,
      'last_reminded_at': null,
    },
  ],
  'leases_expiring': [
    {
      'lease_id': aliLease.id,
      'tenant_name': 'Ali Raza',
      'unit_label': 'Ground floor',
      'end_date': '2026-12-01',
      'days_left': 24,
    },
  ],
  'increments_upcoming': [
    {
      'lease_id': techLeaseId,
      'tenant_name': 'Indus Tech (Pvt) Ltd',
      'unit_label': 'Shop 3',
      'current_rent': 120000,
      'increment_percent': 10,
      'anniversary': '2026-11-20',
      'status': 'upcoming',
    },
  ],
  'increments_missed': [
    {
      'lease_id': aliLease.id,
      'tenant_name': 'Ali Raza',
      'unit_label': 'Ground floor',
      'current_rent': 85000,
      'increment_percent': 10.00,
      'anniversary': '2026-08-01',
      'status': 'missed',
    },
  ],
  'police_pending': [
    {
      'lease_id': techLeaseId,
      'tenant_name': 'Indus Tech (Pvt) Ltd',
      'unit_label': 'Shop 3',
      'province': 'punjab',
      'start_date': '2026-10-15',
      'deadline': '2026-10-30',
      'overdue': true,
      'status': 'pending',
      'deadline_days': 15,
      'statutory': true,
      'clock': 'possession',
      'clock_starts_on': '2026-10-15',
    },
    {
      'lease_id': sanaLeaseId,
      'tenant_name': 'Sana Iqbal',
      'unit_label': 'Flat 2B',
      'province': 'islamabad',
      'start_date': '2026-11-06',
      'deadline': '2026-11-07',
      'overdue': false,
      'status': 'submitted',
      'deadline_days': 1,
      'statutory': false,
      'clock': 'possession',
      'clock_starts_on': '2026-11-06',
    },
  ],
  'cnic_expiring': [
    {
      'tenant_id': aliRaza.id,
      'tenant_name': 'Ali Raza',
      'cnic_expiry': '2026-11-25',
      'expired': false,
    },
  ],
  'deposits': {'agreed': 255000, 'held': 110000},
  'utilities': {
    'unpaid_landlord_name_total': 18500,
    'unpaid_landlord_name_count': 1,
    'overdue_count': 1,
    'high_usage': [
      {
        'utility_account_id': lescoMeter.id,
        'property_name': 'Gulberg House',
        'unit_label': 'Ground floor',
        'billing_month': '2026-10-01',
        'units_consumed': 212.5,
        'crossed': true,
      },
    ],
  },
  'expenses': {'this_month': 64000, 'trailing_3m_avg': 30000.00},
  'counts': {
    'properties': 2,
    'tenants': 5,
    'active_leases': 4,
    'open_maintenance': 2,
    'urgent_maintenance': 1,
  },
};

/// A new portfolio's dashboard: no property yet, so nothing due, owed or
/// coming up.
Map<String, Object?> quietDashboardJson() => {
  ...dashboardJson(),
  'counts': {
    'properties': 0,
    'tenants': 0,
    'active_leases': 0,
    'open_maintenance': 0,
    'urgent_maintenance': 0,
  },
  'month': {
    'period': '2026-11-01',
    'expected': 0,
    'paid': 0,
    'collection_rate': null,
    'cash_received': 0,
    'tax_withheld': 0,
    'by_method': <String, Object?>{},
  },
  'outstanding': {
    'total': 0,
    'overdue': 0,
    'aging': {
      'not_due': 0,
      'd1_30': 0,
      'd31_60': 0,
      'd61_90': 0,
      'd90_plus': 0,
    },
  },
  'occupancy': {
    'units': 0,
    'occupied': 0,
    'vacant': 0,
    'unavailable': 0,
    'rate': null,
    'vacant_asking_rent': 0,
  },
  'vacant_units': <Object?>[],
  'top_arrears': <Object?>[],
  'leases_expiring': <Object?>[],
  'increments_upcoming': <Object?>[],
  'increments_missed': <Object?>[],
  'police_pending': <Object?>[],
  'cnic_expiring': <Object?>[],
  'deposits': {'agreed': 0, 'held': 0},
  'utilities': {
    'unpaid_landlord_name_total': 0,
    'unpaid_landlord_name_count': 0,
    'overdue_count': 0,
    'high_usage': <Object?>[],
  },
  'expenses': {'this_month': 0, 'trailing_3m_avg': 0},
};

/// A month of `get_cashflow` for [month], with [scale] times the base
/// figures.
Map<String, Object?> cashflowJson(MonthPeriod month, int scale) => {
  'month': month.first.toIso(),
  'cash_received': 40000 * scale,
  'rent_collected': 35000 * scale,
  'deposits_collected': scale.isEven ? 10000 : 0,
  'other_collected': 2000,
  'tax_withheld': 1000,
  'expenses': 9000 * (scale % 4 + 1),
  'deposit_refunds': scale == 3 ? 15000 : 0,
};

/// `get_property_performance` over a year: a house with a value, a plaza
/// without one.
List<Map<String, Object?>> performanceJson() => [
  {
    'property_id': gulbergHouse.id,
    'property_name': 'Gulberg House',
    'units': 3,
    'occupied_units': 2,
    'rent_income': 1530000,
    'other_income': 42000,
    'expenses': 186000,
    'net_operating_income': 1386000,
    'estimated_value': 45000000,
    'gross_yield': 0.034,
    'net_yield': 0.0308,
  },
  {
    'property_id': saddarPlaza.id,
    'property_name': 'Saddar Plaza',
    'units': 3,
    'occupied_units': 2,
    'rent_income': 1320000,
    'other_income': 0,
    'expenses': 240000,
    'net_operating_income': 1080000,
    'estimated_value': null,
    'gross_yield': null,
    'net_yield': null,
  },
];

/// `get_tax_year_statement` for TY2027 (and TY2026).
List<Map<String, Object?>> taxYearJson() => [
  {
    'property_id': gulbergHouse.id,
    'property_name': 'Gulberg House',
    'gross_rent': 1020000,
    'tax_withheld': 30000,
    'repairs_allowance': 204000,
    'expenses_by_category': {
      'repairs_maintenance': 45000,
      'property_tax': 18500.50,
    },
    'expenses_total': 63500.50,
    'net_after_repairs_allowance': 816000,
  },
  {
    'property_id': saddarPlaza.id,
    'property_name': 'Saddar Plaza',
    'gross_rent': 1440000,
    'tax_withheld': 144000,
    'repairs_allowance': 288000,
    'expenses_by_category': {'society_charges': 36000},
    'expenses_total': 36000,
    'net_after_repairs_allowance': 1152000,
  },
];

/// One rent due of the payment facts.
Map<String, Object?> factJson({
  required String leaseId,
  required String tenantId,
  required String dueDate,
  required num amount,
  num outstanding = 0,
  String? settledOn,
  num waived = 0,
  int grace = 5,
  num rent = 85000,
}) => {
  'lease_id': leaseId,
  'tenant_id': tenantId,
  'charge_id': 'c-$leaseId-$dueDate',
  'due_date': dueDate,
  'amount': amount,
  'waived': waived,
  'outstanding': outstanding,
  'settled_on': settledOn,
  'grace_days': grace,
  'monthly_rent': rent,
};

/// The payment facts of [gulberg]: Ali Raza late and owing, Indus Tech
/// always on time.
List<Map<String, Object?>> factsJson() => [
  for (final (due, settled) in [
    ('2026-06-01', '2026-06-04'),
    ('2026-07-01', '2026-07-20'),
  ])
    factJson(
      leaseId: aliLease.id,
      tenantId: aliRaza.id,
      dueDate: due,
      amount: 85000,
      settledOn: settled,
    ),
  for (final due in ['2026-08-01', '2026-09-01'])
    factJson(
      leaseId: aliLease.id,
      tenantId: aliRaza.id,
      dueDate: due,
      amount: 85000,
      outstanding: due == '2026-08-01' ? 85000 : 45000,
    ),
  for (final due in ['2026-09-01', '2026-10-01', '2026-11-01'])
    factJson(
      leaseId: techLeaseId,
      tenantId: techCorp.id,
      dueDate: due,
      amount: 120000,
      settledOn: due.replaceFirst('-01', '-03'),
      rent: 120000,
    ),
];

/// The rent roll of [gulberg]: Ali Raza's rent well below the asking rent.
List<Map<String, Object?>> rentRollJson() => [
  {
    'id': aliLease.id,
    'monthly_rent': 85000,
    'created_at': '2026-01-10T07:00:00+00:00',
    'tenant': {'full_name': 'Ali Raza'},
    'unit': {
      'label': 'Ground floor',
      'asking_rent': 100000,
      'property': {'name': 'Gulberg House'},
    },
  },
  {
    'id': techLeaseId,
    'monthly_rent': 120000,
    'created_at': '2026-02-10T07:00:00+00:00',
    'tenant': {'full_name': 'Indus Tech (Pvt) Ltd'},
    'unit': {
      'label': 'Shop 3',
      'asking_rent': 125000,
      'property': {'name': 'Saddar Plaza'},
    },
  },
];

/// `search_portfolio`'s answer for "ali".
List<Map<String, Object?>> searchJson() => [
  {
    'entity_type': 'tenant',
    'entity_id': aliRaza.id,
    'title': 'Ali Raza',
    'subtitle': '+923001112233',
    'score': 0.9,
  },
  {
    'entity_type': 'property',
    'entity_id': gulbergHouse.id,
    'title': 'Gulberg House',
    'subtitle': 'Gulberg III, Lahore',
    'score': 0.6,
  },
  {
    'entity_type': 'unit',
    'entity_id': annexe.id,
    'title': 'Annexe room',
    'subtitle': 'Gulberg House',
    'score': 0.4,
  },
];

/// An [InsightsRepository] answering with the fixtures above, which a
/// test may change, recording every call; [failure] fails every read.
final class FakeInsightsRepository implements InsightsRepository {
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? failure;

  Map<String, Object?> dashboardAnswer = dashboardJson();
  List<Map<String, Object?>> performanceAnswer = performanceJson();
  List<Map<String, Object?>> taxYearAnswer = taxYearJson();
  List<Map<String, Object?>> factsAnswer = factsJson();
  List<Map<String, Object?>> rentRollAnswer = rentRollJson();
  List<Map<String, Object?>> searchAnswer = searchJson();

  /// Whether the cash flow is empty (otherwise money in each month,
  /// scaled by the month's place).
  bool quietCashflow = false;

  /// Whether the cash flow has no row at all (a span the server's series
  /// left out).
  bool cashflowMissing = false;

  /// Whether a search answers only the results whose name or line holds
  /// the query (otherwise every result of [searchAnswer]).
  bool searchFilters = true;
  List<ExportCharge> charges = [];
  List<ExportPayment> payments = [];
  List<Expense> expenses = [plumberExpense, taxExpense];
  List<CashPosition> positions = FakeHandoverRepository().positions;

  Future<void> _call(String name, List<Object?> arguments) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<Dashboard> dashboard(String portfolioId) async {
    await _call('dashboard', [portfolioId]);
    return Dashboard.fromJson(dashboardAnswer);
  }

  @override
  Future<List<CashflowMonth>> cashflow(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    await _call('cashflow', [portfolioId, from, to]);
    final months = MonthPeriod.range(MonthPeriod.of(from), MonthPeriod.of(to));
    if (cashflowMissing) return const [];
    return [
      for (final (index, month) in months.indexed)
        if (quietCashflow)
          CashflowMonth(
            month: month,
            received: Money.zero,
            rent: Money.zero,
            deposits: Money.zero,
            other: Money.zero,
            taxWithheld: Money.zero,
            expenses: Money.zero,
            depositRefunds: Money.zero,
          )
        else
          CashflowMonth.fromRow(cashflowJson(month, index % 5 + 1)),
    ];
  }

  @override
  Future<List<PropertyPerformance>> propertyPerformance(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    await _call('propertyPerformance', [portfolioId, from, to]);
    return performanceAnswer.map(PropertyPerformance.fromRow).toList();
  }

  @override
  Future<List<PaymentFact>> paymentFacts(String portfolioId) async {
    await _call('paymentFacts', [portfolioId]);
    return factsAnswer.map(PaymentFact.fromRow).toList();
  }

  @override
  Future<TaxYearStatement> taxYearStatement(
    String portfolioId,
    TaxYear taxYear,
  ) async {
    await _call('taxYearStatement', [portfolioId, taxYear]);
    return TaxYearStatement(
      taxYear: taxYear,
      properties: taxYear.endYear >= 2026
          ? taxYearAnswer.map(TaxYearProperty.fromRow).toList()
          : const [],
    );
  }

  @override
  Future<List<CashPosition>> cashPositions(String portfolioId) async {
    await _call('cashPositions', [portfolioId]);
    return positions;
  }

  @override
  Future<List<RentRollEntry>> rentRoll(String portfolioId) async {
    await _call('rentRoll', [portfolioId]);
    return rentRollAnswer.map(RentRollEntry.fromRow).toList();
  }

  @override
  Future<List<SearchResult>> search(String portfolioId, String query) async {
    await _call('search', [portfolioId, query]);
    return [
      for (final row in searchAnswer)
        if (!searchFilters ||
            (row['title']! as String).toLowerCase().contains(
              query.toLowerCase(),
            ) ||
            (row['subtitle']! as String).toLowerCase().contains(
              query.toLowerCase(),
            ))
          SearchResult.fromRow(
            row,
          ).inProperty(row['entity_type'] == 'unit' ? gulbergHouse.id : null),
    ];
  }

  @override
  Future<List<ExportCharge>> chargesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    await _call('chargesBetween', [portfolioId, from, to]);
    return charges;
  }

  @override
  Future<List<ExportPayment>> paymentsBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    await _call('paymentsBetween', [portfolioId, from, to]);
    return payments;
  }

  @override
  Future<List<Expense>> expensesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    await _call('expensesBetween', [portfolioId, from, to]);
    return expenses;
  }
}
