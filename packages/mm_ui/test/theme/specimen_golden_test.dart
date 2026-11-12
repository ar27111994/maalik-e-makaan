@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

/// Latin user data with the glyph pairs a CNIC must keep distinct.
const _cnic = 'CNIC 35202-1234567-1  0O 1lI 5S';

/// A specimen of the type scale, amounts and icons in each variant: the
/// golden shows at a glance that the bundled fonts, the Nastaliq line
/// height and right-to-left mirroring all work.
class _Specimen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mm = context.mm;
    final urdu = mm.script == MmScript.urdu;
    return SizedBox(
      width: 328,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Rs 1,25,000', style: mm.amountLarge),
          Text(urdu ? 'کرائے کی تاریخ' : 'Rent due', style: text.headlineLarge),
          Text(
            urdu ? 'گلبرگ کا مکان' : 'House in Gulberg',
            style: text.titleLarge,
          ),
          Text(
            urdu
                ? 'اکتوبر کا کرایہ ۵ تاریخ کو دینا تھا۔'
                : 'October rent was due on the 5th.',
            style: text.bodyLarge,
          ),
          Text(_cnic, style: mm.styleFor(_cnic, text.bodyMedium!)),
          const SizedBox(height: MmSpace.s2),
          Row(
            children: [
              for (final icon in [
                MmIcons.home,
                MmIcons.receipt,
                MmIcons.back,
                MmIcons.chevronEnd,
                MmIcons.warning,
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: MmSpace.s2),
                  child: Icon(icon, size: MmSize.iconLg, color: mm.colors.ink),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in [
    MmVariant.light,
    MmVariant.urdu,
    MmVariant.darkHighContrast,
  ]) {
    testWidgets('specimen ${variant.name}', (tester) async {
      await pumpThemed(tester, const _Specimen(), variant: variant);
      await expectGolden('specimen', variant);
    });
  }
}
