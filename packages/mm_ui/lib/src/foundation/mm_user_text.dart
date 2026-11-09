import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// Text the landlord wrote (a name, an address, a property's name), set in
/// its own script's face and running in its own direction.
///
/// In the Urdu UI a name typed in English is set in the Latin face, and the
/// Latin letters and figures inside Urdu text ("مکان 12، Gulberg III") are
/// too ([MmScriptText]); in the English UI text typed in Urdu falls back to
/// Nastaliq. The text is also kept apart in its own
/// direction when that differs from the UI's (`MmSemantics.isolated`), so
/// an Urdu address in the English UI keeps its word order when it wraps,
/// and a sentence typed in English keeps its full stop at its end in the
/// Urdu UI. Screen readers get the text as written.
///
/// Internal to mm_ui: any component family may use it.
class MmUserText extends StatelessWidget {
  /// Shows [text] in [style].
  const new(
    this.text, {
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  /// The text as the landlord wrote it.
  final String text;

  /// The style for text in the UI's script.
  final TextStyle style;

  /// How the lines of [text] are aligned.
  final TextAlign? textAlign;

  /// The most lines the text takes, or null for as many as it needs.
  final int? maxLines;

  /// How text cut off at [maxLines] ends.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final shown = MmSemantics.isolated(text, Directionality.of(context));
    return MmScriptText(
      shown,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: shown == text ? null : text,
    );
  }
}
