@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_form_screen.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

void main() {
  screenGoldenEveryVariant(
    'lease_detail',
    () => LeaseDetailScreen(leaseId: aliLease.id),
    size: const Size(360, 3300),
    sizes: {
      MmVariant.largeText: const Size(360, 7200),
      MmVariant.urdu: const Size(360, 4300),
    },
  );

  screenGoldenEveryVariant(
    'lease_end_sheet',
    () => LeaseDetailScreen(leaseId: aliLease.id),
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2400)},
    act: (tester) async {
      final end = find.widgetWithText(MmButton, 'End tenancy');
      final button = end.evaluate().isEmpty
          ? find.byType(OutlinedButton).last
          : end;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'lease_form',
    () => LeaseFormScreen(unitId: firstFloor.id, tenantId: aliRaza.id),
    size: const Size(360, 3900),
    sizes: {
      MmVariant.largeText: const Size(360, 8400),
      MmVariant.urdu: const Size(360, 5000),
    },
  );
}
