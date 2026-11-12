import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
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
      expect(styleOf(tester, _confirm).color, colors.surface);
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
        // Named by the label, which says what to type.
        isSemantics(label: _typedLabel, isTextField: true),
      );
      // No hint: in the empty field it would look like a value already
      // typed in. The label sets the text to type in bold instead.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, isNull);
      expect(find.text(_typed), findsNothing);
      expect(
        runStyleIn(tester, _typedLabel, _typed).fontWeight,
        FontWeight.w700,
      );
      expect(
        runStyleIn(tester, _typedLabel, 'Type').fontWeight,
        FontWeight.w400,
      );
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
      await tester.tap(find.text('رہنے دیں'));
      await tester.pumpAndSettle();

      const label = 'فلیٹ 3 کی تصدیق کے لیے گلبرگ ہاؤس لکھیں';
      await _open(
        tester,
        urdu,
        typedConfirmation: 'گلبرگ ہاؤس',
        typedConfirmationLabel: label,
      );
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, isNull);
      expect(field.style!.fontFamily, contains(MmFontFamily.urdu));
      // Urdu text to type stays in Nastaliq, in bold; a figure elsewhere in
      // the label is in the Latin face.
      final name = runStyleIn(tester, label, 'گلبرگ ہاؤس');
      expect(isLatinFace(name), isFalse);
      expect(name.fontWeight, FontWeight.w700);
      expect(isLatinFace(runStyleIn(tester, label, '3')), isTrue);
    });

    testWidgets('in Urdu the Latin text to type is bold Atkinson, typed '
        'from the same side it is read', (tester) async {
      const label = 'تصدیق کے لیے Gulberg House لکھیں';
      final urdu = await _page(tester, variant: MmVariant.urdu);
      await _open(
        tester,
        urdu,
        destructive: true,
        typedConfirmation: _typed,
        typedConfirmationLabel: label,
      );
      final name = runStyleIn(tester, label, _typed);
      expect(isLatinFace(name), isTrue);
      expect(name.fontWeight, FontWeight.w700);
      expect(isLatinFace(runStyleIn(tester, label, 'تصدیق')), isFalse);

      // The field is empty (no hint at the right edge for the text to jump
      // away from), and the name typed into it starts at its left edge.
      expect(find.text(_typed), findsNothing);
      final box = tester.getRect(find.byType(TextField));
      await tester.enterText(find.byType(TextField), _typed);
      await tester.pump();
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final ends = editable.getEndpointsForSelection(
        const TextSelection(baseOffset: 0, extentOffset: _typed.length),
      );
      final first = editable.localToGlobal(ends.first.point).dx;
      final last = editable.localToGlobal(ends.last.point).dx;
      expect(first, lessThan(last));
      expect(first - box.left, lessThanOrEqualTo(MmSpace.s6));
      expect(box.right - last, greaterThan(first - box.left));
    });

    testWidgets('sets figures in an Urdu title and message in the Latin '
        'face', (tester) async {
      const title = 'گلبرگ ہاؤس کے 4 یونٹ ڈیلیٹ کریں؟';
      const message = 'اس کے 1,25,000 روپے کا ریکارڈ ختم ہو جائے گا۔';
      final urdu = await _page(tester, variant: MmVariant.urdu);
      unawaited(
        showMmConfirmDialog(
          urdu,
          title: title,
          message: message,
          confirmLabel: 'ڈیلیٹ کریں',
        ),
      );
      await tester.pumpAndSettle();
      expect(isLatinFace(runStyleIn(tester, title, '4')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, '1,25,000')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, 'روپے')), isFalse);
      expect(
        tester.getSemantics(find.text(title)),
        isSemantics(label: title, isHeader: true),
      );
    });

    testEveryVariant('has the overlay edge where it would melt into the '
        'page', (tester, variant) async {
      final context = await _page(tester, variant: variant);
      await _open(tester, context);
      final dialog = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      final edge = MmTheme.overlayEdge(
        variant.colors,
        brightness: variant.brightness,
        highContrast: variant.highContrast,
      );
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.side, edge);
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.lg)),
      );
      if (variant == MmVariant.darkHighContrast) {
        // Black paper on a black page: the outline is the only edge.
        expect(dialog.color, variant.colors.surface);
        expect(edge.color, variant.colors.outline);
        expect(
          mmContrastRatio(edge.color, variant.colors.surface),
          greaterThanOrEqualTo(mmMinimumIconContrast),
        );
      }
    });

    testWidgets('keeps at least 16 dp of padding at large text', (
      tester,
    ) async {
      Future<Rect> titleIn(MmVariant variant) async {
        final context = await _page(
          tester,
          variant: variant,
          size: const Size(320, 740),
        );
        await _open(tester, context);
        return tester.getRect(find.text(_title));
      }

      final dialogOf = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first;
      final normal = await titleIn(MmVariant.light);
      final box = tester.getRect(dialogOf);
      expect(normal.left - box.left, MmSpace.s6);
      expect(normal.top - box.top, MmSpace.s6);
      expect(tester.getRect(find.text(_message)).left - box.left, MmSpace.s6);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final large = await titleIn(MmVariant.largeText);
      final largeBox = tester.getRect(dialogOf);
      expect(large.left - largeBox.left, MmSpace.s4);
      expect(large.top - largeBox.top, MmSpace.s4);
      expect(
        tester.getRect(find.text(_message)).left - largeBox.left,
        MmSpace.s4,
      );
      final cancel = tester.getRect(
        find.ancestor(
          of: find.text('Cancel'),
          matching: find.byType(TextButton),
        ),
      );
      expect(largeBox.bottom - cancel.bottom, greaterThanOrEqualTo(MmSpace.s4));
    });

    testWidgets('fits in Urdu at 200% text on a 320 dp phone', (tester) async {
      const title = 'گلبرگ ہاؤس ڈیلیٹ کریں؟';
      const message =
          'اس کے 4 یونٹ اور 1,25,000 روپے کا ریکارڈ ختم ہو جائے گا۔';
      const label = 'تصدیق کے لیے Gulberg House لکھیں';
      final context = await pumpUrduLargeNarrow(tester, height: 640);
      unawaited(
        showMmConfirmDialog(
          context,
          title: title,
          message: message,
          confirmLabel: 'جائیداد ڈیلیٹ کریں',
          destructive: true,
          typedConfirmation: _typed,
          typedConfirmationLabel: label,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in [title, message, label]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      }
      await tester.enterText(find.byType(TextField), _typed);
      await tester.pump();
      final confirm = find.ancestor(
        of: find.text('جائیداد ڈیلیٹ کریں'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
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
      // The label must show the text to type, now that the field has no
      // hint.
      await expectLater(
        showMmConfirmDialog(
          context,
          title: _title,
          message: _message,
          confirmLabel: _confirm,
          typedConfirmation: _typed,
          typedConfirmationLabel: 'Type the property name to confirm',
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
        tester.getCenter(find.text('رہنے دیں')).dx,
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

  group('showMmConfirmDialog cancel label', () {
    testWidgets('names the way out in its own words when "Cancel" would '
        'be ambiguous', (tester) async {
      final context = await _page(tester);
      final answer = _Answer(
        showMmConfirmDialog(
          context,
          title: 'Cancel the repair?',
          message: 'The plumber will not be called.',
          confirmLabel: 'Cancel the repair',
          cancelLabel: 'Keep the repair',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      final keep = find.ancestor(
        of: find.text('Keep the repair'),
        matching: find.byType(TextButton),
      );
      expect(keep, findsOneWidget);
      // It is still the safe answer: it has the focus and answers no.
      expect(hasFocus(tester, find.text('Keep the repair')), isTrue);
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(answer.value, isFalse);
    });

    testWidgets('sets Latin words in an Urdu cancel label in the Latin face', (
      tester,
    ) async {
      final context = await _page(tester, variant: MmVariant.urdu);
      unawaited(
        showMmConfirmDialog(
          context,
          title: 'مرمت کا کام کینسل کریں؟',
          message: 'پلمبر کو نہیں بلایا جائے گا۔',
          confirmLabel: 'کام کینسل کریں',
          cancelLabel: 'PDF رکھیں',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PDF رکھیں', findRichText: true), findsOneWidget);
    });
  });
}
