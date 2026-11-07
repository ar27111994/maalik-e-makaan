import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// Text the landlord wrote (a name, an address, a property's name), set in
/// its own script's face and running in its own direction.
///
/// In the Urdu UI a name typed in English is set in the Latin face, and in
/// the English UI one typed in Urdu falls back to Nastaliq
/// (`MmSemantics.styleFor`). The text is also kept apart in its own
/// direction when that differs from the UI's (`MmSemantics.isolated`), so
/// an Urdu address in the English UI keeps its word order when it wraps,
/// and a sentence typed in English keeps its full stop at its end in the
/// Urdu UI. Screen readers get the text as written.
///
/// Internal to the display family.
class MmUserText extends StatelessWidget {
  /// Shows [text] in [style].
  const new(
    this.text, {
    required this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  /// The text as the landlord wrote it.
  final String text;

  /// The style for text in the UI's script.
  final TextStyle style;

  /// The most lines the text takes, or null for as many as it needs.
  final int? maxLines;

  /// How text cut off at [maxLines] ends.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final shown = MmSemantics.isolated(text, Directionality.of(context));
    return Text(
      shown,
      style: context.mm.styleFor(text, style),
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: shown == text ? null : text,
    );
  }
}
