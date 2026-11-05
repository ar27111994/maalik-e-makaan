@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A field labelled above, as the inputs family draws them.
Widget _field(BuildContext context, String label, String value) {
  final text = Theme.of(context).textTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MmSpace.s1,
    children: [
      ExcludeSemantics(child: Text(label, style: text.labelLarge)),
      TextFormField(
        initialValue: value,
        style: context.mm.styleFor(value, text.bodyLarge!),
        decoration: InputDecoration(labelText: label),
      ),
    ],
  );
}

/// A section with a description and two fields, and one without a
/// description, 32 dp apart.
void main() {
  goldenEveryVariant(
    'mm_form_section',
    () => GoldenPage(
      padding: const EdgeInsets.symmetric(horizontal: MmSpace.s2),
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s8,
        children: [
          MmFormSection(
            title: say('Tenant details', 'کرایہ دار کی تفصیلات'),
            description: say(
              'As written on the CNIC.',
              'جیسا شناختی کارڈ پر لکھا ہے۔',
            ),
            children: [
              _field(context, say('Full name', 'پورا نام'), 'Ayesha Khan'),
              _field(context, say('CNIC', 'شناختی کارڈ'), '35202-1234567-1'),
            ],
          ),
          MmFormSection(
            title: say('Rent', 'کرایہ'),
            children: [
              _field(context, say('Monthly rent', 'ماہانہ کرایہ'), '45,000'),
            ],
          ),
        ],
      ),
    ),
  );
}
