import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_labels.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_labels.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../support/harness.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('every value has words in ${locale.languageCode}', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final words = <String>[
        for (final v in PropertyType.values) l10n.propertyType(v),
        for (final v in Province.values) l10n.province(v),
        for (final v in Province.values) l10n.policeHint(v),
        for (final v in AreaUnit.values) l10n.areaUnit(v),
        for (final v in UnitType.values) l10n.unitType(v),
        for (final v in TenantKind.values) l10n.tenantKind(v),
        for (final v in GuardianRelation.values) l10n.guardianRelation(v),
        for (final v in PoliceStatus.values) l10n.policeStatus(v),
        for (final v in PoliceChannel.values) l10n.policeChannel(v),
        for (final v in RegistrarStatus.values) l10n.registrarStatus(v),
        for (final v in EndReason.values) l10n.endReason(v),
        for (final v in RentChangeReason.values) l10n.rentReason(v),
      ];
      expect(words.every((w) => w.trim().isNotEmpty), isTrue);
      const money = MoneyFormat();
      expect(l10n.lateFee(const NoLateFee(), money), isNotEmpty);
      expect(
        l10n.lateFee(const FlatLateFee(Money.fromRupees(500)), money),
        contains('500'),
      );
      expect(l10n.lateFee(const PercentLateFee(250), money), contains('2.5'));
      expect(
        l10n.lateFee(const DailyLateFee(Money.fromRupees(100)), money),
        contains('100'),
      );
      expect(
        guardianText(
          l10n,
          const Tenant(
            id: 't',
            fullName: 'x',
            guardianName: 'Ahmed',
            guardianRelation: GuardianRelation.other,
          ),
        ),
        'Ahmed',
      );
      expect(guardianText(l10n, const Tenant(id: 't', fullName: 'x')), isNull);
    });
  }

  test('police portals exist for Punjab, Sindh and Islamabad', () {
    expect(
      [for (final p in Province.values) policePortal(p) != null],
      [true, true, false, false, true, false, false],
    );
  });

  test('pages keep their cursor through JSON', () {
    const cursor = PageCursor(createdAt: '2026-01-01T00:00:00+00:00', id: 'a');
    expect(PageCursor.fromJson(cursor.toJson()), cursor);
    expect(cursor.hashCode, PageCursor.fromJson(cursor.toJson()).hashCode);
    const page = Paged(['x'], next: cursor);
    final json = page.toJson((item) => item);
    expect(Paged<String>.fromJson(json, (j) => j! as String), page);
    expect(
      page.hashCode,
      Paged<String>.fromJson(json, (j) => j! as String).hashCode,
    );
    expect(page.followedBy(const Paged(['y'])).items, ['x', 'y']);
    expect(Paged.page(List.filled(pageSize, 'z'), (_) => cursor).next, cursor);
    expect(() => PageCursor.fromJson('x'), throwsFormatException);
  });

  testWidgets('badges for every occupancy and an upcoming tenancy', (
    tester,
  ) async {
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
    final labels = [
      for (final status in OccupancyStatus.values)
        occupancyBadge(context, Occupancy(status: status)).label,
      occupancyBadge(context, null).label,
    ];
    expect(labels, [
      'Let',
      'Tenancy starts soon',
      'Vacant',
      'Not available',
      'Archived',
      'Status unknown',
      'Status unknown',
    ]);
    final later = Lease.fromRow({
      ...aliLease.toRow(),
      'start_date': '2027-01-01',
      'billing_starts_on': '2027-01-01',
    });
    expect(leaseBadge(context, later).label, 'Starts 1 Jan 2027');
    expect(leaseBadge(context, aliLease).status, MmStatus.paid);
  });
}
