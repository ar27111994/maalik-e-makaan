import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

final _cnic = Cnic.parse('35202-1234567-1');
final _mobile = PhoneNumber.fromE164('+923001234567');

/// One field of each kind the family has, each holding a value.
Map<String, Widget> _everyKind({bool enabled = true, String? errorText}) => {
  'text': MmTextField(
    label: 'Tenant name',
    initialValue: 'Ali Raza',
    enabled: enabled,
    errorText: errorText,
  ),
  'password': MmPasswordField(
    label: 'Password',
    initialValue: 'gulberg-1985',
    enabled: enabled,
    errorText: errorText,
  ),
  'money': MmMoneyField(
    label: 'Monthly rent',
    value: const Money.fromRupees(45000),
    enabled: enabled,
    errorText: errorText,
    onChanged: (_) {},
  ),
  'cnic': MmCnicField(
    label: "Tenant's CNIC",
    value: _cnic,
    enabled: enabled,
    errorText: errorText,
    onChanged: (_) {},
  ),
  'phone': MmPhoneField(
    label: 'Mobile number',
    value: _mobile,
    enabled: enabled,
    errorText: errorText,
    onChanged: (_) {},
  ),
};

/// The colours every glyph of [icon] is painted in.
List<Color?> _inksOf(WidgetTester tester, IconData icon) => [
  for (final glyph in tester.widgetList<RichText>(
    find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
  ))
    glyph.text.style?.color,
];

void main() {
  group('The inputs family', () {
    testEveryVariant('every kind of field is as tall as the others', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        Column(
          children: [
            ..._everyKind().values,
            // The largest amount is set smaller at 200% text to fit, on a
            // line as tall as the others.
            MmMoneyField(
              label: 'Security deposit',
              value: Money.maxValue,
              onChanged: (_) {},
            ),
          ],
        ),
        variant: variant,
        size: const Size(360, 1600),
      );
      final heights = {
        for (final field in find.byType(InputDecorator).evaluate())
          ((field.renderObject! as RenderBox).size.height * 100).round() / 100,
      };
      expect(heights, hasLength(1), reason: '$heights');
      if (variant.textScale == 1 && variant != MmVariant.urdu) {
        expect(heights.single, MmSize.fieldHeight);
      }
    });

    testEveryVariant(
      'the text, helper and error start 16 dp in, as in the choice fields',
      (tester, variant) async {
        await pumpThemed(
          tester,
          Column(
            children: [
              const MmTextField(
                label: 'Tenant name',
                initialValue: 'Ali Raza',
                helper: 'As on the CNIC',
              ),
              MmCnicField(
                label: "Tenant's CNIC",
                value: _cnic,
                errorText: 'Already on another tenant',
                onChanged: (_) {},
              ),
            ],
          ),
          variant: variant,
          size: const Size(360, 1000),
        );
        final urdu = variant == MmVariant.urdu;
        // How far in from the field's start edge [rect] starts.
        double inset(Rect rect, int field) {
          final box = tester.getRect(find.byType(InputDecorator).at(field));
          return urdu ? box.right - rect.right : rect.left - box.left;
        }

        final helper = tester.getRect(find.text('As on the CNIC'));
        final error = tester.getRect(
          find.textContaining('Already on another tenant', findRichText: true),
        );
        final text = tester.getRect(find.byType(EditableText).at(0));
        final number = tester.getRect(find.byType(EditableText).at(1));
        expect(inset(helper, 0), moreOrLessEquals(MmSpace.s4));
        expect(inset(error, 1), moreOrLessEquals(MmSpace.s4));
        expect(inset(text, 0), moreOrLessEquals(MmSpace.s4));
        // The number reads left to right, at the start edge in Urdu too.
        expect(inset(number, 1), moreOrLessEquals(MmSpace.s4));
      },
    );

    testEveryVariant('a focused field draws the focus ring on its edge', (
      tester,
      variant,
    ) async {
      useKeyboardHighlights();
      final colors = colorsOf(variant);
      for (final MapEntry(key: kind, value: field) in _everyKind().entries) {
        await pumpThemed(tester, field, variant: variant);
        final decorator = find.byType(InputDecorator);
        // The fill, then the outline.
        final ring = paints
          ..rrect()
          ..rrect(color: colors.focus, strokeWidth: MmSize.focusRing);
        expect(decorator, isNot(ring), reason: kind);
        // Tab moves keyboard focus into the field.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester.widget<InputDecorator>(decorator).isFocused,
          isTrue,
          reason: kind,
        );
        expect(decorator, ring, reason: kind);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testEveryVariant('a focused field with an error keeps the overdue edge', (
      tester,
      variant,
    ) async {
      useKeyboardHighlights();
      final colors = colorsOf(variant);
      for (final MapEntry(key: kind, value: field) in _everyKind(
        errorText: 'Check this',
      ).entries) {
        await pumpThemed(tester, field, variant: variant);
        final decorator = find.byType(InputDecorator);
        expect(
          decorator,
          paints
            ..rrect()
            ..rrect(color: colors.overdue, strokeWidth: MmSize.hairline),
          reason: kind,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          decorator,
          paints
            ..rrect()
            ..rrect(color: colors.overdue, strokeWidth: MmSize.focusRing),
          reason: kind,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testEveryVariant('icons inside a field are muted ink in every state', (
      tester,
      variant,
    ) async {
      final muted = colorsOf(variant).inkMuted;
      await pumpThemed(
        tester,
        const Column(
          children: [
            MmTextField(label: 'Unit', prefixIcon: MmIcons.unit),
            MmTextField(
              label: 'Tenant',
              prefixIcon: MmIcons.person,
              errorText: 'Enter the tenant',
            ),
            MmTextField(
              label: 'Property',
              prefixIcon: MmIcons.property,
              enabled: false,
            ),
            MmPasswordField(label: 'Password', initialValue: 'lahore'),
            MmPasswordField(
              label: 'Old password',
              initialValue: 'gulberg',
              errorText: 'Wrong password',
            ),
            MmPasswordField(label: 'PIN', initialValue: '1985', enabled: false),
          ],
        ),
        variant: variant,
        size: const Size(360, 1600),
      );
      // Not the overdue colour of an error, nor ink at 38% when disabled.
      for (final icon in [MmIcons.unit, MmIcons.person, MmIcons.property]) {
        expect(_inksOf(tester, icon), [muted], reason: '$icon');
      }
      expect(_inksOf(tester, MmIcons.show), [muted, muted, muted]);
    });

    testWidgets('a disabled field is muted ink inside a rule outline', (
      tester,
    ) async {
      final colors = colorsOf(MmVariant.light);
      for (final MapEntry(key: kind, value: field) in _everyKind(
        enabled: false,
      ).entries) {
        await pumpThemed(tester, field);
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).style.color,
          colors.inkMuted,
          reason: kind,
        );
        expect(
          find.byType(InputDecorator),
          paints
            ..rrect()
            ..rrect(color: colors.rule, strokeWidth: MmSize.hairline),
          reason: kind,
        );
      }
    });
  });
}
