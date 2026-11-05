import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Picks the English or the Urdu words for the ambient language.
typedef Say = String Function(String english, String urdu);

/// A golden composition on the page colour (goldens capture only the
/// subject, so dark modes would otherwise show on transparency), as wide as
/// a phone's content column, with motion reduced so pulsing skeletons hold
/// still. [builder] gets a [Say] that picks the words of the ambient
/// language, as the app's localisations would.
class FeedbackPage extends StatelessWidget {
  /// Lays [builder]'s composition out on the page.
  const new(this.builder, {super.key});

  /// Builds the composition.
  final Widget Function(BuildContext context, Say say) builder;

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
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

/// A callback for components that should look enabled.
void tapped() {}

/// The colour roles of [variant].
MmColorTokens colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

/// Pumps [child] at 200% text on a 320 dp wide phone.
Future<void> pumpLargeNarrow(
  WidgetTester tester,
  Widget child, {
  double height = 740,
}) => pumpThemed(
  tester,
  child,
  variant: MmVariant.largeText,
  size: Size(320, height),
);

/// Draws focus as when driven from a keyboard, for the rest of the test.
void useKeyboardHighlights() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// The style of the paragraph whose text contains [text].
TextStyle styleOf(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(
      find.textContaining(text, findRichText: true).first,
    )
    .text
    .style!;

/// The colour [icon] is painted in.
Color iconColorOf(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find
          .descendant(of: find.byIcon(icon), matching: find.byType(RichText))
          .first,
    )
    .text
    .style!
    .color!;

/// Whether the control around [text] has the primary focus.
bool focusedAt(WidgetTester tester, String text) =>
    Focus.of(tester.element(find.text(text))).hasPrimaryFocus;

/// A host that opens an overlay with [open] once it is first laid out, for
/// tests of snackbars, dialogs and sheets.
class OverlayHost extends StatefulWidget {
  /// Calls [open] after the first frame.
  const new({required this.open, this.child, super.key});

  /// Opens the overlay.
  final void Function(BuildContext context) open;

  /// What the page shows behind the overlay.
  final Widget? child;

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
