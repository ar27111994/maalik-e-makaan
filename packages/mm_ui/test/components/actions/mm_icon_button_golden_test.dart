@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// One row per variant: an action, a toggle off, the toggle on, disabled.
class _IconButtons extends StatelessWidget {
  const new();

  static void _pressed() {}

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    final edit = urdu ? 'کرایہ دار میں ترمیم کریں' : 'Edit tenant';
    final reminders = urdu ? 'کرایے کی یاد دہانیاں' : 'Rent reminders';
    final back = urdu ? 'واپس' : 'Back';
    // The page colour behind the composition: the golden captures only the
    // subject, so dark modes would otherwise show on transparency.
    return ColoredBox(
      color: context.mm.colors.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: MmSpace.s2,
        children: [
          for (final variant in MmIconButtonVariant.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: MmSpace.s4,
              children: [
                MmIconButton(
                  icon: MmIcons.edit,
                  tooltip: edit,
                  variant: variant,
                  onPressed: _pressed,
                ),
                MmIconButton(
                  icon: MmIcons.notificationsOff,
                  selectedIcon: MmIcons.notifications,
                  tooltip: reminders,
                  variant: variant,
                  selected: false,
                  onPressed: _pressed,
                ),
                MmIconButton(
                  icon: MmIcons.notificationsOff,
                  selectedIcon: MmIcons.notifications,
                  tooltip: reminders,
                  variant: variant,
                  selected: true,
                  onPressed: _pressed,
                ),
                MmIconButton(
                  icon: MmIcons.back,
                  tooltip: back,
                  variant: variant,
                  onPressed: null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void main() {
  goldenEveryVariant('mm_icon_button', () => const _IconButtons());
}
