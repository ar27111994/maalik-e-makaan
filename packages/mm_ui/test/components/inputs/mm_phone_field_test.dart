import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'editing.dart';

final _mobile = PhoneNumber.fromE164('+923001234567');

/// A phone field whose value its parent keeps, as an app would.
class _Host extends StatefulWidget {
  const new({this.initial, this.changes});

  final PhoneNumber? initial;
  final List<PhoneNumber?>? changes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late PhoneNumber? value = widget.initial;

  void set(PhoneNumber? next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => MmPhoneField(
    label: 'Mobile number',
    value: value,
    onChanged: (phone) {
      widget.changes?.add(phone);
      set(phone);
    },
  );
}

PhoneNumber? _value(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host)).value;

void main() {
  group('MmPhoneField typing', () {
    testWidgets('shows a mobile number in the national format', (tester) async {
      final changes = <PhoneNumber?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '0300');
      expect(valueOf(tester).text, '0300');
      await tester.enterText(find.byType(TextField), '03001');
      expect(valueOf(tester).text, '0300 1');
      await tester.enterText(find.byType(TextField), '03001234567');
      expect(valueOf(tester).text, '0300 1234567');
      expect(changes, [_mobile]);
      expect(changes.single!.e164, '+923001234567');
    });

    for (final (written, how) in [
      ('+923001234567', 'with +92'),
      ('0092 300 1234567', 'with 0092'),
      ('923001234567', 'with 92'),
      ('3001234567', 'without the trunk 0'),
      ('۰۳۰۰۱۲۳۴۵۶۷', 'in Urdu digits'),
      ('0300-123 4567', 'with dashes and spaces'),
      ('Tel: +92 300 1234567', 'pasted with words'),
    ]) {
      testWidgets('accepts a Pakistani number written $how', (tester) async {
        await pumpThemed(tester, const _Host());
        await tester.enterText(find.byType(TextField), written);
        expect(valueOf(tester).text, '0300 1234567');
        expect(valueOf(tester).selection.baseOffset, 12);
        expect(_value(tester), _mobile);
      });
    }

    testWidgets('keeps an international form until the number is complete', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '+');
      expect(valueOf(tester).text, '+');
      await tester.enterText(find.byType(TextField), '+92 300 123456');
      expect(valueOf(tester).text, '+92300123456');
      expect(_value(tester), isNull);
      await tester.enterText(find.byType(TextField), '+923001234567');
      expect(valueOf(tester).text, '0300 1234567');
    });

    testWidgets('a landline is one run of digits', (tester) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '042 3576 1234');
      expect(valueOf(tester).text, '04235761234');
      expect(_value(tester)!.type, PhoneNumberType.landline);
      await tester.enterText(find.byType(TextField), '042123456789');
      expect(valueOf(tester).text, '042123456789');
      await tester.enterText(find.byType(TextField), '0421234567890');
      expect(valueOf(tester).text, '042123456789');
    });

    testWidgets('a number abroad keeps its plus and country code', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '+44 7700 900123');
      expect(valueOf(tester).text, '+447700900123');
      expect(_value(tester)!.type, PhoneNumberType.international);
      await tester.enterText(find.byType(TextField), '+123456789012345');
      expect(valueOf(tester).text, '+123456789012345');
      await tester.enterText(find.byType(TextField), '+1234567890123456');
      expect(valueOf(tester).text, '+123456789012345');
      await tester.enterText(find.byType(TextField), '00123456789012345');
      expect(valueOf(tester).text, '00123456789012345');
      await tester.enterText(find.byType(TextField), '001234567890123456');
      expect(valueOf(tester).text, '00123456789012345');
    });

    testWidgets('a plus counts only at the start', (tester) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '12+3');
      expect(valueOf(tester).text, '123');
      await tester.enterText(find.byType(TextField), '300123');
      expect(valueOf(tester).text, '300123');
    });

    testWidgets('stops a mobile number at 11 digits', (tester) async {
      await pumpThemed(tester, _Host(initial: _mobile));
      await tester.enterText(find.byType(TextField), '030012345678');
      expect(valueOf(tester).text, '0300 1234567');
    });

    testWidgets('backspace just after the space deletes the digit before', (
      tester,
    ) async {
      await pumpThemed(tester, _Host(initial: _mobile));
      await edit(tester, '0300 1234567', caret: 5);
      await edit(tester, '03001234567', caret: 4);
      expect(valueOf(tester).text, '0301 234567');
      expect(valueOf(tester).selection.baseOffset, 3);
    });

    testWidgets('keeps the caret beside the digit typed', (tester) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '03001');
      // "030|0 1" -> type 5 -> "0305| 01".
      await edit(tester, '03050 1', caret: 4);
      expect(valueOf(tester).text, '0305 01');
      expect(valueOf(tester).selection.baseOffset, 4);
    });
  });

  group('MmPhoneField value', () {
    testWidgets('shows a value nationally and replaces it when it changes', (
      tester,
    ) async {
      await pumpThemed(tester, _Host(initial: _mobile));
      expect(valueOf(tester).text, '0300 1234567');
      final host = tester.state<_HostState>(find.byType(_Host))
        ..set(PhoneNumber.fromE164('+447700900123'));
      await tester.pump();
      expect(valueOf(tester).text, '+447700900123');
      host.set(null);
      await tester.pump();
      expect(valueOf(tester).text, '');
    });
  });

  group('MmPhoneField presentation', () {
    testEveryVariant('a phone keyboard, autofill and the Latin face', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _Host(initial: _mobile), variant: variant);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.autofillHints, [AutofillHints.telephoneNumber]);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.fontFamily, contains(MmFontFamily.latin));
      expect(editable.textDirection, TextDirection.ltr);
      expect(
        editable.textAlign,
        variant == MmVariant.urdu ? TextAlign.right : TextAlign.left,
      );
    });

    testWidgets('is labelled and read digit by digit', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        MmPhoneField(
          label: 'Mobile number',
          value: _mobile,
          optional: true,
          onChanged: (_) {},
        ),
      );
      final node = tester.getSemantics(find.byType(EditableText));
      expect(
        node,
        isSemantics(
          label: 'Mobile number',
          value: '0300 1234567',
          hint: 'Optional',
          isTextField: true,
        ),
      );
      expect(
        node.attributedValue.attributes,
        contains(isA<SpellOutStringAttribute>()),
      );
      handle.dispose();
    });

    testWidgets('passes its settings to the field', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        MmPhoneField(
          label: 'Mobile number',
          required: true,
          helper: 'Rent reminders are sent to this number',
          errorText: 'Not a mobile number',
          focusNode: focus,
          textInputAction: TextInputAction.done,
          enabled: false,
          onChanged: (_) {},
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, focus);
      expect(field.textInputAction, TextInputAction.done);
      expect(field.enabled, isFalse);
      expect(
        find.textContaining('Not a mobile number', findRichText: true),
        findsOne,
      );
    });

    test('a field is not both required and optional', () {
      expect(
        () => MmPhoneField(
          label: 'Phone',
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
        MmPhoneField(
          label: "Tenant's mobile number for reminders",
          value: PhoneNumber.fromE164('+447700900123'),
          required: true,
          helper: 'Rent reminders are sent to this number on WhatsApp',
          onChanged: (_) {},
        ),
      );
    });

    testWidgets('a mobile and a number abroad show whole at 200% on a '
        '320 dp phone', (tester) async {
      await expectWholeValues(
        tester,
        Column(
          children: [
            MmPhoneField(
              label: 'Mobile number',
              value: _mobile,
              onChanged: (_) {},
            ),
            MmPhoneField(
              label: 'Number abroad',
              value: PhoneNumber.fromE164('+447700900123'),
              onChanged: (_) {},
            ),
          ],
        ),
        check: (locale) async {
          for (final field in find.byType(MmPhoneField).evaluate()) {
            // They fit at the reader's size: nothing is set smaller.
            expect(
              textScaleOf(tester, find.byWidget(field.widget)),
              2,
              reason: locale.languageCode,
            );
          }
        },
      );
    });

    testWidgets('the longest number shows whole, set only as small as it '
        'needs', (tester) async {
      await expectWholeValues(
        tester,
        const _Host(),
        check: (locale) async {
          await tester.enterText(find.byType(TextField), '00123456789012345');
          await tester.pumpAndSettle();
          final editable = renderEditableOf(tester);
          expect(
            editable.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(editable.size.width),
          );
          expect(textScaleOf(tester), inExclusiveRange(1, 2));
        },
      );
    });

    testWidgets('submits, validates and takes focus like a text field', (
      tester,
    ) async {
      final form = GlobalKey<FormState>();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final submitted = <PhoneNumber?>[];
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: MmPhoneField(
            label: 'Mobile number',
            focusNode: focus,
            autofocus: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (phone) =>
                phone?.type == PhoneNumberType.mobile ? null : 'Not a mobile',
            onSubmitted: submitted.add,
            onChanged: (_) {},
          ),
        ),
      );
      expect(focus.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), '042 3576 1234');
      await tester.pump();
      expect(find.textContaining('Not a mobile', findRichText: true), findsOne);
      await tester.enterText(find.byType(TextField), '03001234567');
      await tester.pump();
      expect(
        find.textContaining('Not a mobile', findRichText: true),
        findsNothing,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, [_mobile]);
    });
  });
}
