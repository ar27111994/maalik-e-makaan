@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void main() {
  goldenEveryVariant(
    'mm_cnic_text',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            tr('Ali Raza', 'علی رضا'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          MmCnicText(cnic: Cnic.parse('35202-1234567-1')),
          MmCnicText(
            cnic: Cnic.parse('35202-1234567-1'),
            initiallyMasked: false,
          ),
          Text(
            tr('Ayesha Khan', 'عائشہ خان'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          MmCnicText(
            cnic: Cnic.parse('42101-7654321-2'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );
}
