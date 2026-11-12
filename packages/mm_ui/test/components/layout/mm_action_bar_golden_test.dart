@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Two short actions side by side, two long ones stacked with the primary
/// at the bottom, and a single disabled primary filling the width.
void main() {
  goldenEveryVariant(
    'mm_action_bar',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: MmSpace.s4,
        children: [
          MmActionBar(
            secondary: OutlinedButton(
              onPressed: tapped,
              child: Text(say('Cancel', 'رہنے دیں')),
            ),
            primary: FilledButton(
              onPressed: tapped,
              child: Text(say('Save', 'محفوظ کریں')),
            ),
          ),
          MmActionBar(
            secondary: OutlinedButton(
              onPressed: tapped,
              child: Text(say('Share on WhatsApp', 'واٹس ایپ پر بھیجیں')),
            ),
            primary: FilledButton(
              onPressed: tapped,
              child: Text(say('Record payment', 'ادائیگی درج کریں')),
            ),
          ),
          MmActionBar(
            primary: FilledButton(
              onPressed: null,
              child: Text(say('Record payment', 'ادائیگی درج کریں')),
            ),
          ),
        ],
      ),
    ),
  );
}
