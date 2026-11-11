import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'testing.dart';

/// The colours of the pixels [finder]'s repaint boundary paints, as
/// 0xAARRGGBB, row by row.
Future<List<int>> _pixelsOf(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return await image.toByteData();
    } finally {
      image.dispose();
    }
  });
  return [
    for (var i = 0; i < bytes!.lengthInBytes; i += 4)
      bytes.getUint8(i + 3) << 24 |
          bytes.getUint8(i) << 16 |
          bytes.getUint8(i + 1) << 8 |
          bytes.getUint8(i + 2),
  ];
}

/// Shows the window size it is laid out in.
class _WindowSize extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Text('${size.width.round()} x ${size.height.round()}');
  }
}

/// Paints nothing; stands in for a component's painter.
class _Painter extends CustomPainter {
  const new(this.name);

  final String name;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_Painter oldDelegate) => oldDelegate.name != name;
}

void main() {
  group('themed', () {
    testEveryVariant('paints the page under the subject, on whole pixels', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(width: 101.5, height: 33.25),
        variant: variant,
      );
      final subject = find.byKey(subjectKey);
      final origin = tester.getTopLeft(subject);
      expect(origin.dx, origin.dx.roundToDouble());
      expect(origin.dy, origin.dy.roundToDouble());
      expect(tester.getSize(subject), const Size(102 + 32, 34 + 32));
      final box = tester.getTopLeft(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 101.5),
      );
      expect(box, origin + const Offset(MmSpace.s4, MmSpace.s4));
      final page = variant.colors.bg.toARGB32();
      expect((await _pixelsOf(tester, subject)).toSet(), {page});
    });

    testWidgets('captures what the subject paints past its own box', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Transform.translate(
            offset: const Offset(-10, 0),
            child: ColoredBox(
              color: context.mm.colors.primary,
              child: const SizedBox.square(dimension: 20),
            ),
          ),
        ),
      );
      final pixels = await _pixelsOf(tester, find.byKey(subjectKey));
      final width = tester.getSize(find.byKey(subjectKey)).width.toInt();
      // 10 dp down into the square, which starts past the 16 dp gutter.
      final row = MmSpace.s4.toInt() + 10;
      expect(
        pixels[row * width + 8],
        MmVariant.light.colors.primary.toARGB32(),
      );
    });

    testWidgets('keeps ink the subject draws on its nearest Material', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) =>
              Ink(color: context.mm.colors.primary, width: 40, height: 40),
        ),
      );
      final ink = tester.getRect(find.byType(Ink));
      final page = tester.getRect(find.byKey(subjectKey));
      final pixels = await _pixelsOf(tester, find.byKey(subjectKey));
      final centre = ink.center - page.topLeft;
      expect(
        pixels[centre.dy.toInt() * page.width.toInt() + centre.dx.toInt()],
        MmVariant.light.colors.primary.toARGB32(),
      );
    });

    testWidgets("lays a subject out at its own size, not the page's", (
      tester,
    ) async {
      await pumpThemed(tester, const Text('Ali Raza'));
      final text = tester.getSize(find.text('Ali Raza'));
      final subject = tester.getSize(find.byKey(subjectKey));
      expect(subject.width, text.width.ceilToDouble() + 2 * MmSpace.s4);
      expect(subject.height, text.height.ceilToDouble() + 2 * MmSpace.s4);
    });
  });

  group('themedApp', () {
    testWidgets("takes another language with the variant's text scale", (
      tester,
    ) async {
      await tester.pumpWidget(
        themedApp(
          Builder(
            builder: (context) => Text(
              '${Localizations.localeOf(context).languageCode} '
              '${MediaQuery.textScalerOf(context).scale(10)} '
              '${context.mm.script.name}',
            ),
          ),
          variant: MmVariant.largeText,
          locale: const Locale('ur'),
        ),
      );
      expect(find.text('ur 20.0 urdu'), findsOneWidget);
    });
  });

  group('pumpScreen', () {
    testWidgets('fills the window, and follows it when resized', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SizedBox.expand(child: _WindowSize()),
        size: const Size(600, 800),
      );
      expect(
        tester.getRect(find.byType(SizedBox).first),
        Offset.zero & const Size(600, 800),
      );
      expect(find.text('600 x 800'), findsOneWidget);
      await resizeScreen(tester, const Size(1024, 768));
      expect(find.text('1024 x 768'), findsOneWidget);
    });

    testWidgets('paints the page colour under a page that has none', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SizedBox.shrink(),
        size: const Size(20, 20),
        variant: MmVariant.darkHighContrast,
      );
      expect((await _pixelsOf(tester, find.byKey(screenKey))).toSet(), {
        MmVariant.darkHighContrast.colors.bg.toARGB32(),
      });
    });
  });

  group('pumpOverlay', () {
    testWidgets('opens a dialog on the root navigator, inside the screen', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        (context) => unawaited(
          showDialog<void>(
            context: context,
            builder: (context) =>
                const AlertDialog(content: Text('Remove Flat 2B?')),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(screenKey),
          matching: find.text('Remove Flat 2B?'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('shows a snack bar on the page behind', (tester) async {
      await pumpOverlay(
        tester,
        (context) => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payment recorded'))),
        behind: const Scaffold(body: Text('Ledger')),
      );
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.text('Payment recorded'),
        ),
        findsOneWidget,
      );
    });
  });

  group('WindowPanel', () {
    testWidgets('lays its child out as a window of its size', (tester) async {
      await pumpThemed(
        tester,
        const WindowPanel(size: Size(200, 120), child: _WindowSize()),
      );
      expect(find.text('200 x 120'), findsOneWidget);
      expect(tester.getSize(find.byType(WindowPanel)), const Size(200, 120));
    });
  });

  group('GoldenPage', () {
    testEveryVariant('says the words of the ambient language at its width', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        GoldenPage(
          width: 200,
          (context, say) => Text(say('Rent due', 'کرائے کی تاریخ')),
        ),
        variant: variant,
      );
      final urdu = variant == MmVariant.urdu;
      expect(find.text(urdu ? 'کرائے کی تاریخ' : 'Rent due'), findsOneWidget);
      expect(tester.getSize(find.byType(GoldenPage)).width, 200);
    }, variants: const [MmVariant.light, MmVariant.urdu]);
  });

  group('helpers', () {
    testWidgets('expectFitsNarrowLargeText passes text that wraps', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const Text('Rent for October is due on the 5th at Gulberg Heights'),
      );
      expect(tester.view.physicalSize, const Size(320, 740));
    });

    testWidgets('expectFitsNarrowLargeText fails on an overflow', (
      tester,
    ) async {
      Object? failure;
      try {
        await expectFitsNarrowLargeText(
          tester,
          const Row(children: [SizedBox(width: 400, height: 10)]),
        );
      } on TestFailure catch (error) {
        failure = error;
      }
      expect(failure, isA<TestFailure>());
    });

    testWidgets('pumpLargeNarrow pumps 200% text on 320 dp', (tester) async {
      await pumpLargeNarrow(tester, const _WindowSize(), height: 600);
      expect(find.text('320 x 600'), findsOneWidget);
      expect(styleOf(tester, '320').fontSize, isNotNull);
      expect(paragraphOf(tester, '320').textScaler, const TextScaler.linear(2));
    });

    testWidgets('finds focus, labels and painters', (tester) async {
      useKeyboardHighlights();
      expect(
        FocusManager.instance.highlightStrategy,
        FocusHighlightStrategy.alwaysTraditional,
      );
      await pumpThemed(
        tester,
        withoutAnimations(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) => Text(
                  'Animations ${MediaQuery.disableAnimationsOf(context)}',
                ),
              ),
              Semantics(
                key: const ValueKey('tenants'),
                container: true,
                explicitChildNodes: true,
                label: 'Tenants',
                child: Column(
                  children: [
                    Semantics(container: true, child: const Text('Ali Raza')),
                    Semantics(
                      container: true,
                      child: const Text('Ayesha Khan'),
                    ),
                  ],
                ),
              ),
              const TextButton(
                autofocus: true,
                onPressed: tapped,
                child: Text('Pay'),
              ),
              const TextButton(onPressed: tapped, child: Text('Cancel')),
              const CustomPaint(painter: _Painter('a')),
              const CustomPaint(painter: _Painter('b')),
            ],
          ),
        ),
      );
      expect(find.text('Animations true'), findsOneWidget);
      expect(focusedAt(tester, 'Pay'), isTrue);
      expect(hasFocus(tester, find.text('Cancel')), isFalse);
      final tenants = tester.getSemantics(
        find.byKey(const ValueKey('tenants')),
      );
      expect(readingOrder(tenants), ['Ali Raza', 'Ayesha Khan']);
      expect(labelsIn(tenants.parent!), [
        'Animations true',
        'Tenants',
        'Ali Raza',
        'Ayesha Khan',
        'Pay',
        'Cancel',
      ]);
      final column = find.byType(Column).first;
      expect(
        [for (final p in paintersIn<_Painter>(tester, column)) p.name],
        ['a', 'b'],
      );
      expect(painterIn<_Painter>(tester, column).name, 'a');
      expect(colorsOf(MmVariant.dark), MmTheme.tokensFor(Brightness.dark));
    });
  });
}
