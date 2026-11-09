@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Extended (with keyboard focus), compact, a wrapped label, and disabled.
Widget _fabs() => GoldenPage(
  (context, say) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    spacing: MmSpace.s4,
    children: [
      MmFab(
        label: say('Add tenant', 'کرایہ دار شامل کریں'),
        icon: MmIcons.invite,
        heroTag: 'add tenant',
        onPressed: tapped,
      ),
      MmFab(
        label: say('Add property', 'جائیداد شامل کریں'),
        icon: MmIcons.add,
        extended: false,
        heroTag: 'add property',
        onPressed: tapped,
      ),
      MmFab(
        label: say(
          'Record payment for the Gulberg, Lahore flat',
          'گلبرگ، لاہور والے فلیٹ کی ادائیگی درج کریں',
        ),
        icon: MmIcons.payment,
        heroTag: 'record payment',
        onPressed: tapped,
      ),
      MmFab(
        label: say('Add tenant', 'کرایہ دار شامل کریں'),
        icon: MmIcons.invite,
        heroTag: null,
        onPressed: null,
      ),
    ],
  ),
);

void main() {
  focusedGoldenEveryVariant(
    'mm_fab',
    _fabs,
    focused: textIn('Add tenant', 'کرایہ دار شامل کریں'),
  );
}
