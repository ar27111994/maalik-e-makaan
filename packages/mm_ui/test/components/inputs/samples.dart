import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

/// Whether the ambient language of [context] is Urdu.
bool isUrdu(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ur';

/// Lays golden states out one under another, [gap] apart, at the width a
/// phone gives a form, on the page colour (so dark variants are legible in
/// the image).
class GoldenColumn extends StatelessWidget {
  const new({required this.children, this.gap = 16, super.key});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: 328,
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) SizedBox(height: gap),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks the English or the Urdu sample text, as the app's localisations
/// would.
typedef Translate = String Function(String english, String urdu);

/// Builds with [builder], handing it a [Translate] for the ambient language.
class Localised extends StatelessWidget {
  const new(this.builder, {super.key});

  final Widget Function(BuildContext context, Translate tr) builder;

  @override
  Widget build(BuildContext context) {
    final urdu = isUrdu(context);
    return builder(context, (english, inUrdu) => urdu ? inUrdu : english);
  }
}
