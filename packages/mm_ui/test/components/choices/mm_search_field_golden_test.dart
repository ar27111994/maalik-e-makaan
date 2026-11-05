@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void main() {
  goldenEveryVariant(
    'mm_search_field',
    () => Localised(
      (context, tr) => GoldenColumn(
        children: [
          const MmSearchField(),
          MmSearchField(hint: tr('Search tenants', 'کرایہ دار تلاش کریں')),
          MmSearchField(
            controller: TextEditingController(text: tr('Ali Raza', 'علی رضا')),
          ),
          MmSearchField(controller: TextEditingController(text: 'Gulberg')),
        ],
      ),
    ),
  );
}
