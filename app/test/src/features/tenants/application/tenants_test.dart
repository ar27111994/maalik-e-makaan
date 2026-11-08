import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

final TenantList _inUse = (
  portfolioId: gulberg.id,
  archived: false,
  search: '',
);

void main() {
  test('lists, searches and pages tenants', () async {
    final app = TestApp()..tenants.pageLimit = 1;
    final container = containerFor(app);
    listen(container, tenantsProvider(_inUse));
    await pumpEventQueue();
    expect(container.read(tenantsProvider(_inUse)).value!.value.items, [
      aliRaza,
    ]);
    await container.read(tenantsProvider(_inUse).notifier).loadMore();
    expect(container.read(tenantsProvider(_inUse)).value!.value.items, [
      aliRaza,
      techCorp,
    ]);
    await container.read(tenantsProvider(_inUse).notifier).loadMore();
    final searched = (
      portfolioId: gulberg.id,
      archived: false,
      search: 'indus',
    );
    listen(container, tenantsProvider(searched));
    await pumpEventQueue();
    expect(container.read(tenantsProvider(searched)).value!.value.items, [
      techCorp,
    ]);
  });

  test('finds matches and adds a tenant', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, tenantsProvider(_inUse));
    await pumpEventQueue();
    final controller = container.read(tenantsProvider(_inUse).notifier);
    expect(await controller.matches(phone: aliRaza.phone), [
      (id: aliRaza.id, fullName: 'Ali Raza'),
    ]);
    expect(
      await controller.matches(phone: aliRaza.phone, exceptId: aliRaza.id),
      isEmpty,
    );
    final created = await controller.create(
      const Tenant(id: 'new', fullName: 'Nadia Khan'),
    );
    expect(created.fullName, 'Nadia Khan');
    await pumpEventQueue();
    expect(
      container.read(tenantsProvider(_inUse)).value!.value.items.last.fullName,
      'Nadia Khan',
    );
  });

  test('a tenant is edited, archived and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = tenantProvider(aliRaza.id);
    listen(container, provider);
    await pumpEventQueue();
    final controller = container.read(provider.notifier);
    final saved = await controller.save(
      Tenant.fromRow({...aliRaza.toRow(), 'occupation': 'Banker'}),
    );
    expect(saved.occupation, 'Banker');
    expect(container.read(provider).value!.value.occupation, 'Banker');
    expect((await controller.archive(archived: true)).archived, isTrue);
    expect((await controller.archive(archived: false)).archived, isFalse);
    app.tenants.gate.failure = const RejectedFailure('still_in_use');
    await expectLater(controller.delete(), throwsA(isA<RejectedFailure>()));
    app.tenants.gate.failure = null;
    await controller.delete();
    expect(app.tenants.calls.last.$1, 'deleteTenant');
  });
}
