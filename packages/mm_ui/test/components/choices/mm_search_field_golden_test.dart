@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void main() {
  goldenEveryVariant(
    'mm_search_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
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
