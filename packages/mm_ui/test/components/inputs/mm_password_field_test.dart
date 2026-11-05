import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

bool _obscured(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).obscureText;

void main() {
  group('MmPasswordField', () {
    testEveryVariant('hides the password until the button shows it', (
      tester,
      variant,
    ) async {
      final strings = MmLocalizations.forLocale(variant.locale);
      await pumpThemed(
        tester,
        const MmPasswordField(label: 'Password', initialValue: 'gulberg-1985'),
        variant: variant,
      );
      expect(_obscured(tester), isTrue);
      expect(find.byTooltip(strings.showPassword), findsOneWidget);
      expect(find.byIcon(MmIcons.show), findsOneWidget);

      await tester.tap(find.byTooltip(strings.showPassword));
      await tester.pump();
      expect(_obscured(tester), isFalse);
      expect(find.byTooltip(strings.hidePassword), findsOneWidget);
      expect(find.byIcon(MmIcons.hide), findsOneWidget);

      await tester.tap(find.byTooltip(strings.hidePassword));
      await tester.pump();
      expect(_obscured(tester), isTrue);
    });

    testWidgets('the button works from the keyboard', (tester) async {
      await pumpThemed(
        tester,
        const MmPasswordField(label: 'Password', initialValue: 'lahore'),
      );
      // Tab into the field, then on to its button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_obscured(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_obscured(tester), isTrue);
    });

    testWidgets('semantics: an obscured text field and a labelled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmPasswordField(
          label: 'Password',
          initialValue: 'lahore',
          required: true,
        ),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Password',
          hint: 'Required',
          isTextField: true,
          isObscured: true,
          isRequired: true,
        ),
      );
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(
          tooltip: 'Show password',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('offers the saved password, or a new one to store', (
      tester,
    ) async {
      await pumpThemed(tester, const MmPasswordField(label: 'Password'));
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, [AutofillHints.password]);
      expect(field.keyboardType, TextInputType.visiblePassword);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);

      await pumpThemed(
        tester,
        const MmPasswordField(label: 'New password', newPassword: true),
      );
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, [AutofillHints.newPassword]);
    });

    testWidgets('reports changes and submission', (tester) async {
      final changes = <String>[];
      final submitted = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        MmPasswordField(
          label: 'Password',
          hint: 'Your password',
          helper: 'At least 8 characters',
          onChanged: changes.add,
          onSubmitted: submitted.add,
          textInputAction: TextInputAction.done,
          focusNode: focus,
          autofocus: true,
        ),
      );
      expect(focus.hasFocus, isTrue);
      expect(find.text('Your password'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ayesha-khan');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(changes, ['ayesha-khan']);
      expect(submitted, ['ayesha-khan']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.done,
      );
    });

    testWidgets('validates in a Form and shows outside errors', (tester) async {
      final form = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'short');
      addTearDown(controller.dispose);
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: Column(
            children: [
              MmPasswordField(
                label: 'Password',
                controller: controller,
                optional: true,
                autovalidateMode: AutovalidateMode.disabled,
                validator: (password) =>
                    password!.length < 8 ? 'At least 8 characters' : null,
              ),
              const MmPasswordField(
                label: 'Old password',
                errorText: 'Wrong password',
              ),
            ],
          ),
        ),
      );
      expect(
        find.textContaining('Wrong password', findRichText: true),
        findsOne,
      );
      expect(find.textContaining('Optional', findRichText: true), findsOne);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.textContaining('At least 8 characters', findRichText: true),
        findsOne,
      );
    });

    testWidgets('a disabled field cannot be revealed', (tester) async {
      await pumpThemed(
        tester,
        const MmPasswordField(
          label: 'Old password',
          initialValue: 'gulberg',
          enabled: false,
        ),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    test('a field is not both required and optional', () {
      expect(
        () =>
            MmPasswordField(label: 'Password', required: true, optional: true),
        throwsAssertionError,
      );
      expect(
        () => MmPasswordField(
          label: 'Password',
          controller: TextEditingController(),
          initialValue: 'x',
        ),
        throwsAssertionError,
      );
    });

    testWidgets('reads left to right at the start edge in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmPasswordField(label: 'پاس ورڈ', initialValue: 'abc'),
        variant: MmVariant.urdu,
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textDirection, TextDirection.ltr);
      expect(editable.textAlign, TextAlign.right);
      final field = tester.getRect(find.byType(InputDecorator));
      final button = tester.getRect(find.byType(IconButton));
      expect(button.center.dx, lessThan(field.center.dx));
    });

    testWidgets('fits 200% text on a 320 dp wide screen', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmPasswordField(
          label: 'Choose a new password for your account',
          required: true,
          newPassword: true,
          helper: 'At least 8 characters, with a number',
          initialValue: 'gulberg-iii-lahore-1985',
        ),
      );
    });
  });
}
