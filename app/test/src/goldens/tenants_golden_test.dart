@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_form_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenants_screen.dart';

import '../../support/harness.dart';

void main() {
  screenGoldenEveryVariant(
    'tenants',
    TenantsScreen.new,
    sizes: {MmVariant.largeText: const Size(360, 1400)},
  );

  screenGoldenEveryVariant(
    'tenant_detail',
    () => TenantDetailScreen(tenantId: aliRaza.id),
    size: const Size(360, 2300),
    sizes: {
      MmVariant.largeText: const Size(360, 5200),
      MmVariant.urdu: const Size(360, 2900),
    },
  );

  screenGoldenEveryVariant(
    'tenant_form',
    () => TenantFormScreen(tenantId: aliRaza.id),
    size: const Size(360, 4600),
    sizes: {
      MmVariant.largeText: const Size(360, 9800),
      MmVariant.urdu: const Size(360, 5800),
    },
  );
}
