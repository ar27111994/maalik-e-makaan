import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _title = 'Tenant details';
const _description = 'As written on the CNIC.';

Widget _section({String? description = _description}) => SizedBox(
  width: 328,
  child: MmFormSection(
    title: _title,
    description: description,
    children: const [
      TextField(
        key: ValueKey('name'),
        decoration: InputDecoration(labelText: 'Full name'),
      ),
      TextField(
        key: ValueKey('cnic'),
        decoration: InputDecoration(labelText: 'CNIC'),
      ),
    ],
  ),
);

Rect _field(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey(key)));

void main() {
  group('MmFormSection', () {
    testEveryVariant('titles the section in titleMedium, read as a heading', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _section(), variant: variant);
      final title = tester.widget<Text>(find.text(_title));
      final theme = Theme.of(tester.element(find.text(_title)));
      expect(title.style, theme.textTheme.titleMedium);
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
    });

    testEveryVariant('describes it in muted ink', (tester, variant) async {
      await pumpThemed(tester, _section(), variant: variant);
      final description = tester.widget<Text>(find.text(_description));
      expect(description.style!.color, colorsOf(variant).inkMuted);
      expect(
        description.style,
        Theme.of(tester.element(find.text(_description))).textTheme.bodyMedium!
            .copyWith(color: colorsOf(variant).inkMuted),
      );
      expect(
        tester.getSemantics(find.text(_description)),
        isNot(isSemantics(isHeader: true)),
      );
      final title = tester.getRect(find.text(_title));
      expect(
        tester.getRect(find.text(_description)).top,
        title.bottom + MmSpace.s1,
      );
    });

    testWidgets('spaces the fields 16 dp apart, under the header', (
      tester,
    ) async {
      await pumpThemed(tester, _section());
      final description = tester.getRect(find.text(_description));
      expect(_field(tester, 'name').top, description.bottom + MmSpace.s4);
      expect(
        _field(tester, 'cnic').top,
        _field(tester, 'name').bottom + MmSpace.s4,
      );
      expect(_field(tester, 'name').width, 328);
    });

    testWidgets('without a description, the fields follow the title', (
      tester,
    ) async {
      await pumpThemed(tester, _section(description: null));
      expect(find.text(_description), findsNothing);
      expect(
        _field(tester, 'name').top,
        tester.getRect(find.text(_title)).bottom + MmSpace.s4,
      );
    });

    testWidgets('starts its text at the right edge in Urdu', (tester) async {
      await pumpThemed(tester, _section(), variant: MmVariant.urdu);
      final section = tester.getRect(find.byType(MmFormSection));
      expect(tester.getRect(find.text(_title)).right, section.right);
    });

    testWidgets('keyboard focus finishes the section before leaving it', (
      tester,
    ) async {
      // The Help button sits level with the title, but the fields come
      // first.
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _section()),
              const TextButton(onPressed: tapped, child: Text('Help')),
            ],
          ),
        ),
      );
      bool fieldFocused(String key) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;
      final order = <String>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        if (fieldFocused('name')) order.add('name');
        if (fieldFocused('cnic')) order.add('cnic');
        if (hasFocus(tester, find.text('Help'))) order.add('help');
      }
      expect(order, ['name', 'cnic', 'help']);
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmFormSection(
          title: 'Emergency contact of the tenant',
          description:
              'Someone we can call if the tenant cannot be reached about '
              'rent or repairs.',
          children: [TextField(decoration: InputDecoration(labelText: 'Name'))],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
