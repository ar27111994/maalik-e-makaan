import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

void main() {
  test("lists a unit's and a tenant's tenancies and starts one", () async {
    final app = TestApp();
    final container = containerFor(app);
    final unit = leasesProvider((unitId: groundFloor.id, tenantId: null));
    final tenant = leasesProvider((unitId: null, tenantId: formerTenant.id));
    listen(container, unit);
    listen(container, tenant);
    await pumpEventQueue();
    expect(container.read(unit).value!.value, [aliLease]);
    expect(container.read(tenant).value!.value, [endedLease]);
    final started = await container
        .read(unit.notifier)
        .start(
          id: 'new-lease',
          portfolioId: gulberg.id,
          unitId: groundFloor.id,
          tenantId: aliRaza.id,
          terms: aliLease.terms,
        );
    expect(started.id, 'new-lease');
    await pumpEventQueue();
    expect(container.read(unit).value!.value.first.id, 'new-lease');
  });

  test('a tenancy is edited, re-priced, ended and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = leaseProvider(aliLease.id);
    listen(container, provider);
    await pumpEventQueue();
    final controller = container.read(provider.notifier);
    expect(container.read(provider).value!.value.occupants, hasLength(1));
    final terms = LeaseTerms(
      startDate: aliLease.terms.startDate,
      monthlyRent: aliLease.terms.monthlyRent,
      billingStartsOn: aliLease.terms.billingStartsOn,
      graceDays: 7,
    );
    expect((await controller.save(terms)).terms.graceDays, 7);
    await controller.changeRent(
      from: MonthPeriod(2027, 1),
      rent: const Money.fromRupees(93500),
      reason: RentChangeReason.annualIncrement,
    );
    expect(
      container.read(provider).value!.value.rentChanges.first.monthlyRent,
      const Money.fromRupees(93500),
    );
    await controller.addOccupant(
      gulberg.id,
      const Occupant(id: 'occ-2', fullName: 'Zara Raza'),
    );
    await controller.saveOccupant(
      const Occupant(id: 'occ-2', fullName: 'Zara R.'),
    );
    expect(
      container.read(provider).value!.value.occupants.last.fullName,
      'Zara R.',
    );
    await controller.removeOccupant('occ-2');
    expect(container.read(provider).value!.value.occupants, hasLength(1));
    await controller.end(
      movedOutOn: CalendarDate(2026, 11, 7),
      reason: EndReason.termCompleted,
    );
    expect(container.read(provider).value!.value.lease.active, isFalse);
    app.leases.gate.failure = const RejectedFailure('lease_has_records');
    await expectLater(controller.delete(), throwsA(isA<RejectedFailure>()));
    app.leases.gate.failure = null;
    await controller.delete();
    expect(app.leases.calls.last.$1, 'deleteLease');
  });
}
