import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../../support/testing.dart';

final _mobile = PhoneNumber.fromE164('+923001234567');

/// The size the glyph of the first [icon] is drawn at.
double _glyphSize(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find
          .descendant(
            of: find.byIcon(icon).first,
            matching: find.byType(RichText),
          )
          .first,
    )
    .text
    .style!
    .fontSize!;

/// The field's error line, if it shows one.
Finder _error(String text) => find.textContaining(text, findRichText: true);

void main() {
  group('MmValueEntry', () {
    test('tells an empty field from a typo and a value', () {
      const empty = MmValueEntry<PhoneNumber>(text: '', value: null);
      const spaces = MmValueEntry<PhoneNumber>(text: '  ', value: null);
      const typo = MmValueEntry<PhoneNumber>(text: '0300 12', value: null);
      final valid = MmValueEntry(text: '0300 1234567', value: _mobile);
      expect(
        (empty.isEmpty, empty.isValid, empty.isInvalid),
        (true, false, false),
      );
      expect(spaces.isEmpty, isTrue);
      expect(spaces.isInvalid, isFalse);
      expect(
        (typo.isEmpty, typo.isValid, typo.isInvalid),
        (false, false, true),
      );
      expect(
        (valid.isEmpty, valid.isValid, valid.isInvalid),
        (false, true, false),
      );
    });

    test('has value equality and says what it holds', () {
      expect(
        MmValueEntry(text: '0300 1234567', value: _mobile),
        MmValueEntry(text: '0300 1234567', value: _mobile),
      );
      expect(
        MmValueEntry(text: '0300 1234567', value: _mobile).hashCode,
        MmValueEntry(text: '0300 1234567', value: _mobile).hashCode,
      );
      expect(
        const MmValueEntry<PhoneNumber>(text: '0300 12', value: null),
        isNot(const MmValueEntry<PhoneNumber>(text: '0300 1', value: null)),
      );
      expect(
        const MmValueEntry<PhoneNumber>(
          text: '0300 12',
          value: null,
        ).toString(),
        'MmValueEntry("0300 12", null)',
      );
    });
  });

  group('an optional phone field', () {
    testWidgets('reports every text with its value, so a typo is not taken '
        'for no phone', (tester) async {
      final entries = <MmValueEntry<PhoneNumber>>[];
      final values = <PhoneNumber?>[];
      await pumpThemed(
        tester,
        MmPhoneField(
          label: 'Mobile number',
          optional: true,
          onChanged: values.add,
          onEntryChanged: entries.add,
        ),
      );
      await tester.enterText(find.byType(TextField), '030012');
      await tester.enterText(find.byType(TextField), '03001234567');
      await tester.enterText(find.byType(TextField), '');
      expect(entries, [
        const MmValueEntry<PhoneNumber>(text: '0300 12', value: null),
        MmValueEntry(text: '0300 1234567', value: _mobile),
        const MmValueEntry<PhoneNumber>(text: '', value: null),
      ]);
      expect(entries.first.isInvalid, isTrue);
      expect(entries.last.isEmpty, isTrue);
      // onChanged alone cannot tell the typo from the empty field.
      expect(values, [_mobile, null]);
    });

    testWidgets('shows invalidText for a typo when the form validates, and '
        'nothing for an empty field', (tester) async {
      final form = GlobalKey<FormState>();
      final asked = <PhoneNumber?>[];
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: MmPhoneField(
            label: 'Mobile number',
            optional: true,
            invalidText: 'Enter a whole mobile number',
            validator: (phone) {
              asked.add(phone);
              return null;
            },
            onChanged: (_) {},
          ),
        ),
      );
      expect(form.currentState!.validate(), isTrue);
      expect(asked, [null]);

      await tester.enterText(find.byType(TextField), '030012');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(_error('Enter a whole mobile number'), findsOneWidget);
      // The validator is not asked about a typo.
      expect(asked, [null]);

      await tester.enterText(find.byType(TextField), '03001234567');
      expect(form.currentState!.validate(), isTrue);
      await tester.pump();
      expect(_error('Enter a whole mobile number'), findsNothing);
      expect(asked, [null, _mobile]);
    });

    testWidgets('without invalidText, the validator gets null for a typo as '
        'before', (tester) async {
      final form = GlobalKey<FormState>();
      final asked = <PhoneNumber?>[];
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: MmPhoneField(
            label: 'Mobile number',
            validator: (phone) {
              asked.add(phone);
              return phone == null ? 'Enter the mobile number' : null;
            },
            onChanged: (_) {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '030012');
      expect(form.currentState!.validate(), isFalse);
      expect(asked, [null]);
    });
  });

  group('the CNIC and money fields', () {
    testWidgets('take invalidText and report entries too', (tester) async {
      final form = GlobalKey<FormState>();
      final cnics = <MmValueEntry<Cnic>>[];
      final amounts = <MmValueEntry<Money>>[];
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: Column(
            children: [
              MmCnicField(
                label: 'CNIC',
                optional: true,
                invalidText: 'Enter all 13 digits',
                onChanged: (_) {},
                onEntryChanged: cnics.add,
              ),
              MmMoneyField(
                label: 'Rent',
                max: const Money.fromRupees(100000),
                invalidText: 'Enter at most Rs 1,00,000',
                onChanged: (_) {},
                onEntryChanged: amounts.add,
              ),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '35202');
      await tester.enterText(find.byType(TextField).last, '200000');
      expect(cnics.single.isInvalid, isTrue);
      expect(amounts.single.isInvalid, isTrue);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(_error('Enter all 13 digits'), findsOneWidget);
      expect(_error('Enter at most Rs 1,00,000'), findsOneWidget);
    });
  });

  group('errorText', () {
    testWidgets('wins over the validator, fails the form and stays until it '
        'is cleared', (tester) async {
      final form = GlobalKey<FormState>();
      var asked = 0;
      String? serverError = 'Wrong password';
      late StateSetter setOuter;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return Form(
              key: form,
              child: MmPasswordField(
                label: 'Password',
                errorText: serverError,
                validator: (_) {
                  asked++;
                  return null;
                },
              ),
            );
          },
        ),
      );
      expect(_error('Wrong password'), findsOneWidget);
      expect(form.currentState!.validate(), isFalse);
      expect(asked, 0);

      await tester.enterText(find.byType(TextField), 'kiraya2026');
      await tester.pump();
      expect(_error('Wrong password'), findsOneWidget);

      setOuter(() => serverError = null);
      await tester.pump();
      expect(_error('Wrong password'), findsNothing);
      expect(form.currentState!.validate(), isTrue);
      expect(asked, 1);
    });
  });

  group('MmTextField', () {
    testWidgets('with leftToRight, reads left to right at the start edge of '
        'an Urdu form', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(
          label: 'ای میل',
          initialValue: 'ali.raza@example.pk',
          leftToRight: true,
        ),
        variant: MmVariant.urdu,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.right);
    });

    testWidgets('by default follows the text', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'نام', initialValue: 'Ali Raza'),
        variant: MmVariant.urdu,
      );
      // A name typed in English runs left to right from its first letter,
      // at the start edge of the Urdu form.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.right);
    });

    for (final (variant, size) in [
      (MmVariant.light, MmSize.iconLg),
      (MmVariant.largeText, MmSize.iconLg * MmIconLabel.maxIconScale),
    ]) {
      testWidgets('grows its icons with the text (${variant.name})', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const MmTextField(
            label: 'Search tenants',
            prefixIcon: MmIcons.search,
            suffix: Icon(MmIcons.close),
          ),
          variant: variant,
        );
        expect(_glyphSize(tester, MmIcons.search), size);
        expect(_glyphSize(tester, MmIcons.close), size);
      });
    }
  });

  group('show and hide buttons', () {
    for (final (variant, size) in [
      (MmVariant.light, MmSize.iconLg),
      (MmVariant.largeText, MmSize.iconLg * MmIconLabel.maxIconScale),
    ]) {
      testWidgets('grow their glyph with the text (${variant.name})', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          Column(
            children: [
              const MmPasswordField(label: 'Password'),
              MmCnicText(cnic: Cnic.parse('35202-1234567-1')),
            ],
          ),
          variant: variant,
          size: const Size(360, 900),
        );
        expect(_glyphSize(tester, MmIcons.show), size);
      });
    }
  });
}
