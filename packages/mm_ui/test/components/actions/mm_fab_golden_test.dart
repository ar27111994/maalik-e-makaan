@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Extended, compact, a wrapped label, and disabled.
class _Fabs extends StatelessWidget {
  const new();

  static void _pressed() {}

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    // The page colour behind the composition: the golden captures only the
    // subject, so dark modes would otherwise show on transparency.
    return ColoredBox(
      color: context.mm.colors.bg,
      child: SizedBox(
        width: 328,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: MmSpace.s4,
          children: [
            MmFab(
              label: say('Add tenant', 'کرایہ دار شامل کریں'),
              icon: MmIcons.invite,
              onPressed: _pressed,
            ),
            MmFab(
              label: say('Add property', 'جائیداد شامل کریں'),
              icon: MmIcons.add,
              extended: false,
              onPressed: _pressed,
            ),
            MmFab(
              label: say(
                'Record payment for the Gulberg, Lahore flat',
                'گلبرگ، لاہور والے فلیٹ کی ادائیگی درج کریں',
              ),
              icon: MmIcons.payment,
              onPressed: _pressed,
            ),
            MmFab(
              label: say('Add tenant', 'کرایہ دار شامل کریں'),
              icon: MmIcons.invite,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  goldenEveryVariant('mm_fab', () => const _Fabs());
}
