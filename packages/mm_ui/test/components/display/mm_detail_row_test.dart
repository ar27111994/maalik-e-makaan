import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';

import '../../support/testing.dart';

const _label = 'Monthly rent';
const _value = 'Rs\u00A045,000';
const _address = 'House 12, Street 4, Gulberg III, Lahore';
const _rent = Money.fromRupees(45000);
const _cnic = '35202-1234567-1';

/// A button that copies the CNIC.
Widget _copy({VoidCallback? onPressed}) => IconButton(
  tooltip: 'Copy',
  onPressed: onPressed ?? () {},
  icon: const Icon(MmIcons.copy),
);

/// The distance from the top of the screen to [text]'s first baseline.
double _baseline(WidgetTester tester, String text) {
  final paragraph = paragraphOf(tester, text);
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

void main() {
  group('MmDetailRow', () {
    testEveryVariant('sets the label muted and the value in ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: _label, value: _value),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final label = styleOf(tester, _label);
      expect(label.color, colors.inkMuted);
      expect(label.fontSize, text.bodyMedium!.fontSize);
      final value = styleOf(tester, _value);
      expect(value.color, colors.ink);
      expect(value.fontSize, text.bodyLarge!.fontSize);
      expect(value.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    testWidgets('an emphasized row is a total in the title style', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(
          label: 'Total due',
          value: 'Rs\u00A01,25,000',
          emphasized: true,
        ),
      );
      final titleMedium = MmVariant.light.theme.textTheme.titleMedium!;
      for (final text in ['Total due', 'Rs\u00A01,25,000']) {
        final style = styleOf(tester, text);
        expect(style.color, MmColorModes.light.ink);
        expect(style.fontSize, titleMedium.fontSize);
        expect(style.fontWeight, titleMedium.fontWeight);
      }
    });

    testWidgets('puts the value at the end on the label baseline', (
      tester,
    ) async {
      await pumpThemed(tester, const MmDetailRow(label: _label, value: _value));
      final row = tester.getRect(find.byType(MmDetailRow));
      expect(tester.getRect(find.text(_label)).left, row.left);
      expect(tester.getRect(find.text(_value)).right, row.right);
      expect(
        _baseline(tester, _value),
        moreOrLessEquals(_baseline(tester, _label), epsilon: 0.01),
      );
      // The taller value starts at the top padding; the label drops to its
      // baseline.
      expect(tester.getRect(find.text(_value)).top, row.top + MmSpace.s2);
      expect(
        tester.getRect(find.text(_label)).top,
        greaterThan(row.top + MmSpace.s2),
      );
    });

    testWidgets('mirrors right to left', (tester) async {
      await pumpThemed(
        tester,
        const MmDetailRow.amount(label: 'ماہانہ کرایہ', amount: _rent),
        variant: MmVariant.urdu,
      );
      final row = tester.getRect(find.byType(MmDetailRow));
      expect(tester.getRect(find.text('ماہانہ کرایہ')).right, row.right);
      expect(tester.getRect(find.byType(MmAmount)).left, row.left);
    });

    testEveryVariant('sets an amount as MmAmount does: the Latin face with '
        'tabular figures, in both languages', (tester, variant) async {
      await pumpThemed(
        tester,
        const MmDetailRow.amount(label: _label, amount: _rent),
        variant: variant,
      );
      final semantics = variant.theme.extension<MmSemantics>()!;
      final style = styleOf(tester, '45,000');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(style.fontSize, semantics.amount.fontSize);
      expect(style.fontWeight, semantics.amount.fontWeight);
      expect(style.color, colorsOf(variant).ink);
      // The Urdu currency word falls back to Nastaliq.
      expect(style.fontFamilyFallback, ['packages/mm_ui/${MmFontFamily.urdu}']);
      expect(styleOf(tester, _label).color, colorsOf(variant).inkMuted);
    });

    testWidgets('reads an amount as the plain number and rupees', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow.amount(label: _label, amount: _rent),
      );
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: '$_label, 45000 rupees'),
      );
      const row = MmDetailRow.amount(label: _label, amount: _rent);
      expect(row.amount, _rent);
      expect(row.value, isNull);
      expect(row.userData, isFalse);
      expect(row.emphasized, isFalse);

      await pumpThemed(
        tester,
        const MmDetailRow.amount(
          label: 'Advance',
          amount: Money.fromRupees(-5000),
          creditLabel: 'credit',
          emphasized: true,
        ),
      );
      expect(find.text('Rs\u00A05,000 credit'), findsOneWidget);
      expect(
        styleOf(tester, 'Rs\u00A05,000 credit').color,
        MmColorModes.light.credit,
      );
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: 'Advance, 5000 rupees credit'),
      );
      // A total's label is in the semibold title style, in ink.
      final label = styleOf(tester, 'Advance');
      final titleMedium = MmVariant.light.theme.textTheme.titleMedium!;
      expect(label.fontWeight, titleMedium.fontWeight);
      expect(label.color, MmColorModes.light.ink);
    });

    testWidgets('an amount does not break; it moves under its label', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmDetailRow.amount(
          label: 'Rent for October and November',
          amount: Money.fromRupees(125000),
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
        then: (_) {
          final label = tester.getRect(find.textContaining('Rent for October'));
          final amount = tester.getRect(find.byType(MmAmount));
          expect(amount.top, greaterThanOrEqualTo(label.bottom));
          // One line of 32 px text, at its full size.
          expect(amount.height, lessThan(2 * 32));
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets("at 200% a card's amounts end on one edge, moved or not", (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const Column(
          children: [
            MmDetailRow.amount(label: 'Rent', amount: Money.fromRupees(45000)),
            MmDetailRow.amount(
              label: 'Security deposit held',
              amount: Money.fromRupees(125000),
            ),
            MmDetailRow.amount(
              label: 'Electricity',
              amount: Money.fromRupees(3200),
            ),
            MmDetailRow(label: 'Due on', value: '5 Nov'),
          ],
        ),
        then: (locale) {
          final rows = find.byType(MmDetailRow);
          final rowRect = tester.getRect(rows.first);
          final values = [
            for (final amount in tester.widgetList<MmAmount>(
              find.byType(MmAmount),
            ))
              tester.getRect(find.byWidget(amount)),
            tester.getRect(find.byType(MmUserText)),
          ];
          final labels = [
            for (final label in [
              'Rent',
              'Security deposit held',
              'Electricity',
              'Due on',
            ])
              tester.getRect(find.text(label)),
          ];
          // Some values sit beside their labels and some had to move under
          // them, and every one ends on the row's end edge.
          final moved = [
            for (final (index, value) in values.indexed)
              value.top >= labels[index].bottom,
          ];
          expect(moved, containsAll([true, false]));
          for (final value in values) {
            if (locale.languageCode == 'ur') {
              expect(value.left, moreOrLessEquals(rowRect.left));
            } else {
              expect(value.right, moreOrLessEquals(rowRect.right));
            }
          }
        },
      );
    });

    testWidgets('moves a value that does not fit under its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: 'Property', value: _address),
      );
      final label = tester.getRect(find.text('Property'));
      final value = tester.getRect(find.text(_address));
      expect(value.top, label.bottom + MmSpace.s1);
      // Under its label a value keeps to the end edge, where the values
      // beside their labels end.
      expect(value.right, tester.getRect(find.byType(MmDetailRow)).right);
    });

    testWidgets('at 200% on a 320 dp phone, wraps in whole words without '
        'overflowing', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Column(
          children: [
            MmDetailRow(
              label: 'Property',
              value: _address,
              trailing: const MmStatusBadge(
                status: MmStatus.paid,
                label: 'Paid',
              ),
              action: _copy(),
            ),
            // The CNIC needs the whole width: the copy button moves under
            // it rather than break it.
            MmDetailRow(label: 'CNIC', value: _cnic, action: _copy()),
          ],
        ),
        then: (locale) {
          for (final row in find.byType(MmDetailRow).evaluate()) {
            expect(row.size!.width, 288);
          }
          final cnic = tester.getRect(find.textContaining(_cnic));
          final copy = tester.getRect(find.byType(IconButton).last);
          expect(copy.top, greaterThanOrEqualTo(cnic.bottom));
          if (locale.languageCode == 'en') {
            expect(
              copy.right,
              tester.getRect(find.byType(MmDetailRow).last).right,
            );
          }
        },
      );
    });

    testWidgets('a trailing widget that does not fit goes under the value, '
        'which never breaks for it', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmDetailRow(
          label: 'October rent',
          value: _value,
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      final value = tester.getRect(find.text(_value));
      final badge = tester.getRect(find.byType(MmStatusBadge));
      // One line of 32 px text: the amount is not split.
      expect(value.height, lessThan(2 * 32));
      expect(badge.top, greaterThanOrEqualTo(value.top));

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: _label,
          value: _value,
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      final row = tester.getRect(find.byType(MmDetailRow));
      final beside = tester.getRect(find.byType(MmStatusBadge));
      expect(beside.right, row.right);
      expect(beside.left, greaterThan(tester.getRect(find.text(_value)).right));
    });

    testWidgets('is one node reading "label, value"', (tester) async {
      await pumpThemed(tester, const MmDetailRow(label: _label, value: _value));
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: '$_label, $_value'),
      );

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: _label,
          value: _value,
          semanticValue: '45000 rupees',
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: '$_label, 45000 rupees\nPaid'),
      );
    });

    testWidgets('sets Latin user data in the Latin face, left to right, in '
        'the Urdu UI', (tester) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: 'کرایہ دار', value: 'Ali Raza'),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.latin),
      );
      expect(find.text('\u2066Ali Raza\u2069'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: 'کرایہ دار، Ali Raza'),
      );

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: 'کرایہ دار',
          value: 'Ali Raza',
          userData: false,
        ),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.urdu),
      );
      expect(find.text('Ali Raza'), findsOneWidget);
    });

    testWidgets('draws the narrow no-break space before AM as a no-break '
        'space', (tester) async {
      for (final userData in [true, false]) {
        await pumpThemed(
          tester,
          MmDetailRow(
            label: 'Paid at',
            value: '10:42\u202FAM',
            userData: userData,
          ),
        );
        expect(find.text('10:42\u00A0AM'), findsOneWidget);
      }
    });

    testWidgets("keeps a number's groups in order in the Urdu UI", (
      tester,
    ) async {
      const consumer = '0412 3345 6789';
      await pumpThemed(
        tester,
        const SizedBox(
          width: 300,
          child: MmDetailRow(label: 'صارف نمبر', value: consumer),
        ),
        variant: MmVariant.urdu,
      );
      final paragraph = paragraphOf(tester, consumer);
      final text = paragraph.text.toPlainText();
      double xOf(String group) => paragraph
          .getOffsetForCaret(
            TextPosition(offset: text.indexOf(group)),
            Rect.zero,
          )
          .dx;
      expect(xOf('0412'), lessThan(xOf('3345')));
      expect(xOf('3345'), lessThan(xOf('6789')));
    });

    testWidgets('an action is a separate control at the end of the row', (
      tester,
    ) async {
      var copies = 0;
      await pumpThemed(
        tester,
        MmDetailRow(
          label: 'CNIC',
          value: _cnic,
          trailing: const MmStatusBadge(
            status: MmStatus.paid,
            label: 'Verified',
          ),
          action: _copy(onPressed: () => copies++),
        ),
        // Wide enough for the row and its action side by side.
        size: const Size(480, 740),
      );
      expect(tester.takeException(), isNull);
      // The row reads its label, value and status; the action is its own
      // button.
      final row = tester.getSemantics(find.text('CNIC'));
      expect(row, matchesSemantics(label: 'CNIC, $_cnic\nVerified'));
      expect(
        tester.getSemantics(find.byType(IconButton)),
        matchesSemantics(
          tooltip: 'Copy',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      final box = tester.getRect(find.byType(MmDetailRow));
      expect(tester.getRect(find.byType(IconButton)).right, box.right);
      expect(
        tester.getRect(find.byType(IconButton)).left,
        greaterThan(tester.getRect(find.byType(MmStatusBadge)).right),
      );

      useKeyboardHighlights();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.byIcon(MmIcons.copy)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copies, 1);

      await pumpThemed(
        tester,
        MmDetailRow(label: 'CNIC', value: _cnic, action: _copy()),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getRect(find.byType(IconButton)).left,
        tester.getRect(find.byType(MmDetailRow)).left,
      );
    });

    testWidgets('reports a control in its trailing widget', (tester) async {
      await pumpThemed(
        tester,
        MmDetailRow(label: 'CNIC', value: _cnic, trailing: _copy()),
      );
      final message = (tester.takeException()! as FlutterError).toStringDeep();
      expect(
        message,
        contains('The trailing widget of an MmDetailRow holds a control.'),
      );
      expect(message, contains('Pass the control as the action of the row'));
    });
  });

  group('MmDetailRow.prose', () {
    const notes =
        'The tenant paid before the deadline and asked for the receipt '
        'by WhatsApp.';

    testEveryVariant('sets the label above and the passage under it from '
        'the start edge, across the whole width', (tester, variant) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 320,
          child: MmDetailRow.prose(label: 'Notes', value: notes),
        ),
        variant: variant,
      );
      final row = tester.getRect(find.byType(MmDetailRow));
      final label = tester.getRect(find.text('Notes'));
      final passage = paragraphOf(tester, notes);
      final rect = passage.localToGlobal(Offset.zero) & passage.size;
      expect(rect.top, greaterThanOrEqualTo(label.bottom));
      expect(rect.width, row.width);
      expect(passage.textAlign, TextAlign.start);
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      expect(styleOf(tester, 'Notes').color, colors.inkMuted);
      expect(styleOf(tester, 'Notes').fontSize, text.bodyMedium!.fontSize);
      expect(styleOf(tester, notes).color, colors.ink);
      expect(styleOf(tester, notes).fontSize, text.bodyLarge!.fontSize);
      // The label sits at the start edge too.
      if (variant.locale.languageCode == 'ur') {
        expect(label.right, row.right);
      } else {
        expect(label.left, row.left);
      }
    });

    testWidgets('sets an English passage in the Urdu UI left to right, '
        'every line from the left edge, in the Latin face, and reads it as '
        'written', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 240,
          child: MmDetailRow.prose(label: 'نوٹ', value: notes),
        ),
        variant: MmVariant.urdu,
      );
      final passage = paragraphOf(tester, notes);
      expect(passage.textDirection, TextDirection.ltr);
      expect(passage.text.toPlainText(), notes);
      expect(styleOf(tester, notes).fontFamily, contains(MmFontFamily.latin));
      // Every line starts at the left edge, where English starts.
      // The leftmost edge of each line's characters, by line.
      final lefts = <double, double>{};
      for (var offset = 0; offset < notes.length; offset++) {
        for (final box in passage.getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: offset + 1),
        )) {
          final top = box.top.roundToDouble();
          lefts[top] = lefts.containsKey(top)
              ? (lefts[top]! < box.left ? lefts[top]! : box.left)
              : box.left;
        }
      }
      expect(lefts.length, greaterThan(1), reason: 'it wraps');
      expect(lefts.values, everyElement(moreOrLessEquals(0, epsilon: 1)));
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: 'نوٹ، $notes'),
      );
    });

    testWidgets('sets a passage without letters in the UI direction', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow.prose(label: 'نوٹ', value: '2026-11-08'),
        variant: MmVariant.urdu,
      );
      // Nothing in it decides a direction: it runs with the Urdu UI, kept
      // apart left to right like any figures.
      final passage = paragraphOf(tester, '2026-11-08');
      expect(passage.textDirection, TextDirection.rtl);
      expect(passage.text.toPlainText(), '\u20662026-11-08\u2069');
    });

    testWidgets('is one node, read with its semantic value', (tester) async {
      await pumpThemed(
        tester,
        const MmDetailRow.prose(
          label: 'Description',
          value: 'Leaking tap',
          semanticValue: 'Leaking tap in the kitchen',
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: 'Description, Leaking tap in the kitchen'),
      );
    });

    testWidgets("sets words from the app's localisations as they are", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow.prose(
          label: 'نوٹ',
          value: 'PDF رسید بھیج دی گئی',
          userData: false,
        ),
        variant: MmVariant.urdu,
      );
      // Not isolated, though it starts with a Latin word.
      expect(find.text('PDF رسید بھیج دی گئی'), findsOneWidget);
    });
  });
}
