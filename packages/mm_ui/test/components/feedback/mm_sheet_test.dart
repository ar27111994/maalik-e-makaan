import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _title = 'Record payment';

/// Pumps a page and returns a context under it. [still] reduces motion.
Future<BuildContext> _page(
  WidgetTester tester, {
  MmVariant variant = MmVariant.light,
  Size size = const Size(360, 740),
  bool still = false,
}) async {
  late BuildContext page;
  await pumpThemed(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Builder(
          builder: (context) {
            page = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
    variant: variant,
    size: size,
  );
  return page;
}

/// The value a sheet closed with, once it closed.
class _Result<T> {
  new(Future<T?> result) {
    unawaited(
      result.then((value) {
        closed = true;
        this.value = value;
      }),
    );
  }

  bool closed = false;
  T? value;
}

/// Opens a sheet with [content] and lets it settle.
Future<_Result<String>> _open(
  WidgetTester tester,
  BuildContext context, {
  WidgetBuilder? content,
  String title = _title,
}) async {
  final result = _Result<String>(
    showMmSheet<String>(
      context,
      title: title,
      builder:
          content ??
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Ayesha Khan · Rs 45,000'),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'cash'),
                child: const Text('Record as cash'),
              ),
            ],
          ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

/// Thirty rows, taller than any phone.
Widget _tall(BuildContext context) => Column(
  children: [
    for (var row = 1; row <= 30; row++) ListTile(title: Text('Flat $row')),
  ],
);

/// The close button.
Finder get _close => find.ancestor(
  of: find.byIcon(MmIcons.close),
  matching: find.byType(IconButton),
);

void main() {
  group('showMmSheet', () {
    testEveryVariant('has a heading, a close button and the content', (
      tester,
      variant,
    ) async {
      final handle = tester.ensureSemantics();
      final context = await _page(tester, variant: variant);
      await _open(tester, context);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Ayesha Khan · Rs 45,000'), findsOneWidget);
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      final close = MmLocalizations.forLocale(variant.locale).close;
      expect(
        tester.getSemantics(_close),
        isSemantics(label: close, tooltip: '', isButton: true),
      );
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: _close, matching: find.byType(Tooltip)),
            )
            .message,
        close,
      );
      expect(tester.getSize(_close), const Size.square(MmSize.minTarget));
      final style = styleOf(tester, _title);
      expect(style.fontSize, variant.theme.textTheme.titleLarge!.fontSize);
      handle.dispose();
    });

    testWidgets('the close button closes it with no value', (tester) async {
      final context = await _page(tester);
      final result = await _open(tester, context);
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(result.closed, isTrue);
      expect(result.value, isNull);
    });

    testWidgets('completes with the value the content closes it with', (
      tester,
    ) async {
      final context = await _page(tester);
      final result = await _open(tester, context);
      await tester.tap(find.text('Record as cash'));
      await tester.pumpAndSettle();
      expect(result.value, 'cash');
    });

    testWidgets('a tap outside and Escape close it', (tester) async {
      final context = await _page(tester);
      final outside = await _open(tester, context);
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(outside.closed, isTrue);

      final escape = await _open(tester, context);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(escape.closed, isTrue);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the keyboard reaches and activates the close button', (
      tester,
    ) async {
      final context = await _page(tester);
      final result = await _open(tester, context);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.byIcon(MmIcons.close))).hasPrimaryFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result.closed, isTrue);
    });

    testWidgets('tall content scrolls under a fixed header', (tester) async {
      final context = await _page(tester);
      await _open(tester, context, content: _tall);
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.bottom, 740);
      final header = tester.getRect(find.text(_title));
      await tester.scrollUntilVisible(
        find.text('Flat 30'),
        200,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Flat 30').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.text(_title)), header);
    });

    testWidgets('keeps the content above the on-screen keyboard', (
      tester,
    ) async {
      final context = await _page(tester);
      await _open(
        tester,
        context,
        content: (context) =>
            const TextField(decoration: InputDecoration(hintText: 'Amount')),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(740 - 300),
      );
    });

    testWidgets('keeps clear of the system bars', (tester) async {
      tester.view
        ..padding = const FakeViewPadding(top: 24, bottom: 34)
        ..viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      final context = await _page(tester);
      await _open(tester, context, content: _tall);
      expect(
        tester.getRect(find.byType(BottomSheet)).top,
        greaterThanOrEqualTo(24),
      );
      final scrollable = tester.getRect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.bottom, lessThanOrEqualTo(740 - 34));
    });

    testWidgets('is at most 640 dp wide, centred, on wide windows', (
      tester,
    ) async {
      final context = await _page(tester, size: const Size(1200, 800));
      await _open(tester, context);
      final sheet = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheet.width, 640);
      expect(sheet.center.dx, 600);
      expect(tester.getRect(_close).right, lessThanOrEqualTo(sheet.right));
    });

    testWidgets('opens without animating for reduced motion', (tester) async {
      Duration openingTime() =>
          ModalRoute.of(tester.element(find.byType(BottomSheet)))!
              .transitionDuration;

      final moving = await _page(tester);
      await _open(tester, moving);
      expect(openingTime(), MmDuration.standard);
      await tester.tap(_close);
      await tester.pumpAndSettle();

      final still = await _page(tester, still: true);
      await _open(tester, still);
      expect(openingTime(), Duration.zero);
    });

    testWidgets('wraps at 200% text on a 320 dp phone without overflow', (
      tester,
    ) async {
      const title = 'Record the October payment from Ayesha Khan';
      final context = await _page(
        tester,
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      await _open(tester, context, title: title, content: _tall);
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.didExceedMaxLines, isFalse);
      // The close button stays at the end of the first line.
      expect(
        tester.getRect(_close).left,
        greaterThan(tester.getRect(find.text(title)).right),
      );
    });

    testWidgets('mirrors for Urdu: the close button at the left', (
      tester,
    ) async {
      final context = await _page(tester, variant: MmVariant.urdu);
      await _open(tester, context, title: 'ادائیگی درج کریں');
      expect(
        tester.getCenter(_close).dx,
        lessThan(tester.getCenter(find.text('ادائیگی درج کریں')).dx),
      );
    });
  });
}
