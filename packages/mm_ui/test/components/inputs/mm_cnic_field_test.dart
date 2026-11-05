import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'editing.dart';

final _cnic = Cnic.parse('35202-1234567-1');

/// A CNIC field whose value its parent keeps, as an app would.
class _Host extends StatefulWidget {
  const new({this.initial, this.changes});

  final Cnic? initial;
  final List<Cnic?>? changes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Cnic? value = widget.initial;

  void set(Cnic? next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => MmCnicField(
    label: "Tenant's CNIC",
    value: value,
    onChanged: (cnic) {
      widget.changes?.add(cnic);
      set(cnic);
    },
  );
}

void main() {
  group('MmCnicField typing', () {
    testWidgets('inserts the dashes as the digits are typed', (tester) async {
      final changes = <Cnic?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '35202');
      expect(valueOf(tester).text, '35202');
      await tester.enterText(find.byType(TextField), '352021');
      expect(valueOf(tester).text, '35202-1');
      expect(valueOf(tester).selection.baseOffset, 7);
      await tester.enterText(find.byType(TextField), '352021234567');
      expect(valueOf(tester).text, '35202-1234567');
      await tester.enterText(find.byType(TextField), '3520212345671');
      expect(valueOf(tester).text, '35202-1234567-1');
      expect(changes, [_cnic]);
      await tester.enterText(find.byType(TextField), '352021234567');
      expect(changes, [_cnic, null]);
    });

    testWidgets('takes digits only, and Urdu digits as Western ones', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), 'CNIC: 35202-1');
      expect(valueOf(tester).text, '35202-1');
      await tester.enterText(find.byType(TextField), '۳۵۲۰۲۱۲۳۴۵۶۷۱');
      expect(valueOf(tester).text, '35202-1234567-1');
      expect(tester.state<_HostState>(find.byType(_Host)).value, _cnic);
    });

    testWidgets('stops at 13 digits', (tester) async {
      await pumpThemed(tester, _Host(initial: _cnic));
      await tester.enterText(find.byType(TextField), '35202123456712');
      expect(valueOf(tester).text, '35202-1234567-1');
    });

    testWidgets('keeps the caret beside the digit typed', (tester) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '352021');
      // "3520|2-1" -> type 9 -> "35209|-21".
      await edit(tester, '352092-1', caret: 5);
      expect(valueOf(tester).text, '35209-21');
      expect(valueOf(tester).selection.baseOffset, 5);
    });

    testWidgets('backspace just after a dash deletes the digit before it', (
      tester,
    ) async {
      await pumpThemed(tester, const _Host());
      await tester.enterText(find.byType(TextField), '352021');
      await edit(tester, '35202-1', caret: 6);
      await edit(tester, '352021', caret: 5);
      expect(valueOf(tester).text, '35201');
      expect(valueOf(tester).selection.baseOffset, 4);
    });

    testWidgets('a placeholder number is not a CNIC', (tester) async {
      final changes = <Cnic?>[];
      await pumpThemed(tester, _Host(changes: changes));
      await tester.enterText(find.byType(TextField), '1111111111111');
      expect(valueOf(tester).text, '11111-1111111-1');
      expect(changes, isEmpty);
    });
  });

  group('MmCnicField value', () {
    testWidgets('shows a value and replaces the text when it changes', (
      tester,
    ) async {
      await pumpThemed(tester, _Host(initial: _cnic));
      expect(valueOf(tester).text, '35202-1234567-1');
      final host = tester.state<_HostState>(find.byType(_Host))
        ..set(Cnic.parse('4210176543212'));
      await tester.pump();
      expect(valueOf(tester).text, '42101-7654321-2');
      host.set(null);
      await tester.pump();
      expect(valueOf(tester).text, '');
    });
  });

  group('MmCnicField presentation', () {
    testEveryVariant('a number keyboard and the Latin face, left to right', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _Host(initial: _cnic), variant: variant);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
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
        MmCnicField(
          label: "Tenant's CNIC",
          value: _cnic,
          required: true,
          onChanged: (_) {},
        ),
      );
      final node = tester.getSemantics(find.byType(EditableText));
      expect(
        node,
        isSemantics(
          label: "Tenant's CNIC",
          value: '35202-1234567-1',
          hint: 'Required',
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
        MmCnicField(
          label: "Guarantor's CNIC",
          optional: true,
          helper: '13 digits, as on the card',
          errorText: 'Already on another tenant',
          focusNode: focus,
          textInputAction: TextInputAction.next,
          enabled: false,
          onChanged: (_) {},
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, focus);
      expect(field.textInputAction, TextInputAction.next);
      expect(field.enabled, isFalse);
      expect(
        find.textContaining('Already on another tenant', findRichText: true),
        findsOne,
      );
      expect(find.textContaining('Optional', findRichText: true), findsOne);
    });

    test('a field is not both required and optional', () {
      expect(
        () => MmCnicField(
          label: 'CNIC',
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
        MmCnicField(
          label: "CNIC of the tenant's guarantor",
          value: _cnic,
          required: true,
          helper: '13 digits, as printed on the front of the card',
          onChanged: (_) {},
        ),
      );
    });
  });
}
