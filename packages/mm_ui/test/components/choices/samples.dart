import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

/// Picks the English or the Urdu sample text, as the app's localisations
/// would.
typedef Translate = String Function(String english, String urdu);

/// Builds with [builder], handing it a [Translate] for the ambient language.
class Localised extends StatelessWidget {
  const new(this.builder, {super.key});

  final Widget Function(BuildContext context, Translate tr) builder;

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    return builder(context, (english, inUrdu) => urdu ? inUrdu : english);
  }
}

/// Lays golden states out one under another at the width a phone gives a
/// form, on the page colour (so dark variants are legible in the image).
///
/// Its height is rounded up to an even number of pixels, so the harness
/// centres it on whole pixels: text drawn across a half pixel is blurred,
/// and the thin strokes of Nastaliq then fool the contrast check.
class GoldenColumn extends StatelessWidget {
  const new({required this.children, this.gap = MmSpace.s4, super.key});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return _EvenHeight(
      child: ColoredBox(
        color: context.mm.colors.bg,
        child: SizedBox(
          width: 328,
          child: Padding(
            padding: const EdgeInsets.all(MmSpace.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sizes [child] at its own size with the height rounded up to an even
/// number of pixels, and stretches it to fill that height.
class _EvenHeight extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEvenHeight();
}

class _RenderEvenHeight extends RenderProxyBox {
  @override
  void performLayout() {
    final child = this.child!
      ..layout(constraints.loosen(), parentUsesSize: true);
    final height = (child.size.height / 2).ceilToDouble() * 2;
    child.layout(
      BoxConstraints.tightFor(width: child.size.width, height: height),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
  }
}

/// Pumps [child] at 200% text on a 320 dp wide phone (or [width]), in
/// English and in Urdu, and fails on any overflow or other layout error.
Future<void> expectFitsNarrowLargeText(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double height = 740,
}) async {
  for (final locale in const [Locale('en'), Locale('ur')]) {
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MmTheme.data(
          brightness: Brightness.light,
          script: MmScript.of(locale),
        ),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          MmLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: app!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(MmSpace.s4),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: locale.languageCode);
  }
}
