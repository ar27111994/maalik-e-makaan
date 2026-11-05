import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

/// Picks the English or the Urdu words for the ambient language.
typedef Say = String Function(String english, String urdu);

/// A golden composition on the page colour (goldens capture only the
/// subject, so dark modes would otherwise show on transparency), as wide as
/// a phone's content column. [builder] gets a [Say] that picks the words of
/// the ambient language, as the app's localisations would.
class GoldenPage extends StatelessWidget {
  /// Lays [builder]'s composition out on the page.
  const new(this.builder, {super.key});

  /// Builds the composition.
  final Widget Function(BuildContext context, Say say) builder;

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    return ColoredBox(
      color: context.mm.colors.bg,
      child: SizedBox(
        width: 328,
        child: Builder(builder: (context) => builder(context, say)),
      ),
    );
  }
}

/// A callback for components that should look enabled.
void tapped() {}
