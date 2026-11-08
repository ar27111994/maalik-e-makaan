import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test(
      'every operations value has words in ${locale.languageCode}',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final words = <String>[
          for (final v in ExpenseCategory.values) l10n.expenseCategory(v),
          for (final v in UtilityType.values) l10n.utilityType(v),
          for (final v in UtilityProvider.values) l10n.utilityProvider(v),
          for (final v in BillResponsibility.values) l10n.responsibility(v),
          for (final v in BillPayer.values) l10n.billPayer(v),
          for (final v in ReadingContext.values) l10n.readingContext(v),
          for (final v in MaintenanceCategory.values)
            l10n.maintenanceCategory(v),
          for (final v in MaintenancePriority.values)
            l10n.maintenancePriority(v),
          for (final v in MaintenanceStatus.values) l10n.maintenanceStatus(v),
        ];
        expect(words.every((w) => w.trim().isNotEmpty), isTrue);
        expect(words.toSet(), hasLength(greaterThan(40)));
      },
    );
  }

  test('every kind of connection has its icon', () {
    expect(UtilityType.values.map(utilityIcon).toSet(), hasLength(5));
  });

  testWidgets('names connections, and badges bills and repairs by where '
      'they stand', (tester) async {
    late BuildContext context;
    await pumpScreen(
      tester,
      () => Builder(
        builder: (inner) {
          context = inner;
          return const SizedBox.shrink();
        },
      ),
    );
    expect(
      connectionName(
        context,
        type: UtilityType.internet,
        provider: UtilityProvider.other,
        providerOther: 'Nayatel',
      ),
      contains('Nayatel'),
    );
    expect(
      connectionName(
        context,
        type: UtilityType.other,
        provider: UtilityProvider.other,
      ),
      'Other',
    );
    UtilityBill bill({CalendarDate? due}) =>
        UtilityBill.fromRow({...gasBill.toRow(), 'due_date': due?.toJson()});
    expect(billBadge(context, bill()).label, 'Unpaid');
    expect(
      billBadge(context, bill(due: CalendarDate(2026, 11, 7))).label,
      'Due today',
    );
    expect(
      billBadge(context, bill(due: CalendarDate(2026, 11, 9))).label,
      'Due in 2 days',
    );
    expect(billBadge(context, octoberBill).status, MmStatus.paid);
    expect(protectedBadge(context, ProtectedUse.within), isNull);
    expect(protectedBadge(context, null), isNull);
    for (final status in MaintenanceStatus.values) {
      expect(maintenanceBadge(context, status).label, isNotEmpty);
    }
    expect(
      maintenanceBadge(context, MaintenanceStatus.cancelled).status,
      MmStatus.neutral,
    );
  });
}
