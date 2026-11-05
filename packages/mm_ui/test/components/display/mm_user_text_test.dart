import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/display/mm_user_text.dart';

import '../../support/harness.dart';

MmSemantics _semantics(MmVariant variant) =>
    variant.theme.extension<MmSemantics>()!;

void main() {
  group('MmUserText.userStyleFor', () {
    const latin = 'Ali Raza';
    const urdu = 'علی رضا';

    test('in the English UI, falls back to Nastaliq for Urdu letters', () {
      final semantics = _semantics(MmVariant.light);
      final style = MmVariant.light.theme.textTheme.bodyLarge!;
      final urduStyle = semantics.userStyleFor(urdu, style);
      expect(urduStyle.fontFamily, style.fontFamily);
      expect(urduStyle.fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
      expect(urduStyle.fontSize, style.fontSize);
      expect(urduStyle.height, style.height);
      expect(semantics.userStyleFor(latin, style), style);
    });

    test('in the Urdu UI, sets Latin data in the Latin face', () {
      final semantics = _semantics(MmVariant.urdu);
      final style = MmVariant.urdu.theme.textTheme.bodyLarge!;
      expect(
        semantics.userStyleFor(latin, style).fontFamily,
        contains(MmFontFamily.latin),
      );
      expect(semantics.userStyleFor(urdu, style), style);
    });
  });
}
