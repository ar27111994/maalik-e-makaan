import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _title = 'Ledger unavailable';
const _message =
    'The ledger for Ali Raza could not be loaded. Check your connection.';
const _details = 'HTTP 503: ledger_entries timed out after 30 s';
const _detailsLabel = 'Technical details';

/// An error state with every part, at the given motion setting.
Widget _full({bool still = false, String details = _details}) => Builder(
  key: ValueKey((still, details)),
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: MmErrorState(
      title: _title,
      message: _message,
      onRetry: tapped,
      details: details,
      detailsLabel: _detailsLabel,
    ),
  ),
);

void main() {
  group('MmErrorState', () {
    testEveryVariant('shows the error icon in the overdue colour', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmErrorState(title: _title, message: _message),
        variant: variant,
      );
      final text = variant.theme.textTheme;
      final colors = colorsOf(variant);
      final icon = tester.widget<Icon>(find.byIcon(MmIcons.error));
      expect(icon.size, 48);
      expect(icon.color, colors.overdue);
      expect(styleOf(tester, _title).fontSize, text.titleLarge!.fontSize);
      expect(styleOf(tester, _message).color, colors.inkMuted);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(_detailsLabel), findsNothing);
    });

    testWidgets('announces the message as it appears, the title as a heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmErrorState(title: _title, message: _message),
      );
      expect(
        tester.getSemantics(find.text(_message)),
        isSemantics(label: _message, isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('without a title it shows no heading', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const MmErrorState(message: _message));
      expect(find.text(_title), findsNothing);
      expect(
        tester.getSemantics(find.text(_message)),
        isSemantics(label: _message, isHeader: false, isLiveRegion: true),
      );
      handle.dispose();
    });

    testEveryVariant('the retry button says "Try again" in the language', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmErrorState(message: _message, onRetry: tapped),
        variant: variant,
      );
      final retry = MmLocalizations.forLocale(variant.locale).retry;
      expect(find.text(retry), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byIcon(MmIcons.refresh),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: retry, isButton: true, isEnabled: true),
      );
    });

    testWidgets('retries on tap and from the keyboard', (tester) async {
      var retries = 0;
      await pumpThemed(
        tester,
        MmErrorState(message: _message, onRetry: () => retries++),
      );
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, 'Try again'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(retries, 2);
    });

    test('details without a label are a programming error', () {
      expect(
        () => MmErrorState(message: _message, details: _details),
        throwsAssertionError,
      );
    });

    for (final still in [false, true]) {
      testWidgets(
        'details open and close on request (reduced motion: $still)',
        (tester) async {
          final handle = tester.ensureSemantics();
          await pumpThemed(tester, _full(still: still));
          expect(find.text(_details), findsNothing);
          expect(find.byType(AnimatedSize), still ? findsNothing : findsOne);
          final toggle = find.ancestor(
            of: find.text(_detailsLabel),
            matching: find.byType(TextButton),
          );
          expect(
            tester.getSemantics(toggle),
            isSemantics(
              label: _detailsLabel,
              isButton: true,
              hasExpandedState: true,
              isExpanded: false,
            ),
          );
          expect(find.byIcon(MmIcons.expand), findsOneWidget);

          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text(_details), findsOneWidget);
          expect(find.byType(SelectableText), findsOneWidget);
          expect(find.byIcon(MmIcons.collapse), findsOneWidget);
          expect(
            tester.getSemantics(toggle),
            isSemantics(
              label: _detailsLabel,
              hasExpandedState: true,
              isExpanded: true,
            ),
          );

          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text(_details), findsNothing);
          handle.dispose();
        },
      );
    }

    testWidgets('details open from the keyboard', (tester) async {
      await pumpThemed(tester, _full());
      // Retry first, then the details toggle.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _detailsLabel), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_details), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text(_details), findsNothing);
    });

    testEveryVariant('details sit in a sunken well, Latin left to right', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _full(), variant: variant);
      await tester.tap(find.byIcon(MmIcons.expand));
      await tester.pumpAndSettle();
      final colors = colorsOf(variant);
      final well = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(SelectableText),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = well.decoration as BoxDecoration;
      expect(decoration.color, colors.surfaceSunken);
      expect(
        decoration.border,
        variant.highContrast ? Border.all(color: colors.rule) : isNull,
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.textDirection, TextDirection.ltr);
      // Latin details are set in Atkinson in both languages.
      expect(text.style!.fontFamily, contains(MmFontFamily.latin));
    }, variants: MmVariant.values.where((v) => v != MmVariant.urdu));

    testWidgets('Urdu details follow the page direction and script', (
      tester,
    ) async {
      const urdu = 'سرور سے رابطہ نہیں ہو سکا';
      await pumpThemed(tester, _full(details: urdu), variant: MmVariant.urdu);
      await tester.tap(find.byIcon(MmIcons.expand));
      await tester.pumpAndSettle();
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.textDirection, isNull);
      expect(text.style!.fontFamily, contains(MmFontFamily.urdu));
      // Latin details in the Urdu UI read left to right in Atkinson.
      await pumpThemed(tester, _full(), variant: MmVariant.urdu);
      await tester.tap(find.byIcon(MmIcons.expand));
      await tester.pumpAndSettle();
      final latin = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(latin.textDirection, TextDirection.ltr);
      expect(latin.style!.fontFamily, contains(MmFontFamily.latin));
    });

    testWidgets('wraps at 200% text on a 320 dp phone without overflow', (
      tester,
    ) async {
      await pumpLargeNarrow(tester, _full(), height: 1600);
      await tester.tap(find.byIcon(MmIcons.expand));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in [_message, _title]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      // The details wrap onto several lines inside the 320 dp phone.
      final details = tester.getRect(find.byType(SelectableText));
      expect(details.width, lessThan(320));
      expect(details.height, greaterThan(100));
    });

    testWidgets('mirrors for Urdu', (tester) async {
      await pumpThemed(tester, _full(), variant: MmVariant.urdu);
      // The disclosure chevron follows the label, at its end (left).
      expect(
        tester.getCenter(find.byIcon(MmIcons.expand)).dx,
        lessThan(tester.getCenter(find.text(_detailsLabel)).dx),
      );
      expect(find.text('دوبارہ کوشش کریں'), findsOneWidget);
    });
  });
}
