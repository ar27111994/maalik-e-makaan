import 'package:flutter/widgets.dart';

/// Picks the English or the Urdu words for the ambient language, as the
/// app's own localisations would.
typedef Say = String Function(String english, String urdu);

/// The [Say] of [context]'s language.
Say sayIn(BuildContext context) {
  final urdu = Localizations.localeOf(context).languageCode == 'ur';
  return (english, inUrdu) => urdu ? inUrdu : english;
}

/// A golden composition [width] wide (a phone's content column by default)
/// whose [builder] gets a [Say] for the ambient language, so the Urdu
/// golden shows Urdu words.
///
/// The harness paints the page colour behind every subject and places it
/// on whole pixels, so the page needs neither.
class GoldenPage extends StatelessWidget {
  /// Lays [builder]'s composition out on the page.
  const new(
    this.builder, {
    this.width = 328,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The composition's width.
  final double width;

  /// Space around the composition, for text that starts at the edge:
  /// Urdu marks overhang their line, which the page's gutter absorbs
  /// in the app but the golden's boundary would cut.
  final EdgeInsetsGeometry padding;

  /// Builds the composition.
  final Widget Function(BuildContext context, Say say) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: padding,
      child: Builder(builder: (context) => builder(context, sayIn(context))),
    ),
  );
}
