@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

enum _Status { overdue, dueSoon, paid }

enum _City { lahore, karachi, islamabad }

void _changed(Object? _) {}

void main() {
  tearDown(resetFocusHighlights);
  goldenEveryVariant(
    'mm_filter_chips',
    () => GoldenPage((context, tr) {
      final statuses = [
        MmFilterOption(
          value: _Status.overdue,
          label: tr('Overdue', 'لیٹ'),
          count: 3,
        ),
        MmFilterOption(
          value: _Status.dueSoon,
          label: tr('Due soon', 'تاریخ قریب'),
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          // Keyboard focus on a selected chip: its ring goes outside it.
          KeyboardFocused(
            child: MmFilterChips<_Status>(
              options: statuses,
              selected: const {_Status.overdue, _Status.dueSoon},
              onChanged: _changed,
            ),
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

  // On a phone the row runs to the screen's edges, the first chip lined up
  // with the page's content.
  screenGoldenEveryVariant(
    'mm_filter_chips_edge',
    () => Scaffold(
      body: Builder(
        builder: (context) {
          final tr = sayIn(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MmSpace.s2,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MmSpace.s4,
                  MmSpace.s4,
                  MmSpace.s4,
                  0,
                ),
                child: Text(
                  tr('Tenants', 'کرایہ دار'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MmFilterChips<_Status>(
                options: [
                  MmFilterOption(
                    value: _Status.overdue,
                    label: tr('Overdue', 'لیٹ'),
                    count: 3,
                  ),
                  MmFilterOption(
                    value: _Status.dueSoon,
                    label: tr('Due soon', 'تاریخ قریب'),
                    count: 5,
                  ),
                  MmFilterOption(
                    value: _Status.paid,
                    label: tr('Paid', 'ادا شدہ'),
                    count: 12,
                  ),
                ],
                selected: const {_Status.overdue},
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MmSpace.s4,
                ),
                onChanged: _changed,
              ),
            ],
          );
        },
      ),
    ),
    size: const Size(360, 160),
    sizes: {MmVariant.largeText: const Size(360, 240)},
  );
}
