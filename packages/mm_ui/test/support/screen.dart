import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'harness.dart';

/// Pumps [child] as the whole screen: the first page of an app themed for
/// [variant] (see [themedApp]), filling a window of [size] at one device
/// pixel per logical pixel, without the padding [pumpThemed] puts around a
/// component. Use it for scaffolds, pages and anything that lays out by the
/// window's size class.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 740),
  MmVariant variant = MmVariant.light,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedApp(child, variant: variant));
  await tester.pumpAndSettle();
}

/// Lays the screen pumped by [pumpScreen] or [pumpOverlay] out again in a
/// window of [size], as when a window is resized or a phone turned.
Future<void> resizeScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// Pumps [behind] as the whole screen (see [pumpScreen]), then calls [open]
/// with a context inside that first page and lets the overlay it opens
/// settle.
///
/// The context is under the root navigator and the app's
/// `ScaffoldMessenger`, so `showDialog`, `showModalBottomSheet` and
/// `ScaffoldMessenger.of(context).showSnackBar` all open as they do in the
/// app. [behind] is a plain page by default; a snack bar needs a [Scaffold]
/// in it to show on.
Future<void> pumpOverlay(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  Widget behind = const Scaffold(),
  Size size = const Size(360, 740),
  MmVariant variant = MmVariant.light,
}) async {
  final page = GlobalKey();
  await pumpScreen(
    tester,
    KeyedSubtree(key: page, child: behind),
    size: size,
    variant: variant,
  );
  open(page.currentContext!);
  await tester.pumpAndSettle();
}

/// Registers, for every variant, a test that pumps [build]'s widget as the
/// whole screen (see [pumpScreen]), checks the accessibility guidelines and
/// compares the screen with the approved golden
/// `goldens/<name>_<variant>.png`.
///
/// With [open], the screen is pumped with [pumpOverlay] and [open] opens an
/// overlay on it first, so the golden shows the dialog, sheet or snack bar
/// over its page, scrim included. The window is [size], or the size [sizes]
/// gives a variant.
///
/// Call it from a file tagged `@Tags(['golden'])`.
void screenGoldenEveryVariant(
  String name,
  Widget Function() build, {
  void Function(BuildContext context)? open,
  Size size = const Size(360, 740),
  Map<MmVariant, Size> sizes = const {},
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    final window = sizes[variant] ?? size;
    if (open == null) {
      await pumpScreen(tester, build(), size: window, variant: variant);
    } else {
      await pumpOverlay(
        tester,
        open,
        behind: build(),
        size: window,
        variant: variant,
      );
    }
    await expectAccessible(tester);
    await expectScreenGolden(name, variant);
  }, variants: variants);
}

/// Registers, for every variant, a golden of the overlay [open] opens over
/// [behind] (a plain page by default) on a whole screen: a dialog pushed on
/// the root navigator, a modal sheet or a snack bar. See
/// [screenGoldenEveryVariant].
///
/// Call it from a file tagged `@Tags(['golden'])`.
void overlayGoldenEveryVariant(
  String name,
  void Function(BuildContext context) open, {
  Widget Function()? behind,
  Size size = const Size(360, 740),
  Map<MmVariant, Size> sizes = const {},
  Iterable<MmVariant> variants = MmVariant.values,
}) => screenGoldenEveryVariant(
  name,
  behind ?? () => const Scaffold(),
  open: open,
  size: size,
  sizes: sizes,
  variants: variants,
);

/// A framed stand-in for a whole window of [size], to show several window
/// sizes side by side in one golden: [child] sees a [MediaQuery] of that
/// size (so `MmWindowSize` picks that window's layout), is laid out at that
/// size on a [Material] in the page colour, as a [Scaffold] would give it,
/// and is clipped to it.
class WindowPanel extends StatelessWidget {
  /// Shows [child] as a window of [size].
  const new({required this.size, required this.child, super.key});

  /// The size of the window [child] thinks it fills.
  final Size size;

  /// The window's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      border: Border.all(color: context.mm.colors.outline),
    ),
    child: ClipRect(
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: Material(color: context.mm.colors.bg, child: child),
        ),
      ),
    ),
  );
}
