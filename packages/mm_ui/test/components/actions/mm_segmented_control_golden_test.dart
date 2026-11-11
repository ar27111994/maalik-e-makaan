@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

enum _Period { month, quarter, year }

enum _Method { cash, bank, card }

enum _Filter { all, paid, overdue }

void _changed(Object? _) {}

/// Text segments (keyboard focus on an unselected one), segments with
/// icons, and a disabled control. At 200% text they stack.
Widget _controls() => GoldenPage(
  (context, say) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: MmSpace.s4,
    children: [
      MmSegmentedControl<_Period>(
        segments: [
          MmSegment(value: _Period.month, label: say('Monthly', 'ماہانہ')),
          MmSegment(value: _Period.quarter, label: say('Quarterly', 'سہ ماہی')),
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
        expand: true,
        onChanged: _changed,
      ),
      MmSegmentedControl<_Filter>(
        segments: [
          MmSegment(value: _Filter.all, label: say('All', 'سب')),
          MmSegment(value: _Filter.paid, label: say('Paid', 'ادا شدہ')),
          MmSegment(value: _Filter.overdue, label: say('Overdue', 'لیٹ')),
        ],
        selected: _Filter.overdue,
        onChanged: null,
      ),
    ],
  ),
);

void main() {
  focusedGoldenEveryVariant(
    'mm_segmented_control',
    _controls,
    focused: textIn('Quarterly', 'سہ ماہی'),
  );
}
