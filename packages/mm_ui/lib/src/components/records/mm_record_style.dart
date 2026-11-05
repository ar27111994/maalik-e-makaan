import 'package:flutter/painting.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The style of a record's small print (a receipt's footer, a gauge's
/// caption): [caption] in muted ink, set a step heavier than body text so
/// it survives sunlight on a phone and a cheap printer on paper.
///
/// Internal to the records family.
TextStyle mmSmallPrint(TextStyle caption, MmColorTokens colors) =>
    caption.copyWith(color: colors.inkMuted, fontWeight: FontWeight.w500);
