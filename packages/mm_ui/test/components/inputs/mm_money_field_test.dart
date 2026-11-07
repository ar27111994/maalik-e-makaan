import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/inputs/mm_value_field.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../../support/testing.dart';
import 'editing.dart';

const _rent = Money.fromRupees(125000);

/// A money field whose value its parent keeps, as an app would.
class _Host extends StatefulWidget {
  const new({
    this.initial,
    this.max,
    this.allowZero = true,
    this.format,
    this.changes,
    super.key,
  });

  final Money? initial;
  final Money? max;
  final bool allowZero;
  final MoneyFormat? format;
  final List<Money?>? changes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Money? value = widget.initial;

  void set(Money? next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) {
    final field = MmMoneyField(
      label: 'Monthly rent',
      value: value,
      max: widget.max,
      allowZero: widget.allowZero,
      onChanged: (amount) {
        widget.changes?.add(amount);
        set(amount);
      },
    );
    final format = widget.format;
    return format == null ? field : MmFormats(money: format, child: field);
  }
}

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

void main() {
  group('MmMoneyField display', () {
    testWidgets('groups the amount the way the app set', (tester) async {
      await pumpThemed(tester, const _Host(initial: _rent));
      expect(valueOf(tester).text, '125,000');

      await pumpThemed(
        tester,
        const _Host(
          initial: _rent,
          format: MoneyFormat(grouping: DigitGrouping.southAsian),
        ),
      );
      expect(valueOf(tester).text, '1,25,000');
    });

    testWidgets('lays the text out again when the grouping changes', (
      tester,
    ) async {
      Widget build(DigitGrouping grouping) => MmFormats(
        money: MoneyFormat(grouping: grouping),
        child: MmMoneyField(
          label: 'Monthly rent',
          value: _rent,
          onChanged: (_) {},
        ),
      );
      await pumpThemed(tester, build(DigitGrouping.western));
      expect(valueOf(tester).text, '125,000');
      await tester.pumpWidget(themed(build(DigitGrouping.southAsian)));
      expect(valueOf(tester).text, '1,25,000');
    });

    testWidgets('writes paisa only when there are some', (tester) async {
      await pumpThemed(tester, _Host(initial: Money.parseDecimal('2350.5')));
      expect(valueOf(tester).text, '2,350.50');
    });

    testWidgets('shows "Rs" before the amount in English', (tester) async {
      await pumpThemed(tester, const _Host());
      expect(find.text('Rs'), findsOneWidget);
      expect(
        tester.getRect(find.text('Rs')).right,
        lessThan(tester.getRect(find.byType(EditableText)).left),
      );
    });

    testWidgets('shows "روپے" after the amount in Urdu, against it', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmMoneyField(label: 'کرایہ', value: _rent, onChanged: (_) {}),
        variant: MmVariant.urdu,
      );
      expect(find.text('Rs'), findsNothing);
      expect(find.text('روپے'), findsOneWidget);
      // After the amount in reading order: to its left in right to left.
      final marker = tester.getRect(find.text('روپے'));
      final box = tester.getRect(find.byType(EditableText));
      expect(marker.right, lessThan(box.left));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textDirection, TextDirection.ltr);
      // The amount sits against the marker, not across the field from it:
      // its first figure is about a space's width from the marker.
      expect(editable.textAlign, TextAlign.left);
      final firstFigure = renderEditableOf(tester)
          .getLocalRectForCaret(const TextPosition(offset: 0));
      expect(box.left + firstFigure.left - marker.right, lessThan(MmSpace.s3));
    });

    testEveryVariant('the marker sits on the line of the amount', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, const _Host(initial: _rent), variant: variant);
      final marker = variant == MmVariant.urdu ? 'روپے' : 'Rs';
      double baselineOf(RenderBox box) =>
          box.localToGlobal(Offset.zero).dy +
          box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
      expect(
        baselineOf(paragraphOf(tester, marker)),
        moreOrLessEquals(baselineOf(renderEditableOf(tester)), epsilon: 0.01),
      );
      // The same line box: neither makes the field taller.
      expect(
        tester.getSize(find.text(marker)).height,
        moreOrLessEquals(renderEditableOf(tester).size.height),
      );
    });

    testWidgets('follows the currency style of the money format', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const _Host(format: MoneyFormat(currency: CurrencyDisplay.code)),
      );
      expect(find.text('PKR'), findsOneWidget);

      await pumpThemed(
        tester,
        const _Host(format: MoneyFormat(currency: CurrencyDisplay.none)),
      );
      expect(find.text('Rs'), findsNothing);
      expect(find.text('PKR'), findsNothing);

      await pumpThemed(
        tester,
        const _Host(format: MoneyFormat(language: MoneyLanguage.urdu)),
      );
      expect(find.text('روپے'), findsOneWidget);
    });

    testWidgets('always writes Western digits and the full amount', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const _Host(
          initial: Money.fromRupees(2350000),
          format: MoneyFormat(
            language: MoneyLanguage.urdu,
            nativeDigits: true,
            notation: MoneyNotation.compact,
          ),
        ),
      );
      expect(valueOf(tester).text, '2,350,000');
    });

    testEveryVariant('sets amounts in the Latin face with tabular figures', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, const _Host(initial: _rent), variant: variant);
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.color, colorsOf(variant).ink);
    });
  });

  group('MmMoneyField typing', () {
    testWidgets('groups digits as they are typed', (tester) async {
      final changes = <Money?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '125000');
      expect(valueOf(tester).text, '125,000');
      expect(valueOf(tester).selection.baseOffset, 7);
      expect(changes, [_rent]);
    });

    testWidgets('keeps the caret beside the digit typed', (tester) async {
      await pumpThemed(tester, const _Host(initial: _rent));
      // "1|25,000" -> type 9 -> "1,9|25,000".
      await edit(tester, '1925,000', caret: 2);
      expect(valueOf(tester).text, '1,925,000');
      expect(valueOf(tester).selection.baseOffset, 3);
      expect(_host(tester).value, const Money.fromRupees(1925000));
    });

    testWidgets('backspace just after a comma deletes the digit before it', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host(initial: _rent));
      await edit(tester, '125,000', caret: 4);
      await edit(tester, '125000', caret: 3);
      expect(valueOf(tester).text, '12,000');
      expect(valueOf(tester).selection.baseOffset, 2);
    });

    testWidgets('delete just before a comma deletes the digit after it', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host(initial: _rent));
      await edit(tester, '125,000', caret: 3);
      await edit(tester, '125000', caret: 3);
      expect(valueOf(tester).text, '12,500');
      expect(valueOf(tester).selection.baseOffset, 4);
    });

    testWidgets('accepts Urdu digits and the Arabic decimal separator', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '۴۵۰۰۰');
      expect(valueOf(tester).text, '45,000');
      expect(_host(tester).value, const Money.fromRupees(45000));
      await tester.enterText(find.byType(TextField), '۱۵۰۰٫۵');
      expect(valueOf(tester).text, '1,500.5');
      expect(_host(tester).value, Money.parseDecimal('1500.50'));
    });

    testWidgets('turns pasted text into the amount', (tester) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), 'Rs 1,25,000');
      expect(valueOf(tester).text, '125,000');
      expect(valueOf(tester).selection.baseOffset, 7);
      expect(_host(tester).value, _rent);
      await tester.enterText(find.byType(TextField), '1.5 lakh');
      expect(valueOf(tester).text, '150,000');
      // Words that are not an amount are refused.
      await tester.enterText(find.byType(TextField), 'abc');
      expect(valueOf(tester).text, '150,000');
      await tester.enterText(find.byType(TextField), 'Rs -500');
      expect(valueOf(tester).text, '150,000');
    });

    testWidgets('keeps more than two decimals as typed but reports null', (
      tester,
    ) async {
      final changes = <Money?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '1500.5');
      await tester.enterText(find.byType(TextField), '1500.505');
      expect(valueOf(tester).text, '1,500.505');
      await tester.enterText(find.byType(TextField), '1500.');
      expect(valueOf(tester).text, '1,500.');
      expect(changes, [
        Money.parseDecimal('1500.5'),
        null,
        const Money.fromRupees(1500),
      ]);
    });

    testWidgets('refuses a second decimal point and absurd lengths', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '15.5');
      await tester.enterText(find.byType(TextField), '15.5.');
      expect(valueOf(tester).text, '15.5');
      await tester.enterText(find.byType(TextField), '123456789012');
      expect(valueOf(tester).text, '123,456,789,012');
      await tester.enterText(find.byType(TextField), '1234567890123');
      expect(valueOf(tester).text, '123,456,789,012');
    });

    testWidgets('drops leading zeros and writes a zero before a point', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '007');
      expect(valueOf(tester).text, '7');
      await tester.enterText(find.byType(TextField), '00');
      expect(valueOf(tester).text, '0');
      await tester.enterText(find.byType(TextField), '0.5');
      expect(valueOf(tester).text, '0.5');
      await tester.enterText(find.byType(TextField), '.5');
      expect(valueOf(tester).text, '0.5');
      expect(valueOf(tester).selection.baseOffset, 3);
      await tester.enterText(find.byType(TextField), '');
      expect(valueOf(tester).text, '');
      expect(_host(tester).value, isNull);
    });

    testWidgets('refuses letters typed among the digits, drops spaces', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host(initial: Money.fromRupees(4500)));
      await edit(tester, '4,5a00', caret: 4);
      expect(valueOf(tester).text, '4,500');
      expect(_host(tester).value, const Money.fromRupees(4500));
      await edit(tester, '4,5 00', caret: 4);
      expect(valueOf(tester).text, '4,500');
      expect(valueOf(tester).selection.baseOffset, 3);
    });
  });

  group('MmMoneyField limits', () {
    testWidgets('reports null above the maximum', (tester) async {
      final changes = <Money?>[];
      await pumpThemed(
        tester,
        _Host(max: const Money.fromRupees(50000), changes: changes),
      );
      await tester.enterText(find.byType(TextField), '40000');
      await tester.enterText(find.byType(TextField), '60000');
      expect(valueOf(tester).text, '60,000');
      await tester.enterText(find.byType(TextField), '50000');
      expect(changes, [
        const Money.fromRupees(40000),
        null,
        const Money.fromRupees(50000),
      ]);
    });

    testWidgets('reports null for zero unless zero is allowed', (tester) async {
      final changes = <Money?>[];
      await pumpThemed(tester, _Host(allowZero: false, changes: changes));
      await tester.enterText(find.byType(TextField), '5');
      await tester.enterText(find.byType(TextField), '0');
      expect(changes, [const Money.fromRupees(5), null]);

      changes.clear();
      await pumpThemed(tester, _Host(changes: changes, key: UniqueKey()));
      await tester.enterText(find.byType(TextField), '0');
      expect(changes, [Money.zero]);
    });

    testWidgets('takes no negative amount: a credit is said in words', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host(initial: Money.fromRupees(-500)));
      expect(
        tester.takeException(),
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('zero or more'),
        ),
      );
    });
  });

  group('MmMoneyField value', () {
    testWidgets('a new value from outside replaces the text', (tester) async {
      await pumpThemed(tester, const _Host());
      _host(tester).set(const Money.fromRupees(2500));
      await tester.pump();
      expect(valueOf(tester).text, '2,500');
      _host(tester).set(null);
      await tester.pump();
      expect(valueOf(tester).text, '');
    });

    testWidgets('the value it reported does not rewrite what was typed', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '1500.5');
      await tester.pump();
      expect(_host(tester).value, Money.parseDecimal('1500.50'));
      expect(valueOf(tester).text, '1,500.5');
    });

    testWidgets('reports a change only when the amount changes', (
      tester,
    ) async {
      final changes = <Money?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '1500');
      await tester.enterText(find.byType(TextField), '1500.');
      await tester.enterText(find.byType(TextField), '1500.0');
      expect(changes, [const Money.fromRupees(1500)]);
    });
  });

  group('MmMoneyField semantics', () {
    testWidgets('a screen reader hears the plain number and the currency', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const _Host(initial: _rent));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Monthly rent',
          value: '125000 rupees',
          isTextField: true,
        ),
      );
      // The marker is not read on its own.
      expect(find.semantics.byLabel('Rs'), findsNothing);

      await tester.enterText(find.byType(TextField), '1500.5');
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(value: '1500.50 rupees'),
      );
      // Text that is not an amount is read as shown.
      await tester.enterText(find.byType(TextField), '1500.505');
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(value: '1,500.505'),
      );
      handle.dispose();
    });

    testWidgets('an empty field says the amount is in rupees', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const _Host());
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Monthly rent', value: '', hint: 'rupees'),
      );
      await tester.enterText(find.byType(TextField), '45000');
      await tester.pump();
      // Once there is an amount, it is read with the currency instead.
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(value: '45000 rupees', hint: ''),
      );
      handle.dispose();
    });

    testWidgets('in Urdu, with the Urdu word for rupees', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        MmMoneyField(
          label: 'ماہانہ کرایہ',
          value: _rent,
          required: true,
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'ماہانہ کرایہ',
          value: '125000 روپے',
          hint: 'لازمی',
          isRequired: true,
        ),
      );
      handle.dispose();
    });

    test('reads composing text as shown, keeping its underline', () {
      final controller = MmFieldController(
        text: '1500',
        describe: (_, text) => '$text rupees',
      );
      addTearDown(controller.dispose);
      final context = _FakeContext();
      var span = controller.buildTextSpan(
        context: context,
        withComposing: true,
      );
      expect(span.semanticsLabel, '1500 rupees');
      expect(span.spellOut, isNull);

      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 0, end: 4),
      );
      span = controller.buildTextSpan(context: context, withComposing: true);
      expect(span.semanticsLabel, isNull);
      expect(span.children, hasLength(3));

      controller.spellOut = true;
      span = controller.buildTextSpan(context: context, withComposing: false);
      expect(span.spellOut, isTrue);
    });
  });

  group('MmMoneyField settings', () {
    testWidgets('a decimal keyboard, focus and the keyboard action', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        MmMoneyField(
          label: 'Monthly rent',
          focusNode: focus,
          textInputAction: TextInputAction.next,
          helper: 'As agreed in the lease',
          errorText: 'Enter the rent',
          optional: true,
          onChanged: (_) {},
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(field.textInputAction, TextInputAction.next);
      expect(field.focusNode, focus);
      expect(
        find.textContaining('Enter the rent', findRichText: true),
        findsOne,
      );
      expect(find.textContaining('Optional', findRichText: true), findsOne);
    });

    testWidgets('a disabled field mutes the amount', (tester) async {
      await pumpThemed(
        tester,
        MmMoneyField(
          label: 'Electricity bill',
          value: _rent,
          enabled: false,
          onChanged: (_) {},
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.color,
        MmColorModes.light.inkMuted,
      );
    });

    test('a field is not both required and optional', () {
      expect(
        () => MmMoneyField(
          label: 'Rent',
          required: true,
          optional: true,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('fits 200% text on a 320 dp wide screen', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        MmMoneyField(
          label: 'Security deposit held for the ground floor',
          value: Money.parseDecimal('99999999999.99'),
          required: true,
          helper: 'Returned when the tenant moves out',
          errorText: 'More than the agreed deposit',
          onChanged: (_) {},
        ),
      );
    });

    testWidgets('a crore shows whole at 200% on a 320 dp phone, unshrunk', (
      tester,
    ) async {
      await expectWholeValues(
        tester,
        Builder(
          builder: (context) => MmFormats(
            money: MmFormats.defaultFor(Localizations.localeOf(context))
                .copyWith(grouping: DigitGrouping.southAsian),
            child: MmMoneyField(
              label: 'Security deposit',
              value: const Money.fromRupees(12500000),
              onChanged: (_) {},
            ),
          ),
        ),
        check: (locale) async {
          expect(valueOf(tester).text, '1,25,00,000');
          expect(textScaleOf(tester), 2, reason: locale.languageCode);
          // The currency marker grows only to 150%, leaving the figures
          // their room.
          final marker = locale.languageCode == 'ur' ? 'روپے' : 'Rs';
          expect(
            tester.widget<Text>(find.text(marker)).textScaler,
            const TextScaler.linear(MmIconLabel.maxIconScale),
          );
        },
      );
    });

    testWidgets('the largest amount shows whole, set only as small as it '
        'needs', (tester) async {
      final scales = <double>[];
      for (final grouping in DigitGrouping.values) {
        await expectWholeValues(
          tester,
          Builder(
            builder: (context) => MmFormats(
              money: MmFormats.defaultFor(Localizations.localeOf(context))
                  .copyWith(grouping: grouping),
              child: MmMoneyField(
                label: 'Security deposit',
                value: Money.maxValue,
                helper: 'Returned when the tenant moves out',
                onChanged: (_) {},
              ),
            ),
          ),
          check: (locale) async {
            final scale = textScaleOf(tester);
            scales.add(scale);
            // Smaller than the reader's 200%, larger than the 100% text.
            expect(scale, inExclusiveRange(1, 2));
            // Set any larger, it would not fit.
            final editable = renderEditableOf(tester);
            expect(
              editable.getMaxIntrinsicWidth(double.infinity) * 1.01,
              greaterThan(editable.size.width),
            );
            // The helper keeps the reader's size.
            expect(
              MediaQuery.textScalerOf(
                tester.element(find.text('Returned when the tenant moves out')),
              ).scale(1),
              2,
            );
          },
        );
      }
      expect(scales, hasLength(4));
    });

    testWidgets('a field narrower than a phone sets a value no smaller than '
        'a caption', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 120,
          child: MmMoneyField(
            label: 'Rent',
            value: Money.maxValue,
            onChanged: (_) {},
          ),
        ),
        variant: MmVariant.largeText,
      );
      expect(
        textScaleOf(tester) * MmTypeScale.latinTitleSmall.fontSize!,
        moreOrLessEquals(MmTypeScale.latinCaption.fontSize!),
      );
    });

    testWidgets('submits, validates and takes focus like a text field', (
      tester,
    ) async {
      final form = GlobalKey<FormState>();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final submitted = <Money?>[];
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: MmMoneyField(
            label: 'Monthly rent',
            focusNode: focus,
            autofocus: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (amount) => amount == null ? 'Enter the rent' : null,
            onSubmitted: submitted.add,
            onChanged: (_) {},
          ),
        ),
      );
      expect(focus.hasFocus, isTrue);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.textContaining('Enter the rent', findRichText: true),
        findsOne,
      );
      await tester.enterText(find.byType(TextField), '45000');
      await tester.pump();
      expect(
        find.textContaining('Enter the rent', findRichText: true),
        findsNothing,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, [const Money.fromRupees(45000)]);
      // Text that is not an acceptable amount is checked as no amount.
      await tester.enterText(find.byType(TextField), '1500.505');
      await tester.pump();
      expect(
        find.textContaining('Enter the rent', findRichText: true),
        findsOne,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, [const Money.fromRupees(45000), null]);
    });
  });
}

class _FakeContext extends Fake implements BuildContext;
