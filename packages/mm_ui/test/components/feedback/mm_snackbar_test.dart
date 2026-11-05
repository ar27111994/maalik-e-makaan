import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _message = 'Rs 45,000 recorded for Ayesha Khan';

/// Pumps a page and returns a context under its scaffold, from which
/// snackbars can be shown. [still] reduces motion.
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

/// Shows a snackbar and records when it closes.
class _Shown {
  new(Future<void> closing) {
    unawaited(closing.then((_) => closed = true));
  }

  bool closed = false;
}

void main() {
  group('showMmSnackbar', () {
    testWidgets('floats a message and closes after four seconds', (
      tester,
    ) async {
      final context = await _page(tester);
      final shown = _Shown(showMmSnackbar(context, message: _message));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.action, isNull);
      expect(bar.persist, isFalse);
      expect(bar.duration, const Duration(seconds: 4));
      expect(bar.width, isNull);
      expect(find.byIcon(MmIcons.info), findsNothing);
      expect(
        Theme.of(context).snackBarTheme.behavior,
        SnackBarBehavior.floating,
      );

      await tester.pump(const Duration(seconds: 3));
      expect(find.text(_message), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
      expect(shown.closed, isTrue);
    });

    testWidgets('is announced as it appears', (tester) async {
      final handle = tester.ensureSemantics();
      final context = await _page(tester);
      unawaited(showMmSnackbar(context, message: _message));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text(_message)),
        isSemantics(label: _message, isLiveRegion: true),
      );
      handle.dispose();
    });

    testEveryVariant('a tone puts its icon before the message', (
      tester,
      variant,
    ) async {
      final context = await _page(tester, variant: variant);
      unawaited(
        showMmSnackbar(context, message: _message, tone: MmBannerTone.success),
      );
      await tester.pumpAndSettle();
      final icon = tester.getCenter(find.byIcon(MmIcons.success));
      final text = tester.getCenter(find.text(_message));
      if (variant == MmVariant.urdu) {
        expect(icon.dx, greaterThan(text.dx));
      } else {
        expect(icon.dx, lessThan(text.dx));
      }
      // The snackbar is drawn in the opposite mode, so is its icon.
      final inverse = MmTheme.tokensFor(
        variant.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        highContrast: variant.highContrast,
      );
      expect(iconColorOf(tester, MmIcons.success), inverse.paid);
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byIcon(MmIcons.success),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an action is a button that stays for ten seconds', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var undone = 0;
      final context = await _page(tester);
      final shown = _Shown(
        showMmSnackbar(
          context,
          message: _message,
          tone: MmBannerTone.error,
          actionLabel: 'Undo',
          onAction: () => undone++,
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, greaterThanOrEqualTo(const Duration(seconds: 10)));
      expect(bar.persist, isFalse);
      expect(
        tester.getSemantics(find.text('Undo')),
        isSemantics(label: 'Undo', isButton: true, isEnabled: true),
      );

      await tester.pump(const Duration(seconds: 9));
      expect(find.text(_message), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text(_message), findsNothing);
      expect(shown.closed, isTrue);
      handle.dispose();
    });

    testWidgets('an unused action closes after ten seconds', (tester) async {
      final context = await _page(tester);
      final shown = _Shown(
        showMmSnackbar(
          context,
          message: _message,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
      expect(shown.closed, isTrue);
    });

    testWidgets('the action works from the keyboard', (tester) async {
      var undone = 0;
      final context = await _page(tester);
      unawaited(
        showMmSnackbar(
          context,
          message: _message,
          actionLabel: 'Undo',
          onAction: () => undone++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, 'Undo'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(undone, 1);
    });

    testWidgets('replaces the snackbar already showing', (tester) async {
      final context = await _page(tester);
      final first = _Shown(showMmSnackbar(context, message: 'Receipt shared'));
      await tester.pumpAndSettle();
      final second = _Shown(showMmSnackbar(context, message: _message));
      await tester.pumpAndSettle();
      expect(first.closed, isTrue);
      expect(second.closed, isFalse);
      expect(find.text('Receipt shared'), findsNothing);
      expect(find.text(_message), findsOneWidget);
    });

    testWidgets('appears and goes without animating for reduced motion', (
      tester,
    ) async {
      double opacityOf(String text) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      final moving = await _page(tester);
      unawaited(showMmSnackbar(moving, message: 'Receipt shared'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(opacityOf('Receipt shared'), lessThan(1));
      await tester.pumpAndSettle();

      final still = await _page(tester, still: true);
      final first = _Shown(showMmSnackbar(still, message: 'Receipt shared'));
      await tester.pump();
      await tester.pump();
      expect(opacityOf('Receipt shared'), 1);
      final second = _Shown(showMmSnackbar(still, message: _message));
      await tester.pump();
      await tester.pump();
      expect(first.closed, isTrue);
      expect(second.closed, isFalse);
      expect(find.text('Receipt shared'), findsNothing);
      expect(opacityOf(_message), 1);
    });

    testWidgets('keeps to the reading column on a wide window', (tester) async {
      final context = await _page(tester, size: const Size(1200, 800));
      unawaited(showMmSnackbar(context, message: _message));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).width,
        MmSize.contentMax,
      );
      final surface = find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Material),
      );
      expect(tester.getSize(surface.first).width, MmSize.contentMax);
      expect(tester.getCenter(surface.first).dx, 600);
    });

    testWidgets('wraps at 200% text on a 320 dp phone without overflow', (
      tester,
    ) async {
      final context = await _page(
        tester,
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      unawaited(
        showMmSnackbar(
          context,
          message: 'Ali Raza’s payment of Rs 1,25,000 was deleted',
          tone: MmBannerTone.error,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Undo'), findsOneWidget);
      // The enlarged action moves under the message instead of squeezing
      // it into a narrow column.
      final message = tester.getRect(
        find.text('Ali Raza’s payment of Rs 1,25,000 was deleted'),
      );
      expect(
        tester.getRect(find.text('Undo')).top,
        greaterThan(message.bottom),
      );
      expect(message.width, greaterThan(200));
    });

    testWidgets('a short action sits beside the message at 100% text', (
      tester,
    ) async {
      final context = await _page(tester);
      unawaited(
        showMmSnackbar(
          context,
          message: 'Payment deleted',
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Undo')).dy,
        moreOrLessEquals(tester.getCenter(find.text('Payment deleted')).dy),
      );
      // At the end of the row.
      final bar = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        tester.getRect(find.byType(TextButton)).right,
        moreOrLessEquals(bar.right - MmSpace.s2),
      );
    });

    testWidgets('the action runs once, however often it is pressed', (
      tester,
    ) async {
      var undone = 0;
      final context = await _page(tester);
      unawaited(
        showMmSnackbar(
          context,
          message: _message,
          actionLabel: 'Undo',
          onAction: () => undone++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text(_message), findsNothing);
    });

    testWidgets('says the action in Urdu, mirrored', (tester) async {
      final context = await _page(tester, variant: MmVariant.urdu);
      unawaited(
        showMmSnackbar(
          context,
          message: 'علی رضا کی ادائیگی حذف ہو گئی',
          actionLabel: 'واپس لیں',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('واپس لیں')).dx,
        lessThan(
          tester.getCenter(find.text('علی رضا کی ادائیگی حذف ہو گئی')).dx,
        ),
      );
    });

    testWidgets('an action needs both a label and a callback', (tester) async {
      final context = await _page(tester);
      await expectLater(
        showMmSnackbar(context, message: _message, actionLabel: 'Undo'),
        throwsAssertionError,
      );
      await expectLater(
        showMmSnackbar(context, message: _message, onAction: tapped),
        throwsAssertionError,
      );
    });
  });
}
