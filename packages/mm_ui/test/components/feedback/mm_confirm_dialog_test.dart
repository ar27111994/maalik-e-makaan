import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';

import '../../support/harness.dart';
import 'support.dart';

const _title = 'Remove Ali Raza?';
const _message = 'His ledger for Flat 3, Gulberg III is kept for your records.';
const _confirm = 'Remove tenant';
const _typed = 'Gulberg House';
const _typedLabel = 'Type Gulberg House to confirm';

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

/// A dialog's answer, once it has one.
class _Answer {
  new(Future<bool> answer) {
    unawaited(answer.then((value) => this.value = value));
  }

  bool? value;
}

/// Opens the dialog and lets it settle.
Future<_Answer> _open(
  WidgetTester tester,
  BuildContext context, {
  bool destructive = false,
  String? typedConfirmation,
  String? typedConfirmationLabel,
}) async {
  final answer = _Answer(
    showMmConfirmDialog(
      context,
      title: _title,
      message: _message,
      confirmLabel: _confirm,
      destructive: destructive,
      typedConfirmation: typedConfirmation,
      typedConfirmationLabel: typedConfirmationLabel,
    ),
  );
  await tester.pumpAndSettle();
  return answer;
}

/// The confirm button.
Finder get _confirmButton =>
    find.ancestor(of: find.text(_confirm), matching: find.byType(FilledButton));

/// The Material that paints the confirm button.
Material _confirmMaterial(WidgetTester tester) => tester.widget(
  find.descendant(of: _confirmButton, matching: find.byType(Material)).first,
);

void main() {
  group('showMmConfirmDialog', () {
    testEveryVariant('asks with a title, a message, Cancel and a verb', (
      tester,
      variant,
    ) async {
      final handle = tester.ensureSemantics();
      final context = await _page(tester, variant: variant);
      await _open(tester, context);
      final cancel = MmLocalizations.forLocale(variant.locale).cancel;
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(_message), findsOneWidget);
      expect(
        find.ancestor(of: find.text(cancel), matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(_confirmButton, findsOneWidget);
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      expect(
        tester.getSemantics(_confirmButton),
        isSemantics(label: _confirm, isButton: true, isEnabled: true),
      );
      final colors = colorsOf(variant);
      expect(_confirmMaterial(tester).color, colors.primary);
      expect(find.byType(TextField), findsNothing);
      handle.dispose();
    });

    testWidgets('is named by its title for screen readers', (tester) async {
      final context = await _page(tester);
      await _open(tester, context);
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).semanticLabel,
        _title,
      );
    });

    testWidgets('completes with true only when confirmed', (tester) async {
      final context = await _page(tester);
      final confirmed = await _open(tester, context);
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();
      expect(confirmed.value, isTrue);
      expect(find.byType(AlertDialog), findsNothing);

      final cancelled = await _open(tester, context);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelled.value, isFalse);
    });

    testWidgets('a tap outside, Back and Escape complete with false', (
      tester,
    ) async {
      final context = await _page(tester);
      final outside = await _open(tester, context);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(outside.value, isFalse);

      final back = await _open(tester, context);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(back.value, isFalse);

      final escape = await _open(tester, context);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(escape.value, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testEveryVariant('a destructive confirm is overdue, focus on Cancel', (
      tester,
      variant,
    ) async {
      final context = await _page(tester, variant: variant);
      final answer = await _open(tester, context, destructive: true);
      final colors = colorsOf(variant);
      expect(_confirmMaterial(tester).color, colors.overdue);
      expect(styleOf(tester, _confirm).color, MmFilledAction.onOverdue(colors));
      final cancel = MmLocalizations.forLocale(variant.locale).cancel;
      expect(focusedAt(tester, cancel), isTrue);
      // A stray Enter cancels.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answer.value, isFalse);
    });

    testWidgets('a plain confirmation does not put focus on Cancel', (
      tester,
    ) async {
      final context = await _page(tester);
      final answer = await _open(tester, context);
      expect(focusedAt(tester, 'Cancel'), isFalse);
      // Tab reaches Cancel, then the confirm button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, 'Cancel'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _confirm), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answer.value, isTrue);
    });

    testWidgets('a typed confirmation holds the button until it matches', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final context = await _page(tester);
      final answer = await _open(
        tester,
        context,
        destructive: true,
        typedConfirmation: _typed,
        typedConfirmationLabel: _typedLabel,
      );
      expect(find.text(_typedLabel), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TextField)),
        // Named by the label, then the hint that shows the text to type.
        isSemantics(label: '$_typedLabel\n$_typed', isTextField: true),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, _typed);
      expect(
        tester.getSemantics(_confirmButton),
        isSemantics(isButton: true, isEnabled: false),
      );

      for (final wrong in ['Gulberg', 'gulberg house', 'Gulberg  House']) {
        await tester.enterText(find.byType(TextField), wrong);
        await tester.pump();
        expect(
          tester.widget<FilledButton>(_confirmButton).onPressed,
          isNull,
          reason: wrong,
        );
      }
      // Enter does nothing while the text does not match.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(answer.value, isNull);

      await tester.enterText(find.byType(TextField), '  $_typed ');
      await tester.pump();
      expect(
        tester.getSemantics(_confirmButton),
        isSemantics(isButton: true, isEnabled: true),
      );
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();
      expect(answer.value, isTrue);
      handle.dispose();
    });

    testWidgets('a matching typed confirmation confirms on Enter', (
      tester,
    ) async {
      final context = await _page(tester);
      final answer = await _open(
        tester,
        context,
        typedConfirmation: _typed,
        typedConfirmationLabel: _typedLabel,
      );
      await tester.enterText(find.byType(TextField), _typed);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(answer.value, isTrue);
    });

    testWidgets('the typed field follows the script of the text to type', (
      tester,
    ) async {
      final urdu = await _page(tester, variant: MmVariant.urdu);
      await _open(
        tester,
        urdu,
        typedConfirmation: _typed,
        typedConfirmationLabel: 'تصدیق کے لیے Gulberg House لکھیں',
      );
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.style!.fontFamily, contains(MmFontFamily.latin));
      await tester.tap(find.text('منسوخ کریں'));
      await tester.pumpAndSettle();

      await _open(
        tester,
        urdu,
        typedConfirmation: 'گلبرگ ہاؤس',
        typedConfirmationLabel: 'تصدیق کے لیے گلبرگ ہاؤس لکھیں',
      );
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, isNull);
      expect(field.style!.fontFamily, contains(MmFontFamily.urdu));
    });

    testWidgets('a typed confirmation needs a label and some text', (
      tester,
    ) async {
      final context = await _page(tester);
      await expectLater(
        showMmConfirmDialog(
          context,
          title: _title,
          message: _message,
          confirmLabel: _confirm,
          typedConfirmation: _typed,
        ),
        throwsAssertionError,
      );
      await expectLater(
        showMmConfirmDialog(
          context,
          title: _title,
          message: _message,
          confirmLabel: _confirm,
          typedConfirmation: '  ',
          typedConfirmationLabel: _typedLabel,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('wraps and scrolls at 200% text on a 320 dp phone', (
      tester,
    ) async {
      final context = await _page(
        tester,
        variant: MmVariant.largeText,
        size: const Size(320, 640),
      );
      await _open(
        tester,
        context,
        destructive: true,
        typedConfirmation: _typed,
        typedConfirmationLabel: _typedLabel,
      );
      expect(tester.takeException(), isNull);
      for (final text in [_title, _message, _typedLabel]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      // The buttons stack when they do not fit side by side.
      expect(
        tester.getCenter(_confirmButton).dy,
        isNot(tester.getCenter(find.text('Cancel')).dy),
      );
      await tester.ensureVisible(_confirmButton);
      await tester.pumpAndSettle();
      expect(tester.getRect(_confirmButton).bottom, lessThanOrEqualTo(640));
    });

    testWidgets('mirrors for Urdu: Cancel at the start, on the right', (
      tester,
    ) async {
      final context = await _page(tester, variant: MmVariant.urdu);
      await _open(tester, context);
      expect(
        tester.getCenter(find.text('منسوخ کریں')).dx,
        greaterThan(tester.getCenter(_confirmButton).dx),
      );
    });

    testWidgets('opens without animating for reduced motion', (tester) async {
      Duration openingTime() =>
          ModalRoute.of(tester.element(find.byType(AlertDialog)))!
              .transitionDuration;

      final moving = await _page(tester);
      await _open(tester, moving);
      expect(openingTime(), MmDuration.standard);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final still = await _page(tester, still: true);
      await _open(tester, still);
      expect(openingTime(), Duration.zero);
    });
  });
}
