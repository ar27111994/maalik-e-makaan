import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

final PropertyList _inUse = (portfolioId: gulberg.id, archived: false);

Future<T> _settled<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<Snapshot<T>>> provider,
) async {
  listen(container, provider);
  await pumpEventQueue();
  return container.read(provider).value!.value;
}

void main() {
  test('a list shows properties in use or archived, page by page', () async {
    final app = TestApp()..properties.pageLimit = 1;
    app.properties.byPortfolio[gulberg.id]!.add(saddarPlaza);
    final container = containerFor(app);
    var page = await _settled(container, propertiesProvider(_inUse));
    expect(page.items, [gulbergHouse]);
    expect(page.hasMore, isTrue);
    await container.read(propertiesProvider(_inUse).notifier).loadMore();
    page = container.read(propertiesProvider(_inUse)).value!.value;
    expect(page.items, [gulbergHouse, saddarPlaza]);
    expect(page.hasMore, isFalse);
    // Nothing more to read: no request.
    final calls = app.properties.calls.length;
    await container.read(propertiesProvider(_inUse).notifier).loadMore();
    expect(app.properties.calls, hasLength(calls));
    final archived = await _settled(
      container,
      propertiesProvider((portfolioId: gulberg.id, archived: true)),
    );
    expect(archived.items, [oldPlot]);
    // The list is saved for next time, apart from the archived one.
    final saved = await app.cache.read(
      testUserId,
      'properties.${gulberg.id}.active',
      (json) => json,
    );
    expect(saved, isNotNull);
  });

  test('adding a property refreshes the lists', () async {
    final app = TestApp();
    final container = containerFor(app);
    await _settled(container, propertiesProvider(_inUse));
    final created = await container
        .read(propertiesProvider(_inUse).notifier)
        .create(
          const Property(
            id: 'new-id',
            name: 'Model Town flat',
            type: PropertyType.apartment,
            city: 'Lahore',
            province: Province.punjab,
          ),
        );
    expect(created.id, 'new-id');
    await pumpEventQueue();
    expect(
      container.read(propertiesProvider(_inUse)).value!.value.items.last.name,
      'Model Town flat',
    );
  });

  test('a property is edited, archived, restored and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = propertyProvider(gulbergHouse.id);
    expect(await _settled(container, provider), gulbergHouse);
    await _settled(container, propertiesProvider(_inUse));
    final controller = container.read(provider.notifier);
    final saved = await controller.save(
      Property.fromRow({...gulbergHouse.toRow(), 'name': 'Gulberg Home'}),
    );
    expect(saved.name, 'Gulberg Home');
    expect(container.read(provider).value!.value.name, 'Gulberg Home');
    expect(container.read(provider).value!.source, SnapshotSource.network);
    expect((await controller.archive(archived: true)).archived, isTrue);
    await pumpEventQueue();
    expect(
      container.read(propertiesProvider(_inUse)).value!.value.items,
      isEmpty,
    );
    expect((await controller.archive(archived: false)).archived, isFalse);
    await controller.delete();
    expect(app.properties.calls.last.$1, 'deleteProperty');
  });

  test('a refused command throws and changes nothing', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = propertyProvider(gulbergHouse.id);
    await _settled(container, provider);
    app.properties.gate.failure = const RejectedFailure('still_in_use');
    await expectLater(
      container.read(provider.notifier).delete(),
      throwsA(isA<RejectedFailure>()),
    );
    expect(container.read(provider).value!.value, gulbergHouse);
  });

  test('units are listed with occupancy, added, edited and removed', () async {
    final app = TestApp()..properties.pageLimit = 2;
    final container = containerFor(app);
    final units = unitsProvider(gulbergHouse.id);
    var page = await _settled(container, units);
    expect([for (final s in page.items) s.unit], [groundFloor, firstFloor]);
    await container.read(units.notifier).loadMore();
    page = container.read(units).value!.value;
    expect(page.items.last.unit, annexe);
    await container.read(units.notifier).loadMore();
    final created = await container
        .read(units.notifier)
        .create(
          gulberg.id,
          Unit(
            id: 'u-new',
            propertyId: gulbergHouse.id,
            label: 'Roof room',
            type: UnitType.room,
          ),
        );
    expect(created.label, 'Roof room');
    final unit = unitProvider(groundFloor.id);
    expect(
      (await _settled(container, unit)).occupancy!.status,
      OccupancyStatus.occupied,
    );
    final saved = await container
        .read(unit.notifier)
        .save(
          Unit.fromRow({...groundFloor.toRow(), 'label': 'Ground portion'}),
        );
    expect(saved.label, 'Ground portion');
    expect(container.read(unit).value!.value.unit.label, 'Ground portion');
    expect(
      (await container.read(unit.notifier).archive(archived: true)).archived,
      isTrue,
    );
    await container.read(unit.notifier).delete(gulbergHouse.id);
    expect(
      app.properties.unitList.map((u) => u.id),
      isNot(contains(groundFloor.id)),
    );
  });
}
