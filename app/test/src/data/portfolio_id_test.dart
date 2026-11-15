import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';

import '../../support/fakes.dart';
import '../../support/money_fakes.dart';
import '../../support/operations_fakes.dart';

/// A model the cache tags by the portfolio its row names: how it is read
/// and written, and one of it.
typedef _Model = ({
  String columns,
  Object fixture,
  Object Function(Object? row) fromRow,
  Map<String, Object?> Function(Object model) toRow,
  String? Function(Object model) portfolioOf,
});

final ReminderLog _reminder = FakeReminderRepository().logs.single;

final Map<String, _Model> _models = {
  'Tenant': (
    columns: Tenant.columns,
    fixture: aliRaza,
    fromRow: Tenant.fromRow,
    toRow: (m) => (m as Tenant).toRow(),
    portfolioOf: (m) => (m as Tenant).portfolioId,
  ),
  'Property': (
    columns: Property.columns,
    fixture: gulbergHouse,
    fromRow: Property.fromRow,
    toRow: (m) => (m as Property).toRow(),
    portfolioOf: (m) => (m as Property).portfolioId,
  ),
  'Unit': (
    columns: Unit.columns,
    fixture: groundFloor,
    fromRow: Unit.fromRow,
    toRow: (m) => (m as Unit).toRow(),
    portfolioOf: (m) => (m as Unit).portfolioId,
  ),
  'Lease': (
    columns: Lease.columns,
    fixture: aliLease,
    fromRow: Lease.fromRow,
    toRow: (m) => (m as Lease).toRow(),
    portfolioOf: (m) => (m as Lease).portfolioId,
  ),
  'ReminderLog': (
    columns: ReminderLog.columns,
    fixture: _reminder,
    fromRow: ReminderLog.fromRow,
    toRow: (m) => (m as ReminderLog).toRow(),
    portfolioOf: (m) => (m as ReminderLog).portfolioId,
  ),
  'MaintenanceRequest': (
    columns: MaintenanceRequest.columns,
    fixture: seepageJob,
    fromRow: MaintenanceRequest.fromRow,
    toRow: (m) => (m as MaintenanceRequest).toRow(),
    portfolioOf: (m) => (m as MaintenanceRequest).portfolioId,
  ),
  'Expense': (
    columns: Expense.columns,
    fixture: plumberExpense,
    fromRow: Expense.fromRow,
    toRow: (m) => (m as Expense).toRow(),
    portfolioOf: (m) => (m as Expense).portfolioId,
  ),
  'UtilityAccount': (
    columns: UtilityAccount.columns,
    fixture: lescoMeter,
    fromRow: UtilityAccount.fromRow,
    toRow: (m) => (m as UtilityAccount).toRow(),
    portfolioOf: (m) => (m as UtilityAccount).portfolioId,
  ),
  'UtilityBill': (
    columns: UtilityBill.columns,
    fixture: novemberBill,
    fromRow: UtilityBill.fromRow,
    toRow: (m) => (m as UtilityBill).toRow(),
    portfolioOf: (m) => (m as UtilityBill).portfolioId,
  ),
  'MeterReading': (
    columns: MeterReading.columns,
    fixture: moveInReading,
    fromRow: MeterReading.fromRow,
    toRow: (m) => (m as MeterReading).toRow(),
    portfolioOf: (m) => (m as MeterReading).portfolioId,
  ),
};

void main() {
  for (final MapEntry(key: name, value: model) in _models.entries) {
    group('$name names its portfolio', () {
      test('its select asks for the column', () {
        // The base table's own column, not an embedded one's.
        final top = model.columns.split(RegExp(r',(?![^(]*\))'));
        expect(top, contains('portfolio_id'));
      });

      test('it reads the column, and keeps it in the saved copy', () {
        final row = {...model.toRow(model.fixture), 'portfolio_id': 'p-9'};
        final read = model.fromRow(row);
        expect(model.portfolioOf(read), 'p-9');
        expect(model.toRow(read)['portfolio_id'], 'p-9');
        expect(model.portfolioOf(model.fromRow(model.toRow(read))), 'p-9');
      });

      test('a row without it is refused, a null reads as unknown', () {
        final row = {...model.toRow(model.fixture)}..remove('portfolio_id');
        // Strict, as every column: the server and the app disagree.
        expect(() => model.fromRow(row), throwsFormatException);
        final unknown = {...row, 'portfolio_id': null};
        expect(model.portfolioOf(model.fromRow(unknown)), isNull);
      });

      test('two copies in different portfolios are not equal', () {
        final a = model.fromRow({
          ...model.toRow(model.fixture),
          'portfolio_id': 'p-1',
        });
        final b = model.fromRow({
          ...model.toRow(model.fixture),
          'portfolio_id': 'p-2',
        });
        expect(a, isNot(b));
        expect(a, model.fromRow(model.toRow(a)));
      });
    });
  }

  test('the fakes put every fixture in its portfolio', () {
    for (final MapEntry(key: name, value: model) in _models.entries) {
      expect(model.portfolioOf(model.fixture), gulberg.id, reason: name);
    }
    expect(saddarPlaza.portfolioId, plaza.id);
  });
}
