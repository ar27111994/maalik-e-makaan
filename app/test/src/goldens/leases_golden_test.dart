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
      // "End tenancy" in either language: the button with its icon (the
      // "Delete" under it is outlined red too).
      final button = find.ancestor(
        of: find.byIcon(MmIcons.signOut),
        matching: find.byType(MmButton),
      );
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
