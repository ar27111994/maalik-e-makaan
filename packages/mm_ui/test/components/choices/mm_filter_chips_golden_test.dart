@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

enum _Status { overdue, dueSoon, paid }

enum _City { lahore, karachi, islamabad }

void _changed(Object? _) {}

void main() {
  goldenEveryVariant(
    'mm_filter_chips',
    () => Localised((context, tr) {
      final statuses = [
        MmFilterOption(
          value: _Status.overdue,
          label: tr('Overdue', 'واجب الادا'),
          count: 3,
        ),
        MmFilterOption(
          value: _Status.dueSoon,
          label: tr('Due soon', 'جلد واجب'),
          count: 5,
        ),
        MmFilterOption(
          value: _Status.paid,
          label: tr('Paid', 'ادا شدہ'),
          count: 12,
        ),
      ];
      final cities = [
        MmFilterOption(value: _City.lahore, label: tr('Lahore', 'لاہور')),
        MmFilterOption(value: _City.karachi, label: tr('Karachi', 'کراچی')),
        MmFilterOption(
          value: _City.islamabad,
          label: tr('Islamabad', 'اسلام آباد'),
        ),
      ];
      return GoldenColumn(
        children: [
          MmFilterChips<_Status>(
            options: statuses,
            selected: const {_Status.overdue, _Status.dueSoon},
            onChanged: _changed,
          ),
          MmFilterChips<_City>(
            options: cities,
            selected: const {_City.lahore},
            multiSelect: false,
            onChanged: _changed,
          ),
          MmFilterChips<_Status>(
            options: statuses,
            selected: const {_Status.paid},
            onChanged: null,
          ),
        ],
      );
    }),
  );
}
