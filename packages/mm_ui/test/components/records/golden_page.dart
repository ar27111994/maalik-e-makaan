import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/mm_ui.dart';

/// Picks the English or the Urdu words for the ambient language.
typedef Say = String Function(String english, String urdu);

/// A golden composition on the page colour (goldens capture only the
/// subject, so dark modes would otherwise show on transparency), as wide as
/// a phone's content column. [builder] gets a [Say] that picks the words of
/// the ambient language, as the app's localisations would.
///
/// The page's height is rounded up to an even number of pixels, so the
/// harness centres it on whole pixels: text on a half pixel is drawn with
/// uniform anti-aliased edges that the text contrast guideline can mistake
/// for the text's colour.
class GoldenPage extends StatelessWidget {
  /// Lays [builder]'s composition out on the page.
  const new(this.builder, {super.key});

  /// Builds the composition.
  final Widget Function(BuildContext context, Say say) builder;

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    return _EvenHeight(
      child: ColoredBox(
        color: context.mm.colors.bg,
        child: SizedBox(
          width: 328,
          child: Builder(builder: (context) => builder(context, say)),
        ),
      ),
    );
  }
}

/// Sizes its child to its natural size with the height rounded up to an
/// even number of pixels, stretching the child to fill it.
class _EvenHeight extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEvenHeight();
}

class _RenderEvenHeight extends RenderProxyBox {
  @override
  void performLayout() {
    final child = this.child!;
    final natural = child.getDryLayout(constraints.loosen());
    final height = (natural.height / 2).ceil() * 2.0;
    child.layout(
      BoxConstraints.tightFor(width: natural.width, height: height),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
  }
}
