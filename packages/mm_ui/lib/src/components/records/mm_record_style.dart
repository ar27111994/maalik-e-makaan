import 'package:flutter/painting.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Measures shared by the record components.
///
/// Internal to the records family.
abstract final class MmRecordMetrics {
  /// The stroke of a frame that marks a record: the nameplate's brass
  /// plate, the receipt's brass seal and its void stamp. Heavier than a
  /// hairline so it reads as a frame, not a divider.
  static const double frame = 2;
}

/// The style of a record's small print (a receipt's footer, a gauge's
/// caption): [caption] in muted ink, set a step heavier than body text so
/// it survives sunlight on a phone and a cheap printer on paper.
TextStyle mmSmallPrint(TextStyle caption, MmColorTokens colors) =>
    caption.copyWith(color: colors.inkMuted, fontWeight: FontWeight.w500);

/// Styles for words in the record components that may be the landlord's
/// own data (a name, an address, a receipt number).
///
/// Internal to the records family.
extension MmRecordText on MmSemantics {
  /// [style] for showing [text], in either UI language.
  ///
  /// In the Urdu UI it is [MmSemantics.styleFor]: text without Arabic-script
  /// letters (a name typed in English, a receipt number) is set in the Latin
  /// face. In the English UI, text with Arabic-script letters (a name typed
  /// in Urdu) falls back to Nastaliq for those letters, which the Latin face
  /// does not have. Latin letters and digits stay in the Latin face either
  /// way.
  TextStyle dataStyleFor(String text, TextStyle style) {
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
