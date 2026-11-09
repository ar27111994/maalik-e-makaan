@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/properties_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_form_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/unit_screens.dart';

import '../../support/harness.dart';

void main() {
  screenGoldenEveryVariant(
    'properties',
    PropertiesScreen.new,
    app: () =>
        TestApp()..properties.byPortfolio[gulberg.id]!.insert(1, saddarPlaza),
    sizes: {MmVariant.largeText: const Size(360, 1300)},
  );

  screenGoldenEveryVariant(
    'property_detail',
    () => PropertyDetailScreen(propertyId: gulbergHouse.id),
    size: const Size(360, 2100),
    sizes: {
      MmVariant.largeText: const Size(360, 4600),
      MmVariant.urdu: const Size(360, 2700),
    },
  );

  screenGoldenEveryVariant(
    'property_form',
    () => PropertyFormScreen(propertyId: gulbergHouse.id),
    size: const Size(360, 2900),
    sizes: {
      MmVariant.largeText: const Size(360, 6000),
      MmVariant.urdu: const Size(360, 3700),
    },
  );

  screenGoldenEveryVariant(
    'unit_detail',
    () => UnitDetailScreen(propertyId: gulbergHouse.id, unitId: firstFloor.id),
    size: const Size(360, 1100),
    sizes: {MmVariant.largeText: const Size(360, 2300)},
  );

  screenGoldenEveryVariant(
    'unit_form',
    () => UnitFormScreen(propertyId: gulbergHouse.id, unitId: groundFloor.id),
    size: const Size(360, 1800),
    sizes: {
      MmVariant.largeText: const Size(360, 3700),
      MmVariant.urdu: const Size(360, 2200),
    },
  );
}
