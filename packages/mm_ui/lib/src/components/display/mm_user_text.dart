import 'package:flutter/painting.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Styles for the landlord's own words (names, addresses, notes) in the
/// display components.
///
/// Internal to the display family.
extension MmUserText on MmSemantics {
  /// [style] for showing [text] that a user wrote, in either UI language.
  ///
  /// In the Urdu UI it is [MmSemantics.styleFor]: Latin-script data is set
  /// in the Latin face. In the English UI, data with Arabic-script letters
  /// (a name typed in Urdu) falls back to Nastaliq for those letters, which
  /// the Latin face does not have, instead of to whatever the platform
  /// offers. Latin letters and digits stay in the Latin face either way.
  TextStyle userStyleFor(String text, TextStyle style) {
    final styled = styleFor(text, style);
    if (script == MmScript.urdu || !MmSemantics.hasArabicScript(text)) {
      return styled;
    }
    return styled.copyWith(
      fontFamilyFallback: const [MmFontFamily.urdu],
      package: 'mm_ui',
    );
  }
}
