@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// The filled action button, which has keyboard focus.
const Key _focused = ValueKey('focused');

/// One row per variant: an action, a toggle off, the toggle on, a disabled
/// action (a disabled toggle that is off looks the same) and a disabled
/// toggle that is on. The filled action has keyboard focus.
Widget _iconButtons() => GoldenPage((context, say) {
  final edit = say('Edit tenant', 'کرایہ دار میں ترمیم کریں');
  final reminders = say('Rent reminders', 'کرایے کی یاد دہانیاں');
  final back = say('Back', 'واپس');
  return Column(
    mainAxisSize: MainAxisSize.min,
    spacing: MmSpace.s2,
    children: [
      for (final variant in MmIconButtonVariant.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: MmSpace.s4,
          children: [
            MmIconButton(
              key: variant == MmIconButtonVariant.filled ? _focused : null,
              icon: MmIcons.edit,
              tooltip: edit,
              variant: variant,
              onPressed: tapped,
            ),
            for (final on in [false, true])
              MmIconButton(
                icon: MmIcons.notificationsOff,
                selectedIcon: MmIcons.notifications,
                tooltip: reminders,
                variant: variant,
                selected: on,
                onPressed: tapped,
              ),
            MmIconButton(
              icon: MmIcons.back,
              tooltip: back,
              variant: variant,
              onPressed: null,
            ),
            MmIconButton(
              icon: MmIcons.notificationsOff,
              selectedIcon: MmIcons.notifications,
              tooltip: reminders,
              variant: variant,
              selected: true,
              onPressed: null,
            ),
          ],
        ),
    ],
  );
});

void main() {
  focusedGoldenEveryVariant(
    'mm_icon_button',
    _iconButtons,
    focused: find.descendant(
      of: find.byKey(_focused),
      matching: find.byType(Icon),
    ),
  );
}
