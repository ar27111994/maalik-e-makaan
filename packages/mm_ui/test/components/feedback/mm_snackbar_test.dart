import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../../support/testing.dart';
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

/// The snackbar's own surface.
final Finder _surface = find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

/// The height of one line of the paragraph that shows [text].
double _lineHeight(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final style = paragraph.text.style!;
  return paragraph.textScaler.scale(style.fontSize!) * style.height!;
}

/// The number of lines the paragraph that shows [text] takes.
int _lines(WidgetTester tester, String text) =>
    (tester.getSize(find.text(text)).height / _lineHeight(tester, text))
        .round();

/// The Material that paints the button found by [button].
Material _buttonMaterial(WidgetTester tester, Finder button) => tester.widget(
  find.descendant(of: button, matching: find.byType(Material)).first,
);

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
      // On the page's 16 dp gutter at the sides and the bottom.
      expect(bar.margin, const EdgeInsets.all(MmSpace.s4));
      final surface = tester.getRect(_surface);
      expect(surface.left, MmSpace.s4);
      expect(surface.right, 360 - MmSpace.s4);
      expect(surface.bottom, 740 - MmSpace.s4);
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
          tone: MmBannerTone.info,
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

    testWidgets('wraps in Urdu at 200% text on a 320 dp phone', (tester) async {
      const message = 'علی رضا کی 1,25,000 روپے کی ادائیگی ڈیلیٹ ہو گئی';
      final context = await pumpUrduLargeNarrow(tester);
      unawaited(
        showMmSnackbar(
          context,
          message: message,
          tone: MmBannerTone.info,
          actionLabel: 'واپس لیں',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.renderObject<RenderParagraph>(find.text(message)).size.width,
        greaterThan(150),
      );
      expect(
        tester.getRect(find.text('واپس لیں')).top,
        greaterThan(tester.getRect(find.text(message)).bottom),
      );
    });

    testWidgets('a short action moves under the message at 200% text', (
      tester,
    ) async {
      // "Undo" alone is under a quarter of the bar; with the button's
      // padding it is not, and beside it the message would wrap to a word a
      // line.
      const message = 'Ali Raza’s payment was deleted';
      final context = await _page(tester, variant: MmVariant.largeText);
      unawaited(
        showMmSnackbar(
          context,
          message: message,
          tone: MmBannerTone.info,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.getRect(find.text(message));
      expect(tester.getRect(find.text('Undo')).top, greaterThan(text.bottom));
      expect(text.width, greaterThan(200));
      // Three lines across the bar, not four beside the action (one word
      // a line, as before).
      expect(_lines(tester, message), 3);
    });

    testWidgets('a message that would wrap past two lines beside the '
        'action puts it underneath', (tester) async {
      const message =
          'Rs 1,25,000 from Ali Raza, Ayesha Khan and Bilal Ahmed was '
          'moved to the October ledger';
      final context = await _page(tester);
      unawaited(
        showMmSnackbar(
          context,
          message: message,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Undo')).top,
        greaterThan(tester.getRect(find.text(message)).bottom),
      );
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
      // On a 412 dp phone "واپس لیں" is a short action; on a 360 dp one its
      // button is a pixel over a third of the row (see below).
      final context = await _page(
        tester,
        variant: MmVariant.urdu,
        size: const Size(412, 740),
      );
      unawaited(
        showMmSnackbar(
          context,
          message: 'علی رضا کی ادائیگی ڈیلیٹ ہو گئی',
          actionLabel: 'واپس لیں',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('واپس لیں')).dx,
        lessThan(
          tester.getCenter(find.text('علی رضا کی ادائیگی ڈیلیٹ ہو گئی')).dx,
        ),
      );
      // A short action stays on the message's row.
      expect(
        tester.getCenter(find.text('واپس لیں')).dy,
        moreOrLessEquals(
          tester.getCenter(find.text('علی رضا کی ادائیگی ڈیلیٹ ہو گئی')).dy,
          epsilon: 1,
        ),
      );
    });

    testWidgets('in Urdu, an action over a third of the row goes under the '
        'message at the left end', (tester) async {
      final context = await _page(tester, variant: MmVariant.urdu);
      unawaited(
        showMmSnackbar(
          context,
          message: 'علی رضا کی ادائیگی ڈیلیٹ ہو گئی',
          actionLabel: 'واپس لیں',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      final message = tester.getRect(
        find.text('علی رضا کی ادائیگی ڈیلیٹ ہو گئی'),
      );
      final action = tester.getRect(find.text('واپس لیں'));
      expect(action.top, greaterThan(message.bottom));
      expect(action.center.dx, lessThan(message.center.dx));
    });

    testEveryVariant("keyboard focus rings the action in the bar's mode", (
      tester,
      variant,
    ) async {
      final context = await _page(tester, variant: variant);
      unawaited(
        showMmSnackbar(
          context,
          message: _message,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, 'Undo'), isTrue);
      final bar = tester.widget<Material>(_surface).color!;
      final shape =
          _buttonMaterial(tester, find.byType(TextButton)).shape!
              as OutlinedBorder;
      final inverse = MmTheme.tokensFor(
        variant.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        highContrast: variant.highContrast,
      );
      // The ring is the opposite mode's focus colour, as the bar is the
      // opposite mode's surface: visible in every mode (WCAG 2.4.7, 1.4.11).
      expect(bar, inverse.surface);
      expect(shape.side.color, inverse.focus);
      expect(shape.side.width, MmSize.focusRing);
      expect(
        mmContrastRatio(shape.side.color, bar),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      // The action's label is the opposite mode's cobalt.
      expect(styleOf(tester, 'Undo').color, inverse.primary);
    });

    testWidgets('with a screen reader an action snackbar stays until used '
        'or dismissed', (tester) async {
      useScreenReader(tester);
      final handle = tester.ensureSemantics();
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
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsOneWidget);
      expect(shown.closed, isFalse);

      // It can still be closed without the action.
      final dismiss = find.byType(IconButton);
      expect(
        tester.getSemantics(dismiss),
        isSemantics(label: 'Dismiss', tooltip: '', isButton: true),
      );
      expect(tester.getSize(dismiss), const Size.square(MmSize.minTarget));
      // On the message's first line, at the end, with the action under it.
      final message = tester.getRect(find.text(_message));
      expect(tester.getCenter(dismiss).dx, greaterThan(message.right));
      expect(tester.getRect(find.text('Undo')).top, greaterThan(message.top));
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(shown.closed, isTrue);
      expect(find.text(_message), findsNothing);
      handle.dispose();
    });

    testWidgets('with a screen reader a message alone still closes', (
      tester,
    ) async {
      useScreenReader(tester);
      final context = await _page(tester);
      final shown = _Shown(showMmSnackbar(context, message: _message));
      await tester.pumpAndSettle();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
      expect(find.byType(IconButton), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(shown.closed, isTrue);
    });

    testEveryVariant("the dismiss button rings in the bar's mode", (
      tester,
      variant,
    ) async {
      useScreenReader(tester);
      final context = await _page(tester, variant: variant);
      unawaited(
        showMmSnackbar(
          context,
          message: _message,
          actionLabel: 'Undo',
          onAction: tapped,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.byIcon(MmIcons.close)), isTrue);
      final bar = tester.widget<Material>(_surface).color!;
      final ring =
          _buttonMaterial(tester, find.byType(IconButton)).shape!
              as MmFocusRingBorder;
      expect(
        mmContrastRatio(ring.color, bar),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      expect(
        mmContrastRatio(iconColorOf(tester, MmIcons.close), bar),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
    });

    testWidgets('the tone icon grows with the text, centred on its line', (
      tester,
    ) async {
      for (final (variant, size) in [
        (MmVariant.light, MmSize.iconLg),
        (MmVariant.largeText, MmSize.iconLg * MmIconLabel.maxIconScale),
      ]) {
        final context = await _page(tester, variant: variant);
        unawaited(
          showMmSnackbar(context, message: _message, tone: MmBannerTone.info),
        );
        await tester.pumpAndSettle();
        final icon = tester.getRect(find.byIcon(MmIcons.info));
        expect(icon.size, Size.square(size), reason: variant.name);
        final text = tester.getRect(find.text(_message));
        expect(
          icon.center.dy,
          moreOrLessEquals(
            text.top + _lineHeight(tester, _message) / 2,
            epsilon: 1,
          ),
          reason: variant.name,
        );
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('sets figures in an Urdu message in the Latin face', (
      tester,
    ) async {
      const message = 'عائشہ خان کے 45,000 روپے درج ہو گئے';
      final context = await _page(tester, variant: MmVariant.urdu);
      unawaited(showMmSnackbar(context, message: message));
      await tester.pumpAndSettle();
      expect(isLatinFace(runStyleIn(tester, message, '45,000')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, 'عائشہ')), isFalse);
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
