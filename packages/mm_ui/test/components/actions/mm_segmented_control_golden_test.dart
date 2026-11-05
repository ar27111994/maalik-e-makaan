@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

enum _Period { month, quarter, year }

enum _Method { cash, bank, card }

enum _Filter { all, paid, overdue }

/// Text segments, segments with icons, and a disabled control.
class _Controls extends StatelessWidget {
  const new();

  static void _changed(Object? _) {}

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
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MmSpace.s4,
          children: [
            MmSegmentedControl<_Period>(
              segments: [
                MmSegment(
                  value: _Period.month,
                  label: say('Monthly', 'ماہانہ'),
                ),
                MmSegment(
                  value: _Period.quarter,
                  label: say('Quarterly', 'سہ ماہی'),
                ),
                MmSegment(value: _Period.year, label: say('Yearly', 'سالانہ')),
              ],
              selected: _Period.month,
              onChanged: _changed,
            ),
            MmSegmentedControl<_Method>(
              segments: [
                MmSegment(
                  value: _Method.cash,
                  label: say('Cash', 'نقد'),
                  icon: MmIcons.cash,
                ),
                MmSegment(
                  value: _Method.bank,
                  label: say('Bank', 'بینک'),
                  icon: MmIcons.bank,
                ),
                MmSegment(
                  value: _Method.card,
                  label: say('Card', 'کارڈ'),
                  icon: MmIcons.card,
                ),
              ],
              selected: _Method.bank,
              onChanged: _changed,
            ),
            MmSegmentedControl<_Filter>(
              segments: [
                MmSegment(value: _Filter.all, label: say('All', 'سب')),
                MmSegment(value: _Filter.paid, label: say('Paid', 'ادا شدہ')),
                MmSegment(
                  value: _Filter.overdue,
                  label: say('Overdue', 'واجب الادا'),
                ),
              ],
              selected: _Filter.overdue,
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  goldenEveryVariant('mm_segmented_control', () => const _Controls());
}
