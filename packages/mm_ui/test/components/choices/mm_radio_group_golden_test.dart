@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

enum _Method { cash, bank, card }

enum _Payer { tenant, landlord }

void _changed(Object? _) {}

void main() {
  goldenEveryVariant(
    'mm_radio_group',
    () => Localised(
      (context, tr) => GoldenColumn(
        children: [
          MmRadioGroup<_Method>(
            label: tr('Received by', 'وصولی کا طریقہ'),
            options: [
              MmOption(
                value: _Method.cash,
                label: tr('Cash', 'نقد'),
                icon: MmIcons.cash,
              ),
              MmOption(
                value: _Method.bank,
                label: tr('Bank transfer', 'بینک ٹرانسفر'),
                description: tr('Meezan Bank, Gulberg', 'میزان بینک، گلبرگ'),
                icon: MmIcons.bank,
              ),
              MmOption(
                value: _Method.card,
                label: tr('Card', 'کارڈ'),
                icon: MmIcons.card,
              ),
            ],
            value: _Method.bank,
            onChanged: _changed,
          ),
          MmRadioGroup<_Payer>(
            label: tr('Electricity bill paid by', 'بجلی کا بل کون دے گا'),
            options: [
              MmOption(value: _Payer.tenant, label: tr('Tenant', 'کرایہ دار')),
              MmOption(value: _Payer.landlord, label: tr('Landlord', 'مالک')),
            ],
            value: _Payer.tenant,
            onChanged: null,
          ),
        ],
      ),
    ),
  );
}
