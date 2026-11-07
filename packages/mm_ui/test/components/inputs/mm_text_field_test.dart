import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'editing.dart';

void main() {
  group('MmTextField anatomy', () {
    testEveryVariant('the label sits above the field and stays there', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'Tenant name', hint: 'Ali Raza'),
        variant: variant,
      );
      final label = tester.getRect(find.text('Tenant name'));
      final field = tester.getRect(find.byType(InputDecorator));
      expect(label.bottom, lessThanOrEqualTo(field.top));
      // Start-aligned with the field in both directions.
      if (variant == MmVariant.urdu) {
        expect(label.right, moreOrLessEquals(field.right));
      } else {
        expect(label.left, moreOrLessEquals(field.left));
      }

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Ali Raza');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Tenant name')), label);
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoration.labelText, isNull);
      expect(decoration.label, isNull);
    });

    testWidgets('the field is 56 dp tall at 1x', (tester) async {
      await pumpThemed(tester, const MmTextField(label: 'Tenant name'));
      expect(
        tester.getSize(find.byType(InputDecorator)).height,
        MmSize.fieldHeight,
      );
    });

    testWidgets('says Required or Optional in words after the label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          children: [
            MmTextField(label: 'Tenant name', required: true),
            MmTextField(label: "Father's name", optional: true),
            MmTextField(label: 'Notes'),
          ],
        ),
      );
      expect(find.textContaining('Required'), findsOneWidget);
      expect(find.textContaining('Optional'), findsOneWidget);
      expect(
        find.text('Tenant name  Required', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Notes', findRichText: true), findsOneWidget);
    });

    testWidgets('the marker is in Urdu in the Urdu UI', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          children: [
            MmTextField(label: 'نام', required: true),
            MmTextField(label: 'پتہ', optional: true),
          ],
        ),
        variant: MmVariant.urdu,
      );
      expect(find.text('نام  لازمی', findRichText: true), findsOneWidget);
      expect(find.text('پتہ  اختیاری', findRichText: true), findsOneWidget);
    });

    test('a field is not both required and optional', () {
      expect(
        () => MmTextField(label: 'Name', required: true, optional: true),
        throwsAssertionError,
      );
      expect(
        () => MmTextField(
          label: 'Name',
          controller: TextEditingController(),
          initialValue: 'Ali',
        ),
        throwsAssertionError,
      );
      expect(
        () => MmTextField(label: 'Name', maxLength: 0),
        throwsAssertionError,
      );
      expect(
        () => MmTextField(label: 'Name', minLines: 0),
        throwsAssertionError,
      );
      expect(
        () => MmTextField(label: 'Name', minLines: 3, maxLines: 2),
        throwsAssertionError,
      );
    });

    testEveryVariant('the hint shows in the empty field, in muted ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmTextField(
          label: "Father's name",
          hint: 'For example, Muhammad Raza',
        ),
        variant: variant,
      );
      final hint = find.text('For example, Muhammad Raza');
      expect(hint, findsOneWidget);
      expect(styleOf(tester, 'For example').color, colorsOf(variant).inkMuted);
      // Inside the field, at its start.
      final field = tester.getRect(find.byType(InputDecorator));
      final words = tester.getRect(hint);
      expect(field.contains(words.center), isTrue);
      if (variant == MmVariant.urdu) {
        expect(field.right - words.right, moreOrLessEquals(MmSpace.s4));
      } else {
        expect(words.left - field.left, moreOrLessEquals(MmSpace.s4));
      }
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: hint, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), 1);
      // Typing replaces it.
      await tester.enterText(find.byType(TextField), 'Muhammad');
      await tester.pumpAndSettle();
      expect(opacity(), 0);
    });

    testWidgets('a long hint wraps at large text instead of being cut', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const hint = 'For example, Muhammad Raza';
      await pumpLargeNarrow(
        tester,
        const MmTextField(label: "Father's name", hint: hint),
      );
      final text = tester.widget<Text>(find.text(hint));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      final lines = tester.getSize(find.text(hint)).height;
      expect(lines, greaterThan(styleOf(tester, hint).fontSize! * 2 * 1.5));
      // The field is as tall as its hint, typed in or not.
      final empty = tester.getSize(find.byType(InputDecorator)).height;
      expect(empty, greaterThan(lines));
      await tester.enterText(find.byType(TextField), 'Muhammad Raza');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(InputDecorator)).height, empty);
      // A screen reader still hears it with the field's name.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(EditableText)).label,
        contains(hint),
      );
      handle.dispose();
    });

    testWidgets('helper text sits below in muted ink and wraps', (
      tester,
    ) async {
      const helper =
          'As written on the CNIC, including the middle name if there is one';
      await pumpThemed(
        tester,
        const MmTextField(label: 'Tenant name', helper: helper),
      );
      final text = tester.widget<Text>(find.text(helper));
      expect(text.style!.color, MmColorModes.light.inkMuted);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(
        tester.getRect(find.text(helper)).top,
        greaterThan(tester.getRect(find.byType(EditableText)).bottom),
      );
      // It wraps onto a second line rather than being cut short.
      expect(tester.getSize(find.text(helper)).height, greaterThan(24));
    });
  });

  group('MmTextField errors', () {
    testEveryVariant(
      'an error shows in words with the icon, not colour alone',
      (tester, variant) async {
        await pumpThemed(
          tester,
          const MmTextField(
            label: 'Unit',
            helper: 'As on the door',
            errorText: 'Enter the unit number',
          ),
          variant: variant,
        );
        final colors = colorsOf(variant);
        expect(
          find.textContaining('Enter the unit number', findRichText: true),
          findsOne,
        );
        expect(find.text('As on the door'), findsNothing);
        final icon = tester.widget<Icon>(find.byIcon(MmIcons.error));
        expect(icon.color, colors.overdue);
        expect(styleOf(tester, 'Enter the unit number').color, colors.overdue);
        // The icon sits on the line of the words, at their start.
        final iconRect = tester.getRect(find.byIcon(MmIcons.error));
        final words = tester.getRect(
          find.textContaining('Enter the unit number', findRichText: true),
        );
        if (variant == MmVariant.urdu) {
          expect(iconRect.right, moreOrLessEquals(words.right, epsilon: 1));
        } else {
          expect(iconRect.left, moreOrLessEquals(words.left, epsilon: 1));
        }
      },
    );

    testWidgets('the error is announced and marks the field invalid', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmTextField(label: 'Unit', errorText: 'Enter the unit number'),
      );
      expect(find.semantics.byLabel('Enter the unit number'), findsOne);
      expect(
        tester.getSemantics(
          find.textContaining('Enter the unit number', findRichText: true),
        ),
        isSemantics(label: 'Enter the unit number', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Unit',
          isTextField: true,
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'Form validation shows, and reset clears, the validator error',
      (tester) async {
        final form = GlobalKey<FormState>();
        await pumpThemed(
          tester,
          Form(
            key: form,
            child: MmTextField(
              label: 'Tenant name',
              initialValue: '',
              validator: (name) => name!.isEmpty ? 'Enter a name' : null,
            ),
          ),
        );
        expect(
          find.textContaining('Enter a name', findRichText: true),
          findsNothing,
        );
        expect(form.currentState!.validate(), isFalse);
        await tester.pump();
        expect(
          find.textContaining('Enter a name', findRichText: true),
          findsOneWidget,
        );
        expect(find.byIcon(MmIcons.error), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Ayesha Khan');
        expect(form.currentState!.validate(), isTrue);
        await tester.pump();
        expect(
          find.textContaining('Enter a name', findRichText: true),
          findsNothing,
        );

        form.currentState!.reset();
        await tester.pump();
        expect(find.text('Ayesha Khan'), findsNothing);
      },
    );

    testWidgets('validates as the user types when asked to', (tester) async {
      await pumpThemed(
        tester,
        MmTextField(
          label: 'Tenant name',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (name) => name!.length < 3 ? 'Too short' : null,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump();
      expect(
        find.textContaining('Too short', findRichText: true),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.pump();
      expect(
        find.textContaining('Too short', findRichText: true),
        findsNothing,
      );
    });

    testWidgets("an outside error wins over the validator's", (tester) async {
      final form = GlobalKey<FormState>();
      await pumpThemed(
        tester,
        Form(
          key: form,
          child: MmTextField(
            label: 'Tenant name',
            errorText: 'Already a tenant',
            validator: (_) => 'Enter a name',
          ),
        ),
      );
      form.currentState!.validate();
      await tester.pump();
      expect(
        find.textContaining('Already a tenant', findRichText: true),
        findsOne,
      );
      expect(
        find.textContaining('Enter a name', findRichText: true),
        findsNothing,
      );
    });
  });

  group('MmTextField semantics', () {
    testEveryVariant('the visible label is the accessible name', (
      tester,
      variant,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmTextField(
          label: 'Tenant name',
          initialValue: 'Ali Raza',
          required: true,
        ),
        variant: variant,
      );
      final required = MmLocalizations.forLocale(variant.locale).requiredField;
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Tenant name',
          value: 'Ali Raza',
          hint: required,
          isTextField: true,
          hasRequiredState: true,
          isRequired: true,
          isEnabled: true,
        ),
      );
      // The visible copy of the label is not read a second time.
      expect(find.semantics.byLabel('Tenant name'), findsOne);
      handle.dispose();
    });

    testWidgets('optional and plain fields', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const Column(
          children: [
            MmTextField(label: "Father's name", optional: true),
            MmTextField(label: 'Notes'),
          ],
        ),
      );
      final fields = find.byType(EditableText);
      expect(
        tester.getSemantics(fields.first),
        isSemantics(
          label: "Father's name",
          hint: 'Optional',
          hasRequiredState: true,
          isRequired: false,
        ),
      );
      expect(
        tester.getSemantics(fields.last),
        isSemantics(label: 'Notes', hint: '', hasRequiredState: false),
      );
      handle.dispose();
    });

    testWidgets('a disabled field says so', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmTextField(
          label: 'Property',
          initialValue: 'Gulberg Heights',
          enabled: false,
        ),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Property',
          isTextField: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('MmTextField input', () {
    testWidgets('reports changes and submission', (tester) async {
      final changes = <String>[];
      final submitted = <String>[];
      await pumpThemed(
        tester,
        MmTextField(
          label: 'Tenant name',
          onChanged: changes.add,
          onSubmitted: submitted.add,
          textInputAction: TextInputAction.done,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Ayesha Khan');
      expect(changes, ['Ayesha Khan']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, ['Ayesha Khan']);
    });

    testWidgets('takes focus from the keyboard and accepts typing', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        Column(
          children: [
            const MmTextField(label: 'Tenant name'),
            MmTextField(label: 'Father’s name', focusNode: focus),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      tester.testTextInput.enterText('Muhammad Raza');
      await tester.pump();
      expect(
        valueOf(tester, find.byType(MmTextField).last).text,
        'Muhammad Raza',
      );
    });

    testWidgets('autofocus takes focus when first shown', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        MmTextField(label: 'Tenant name', focusNode: focus, autofocus: true),
      );
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('passes its settings to the text field', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(
          label: 'Address',
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.next,
          autofillHints: [AutofillHints.fullStreetAddress],
          textCapitalization: TextCapitalization.words,
          minLines: 2,
          maxLines: 4,
          readOnly: true,
          initialValue: 'House 12, Gulberg III, Lahore',
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.streetAddress);
      expect(field.textInputAction, TextInputAction.next);
      expect(field.autofillHints, [AutofillHints.fullStreetAddress]);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.minLines, 2);
      expect(field.maxLines, 4);
      expect(field.readOnly, isTrue);
      expect(find.text('House 12, Gulberg III, Lahore'), findsOneWidget);
    });

    testWidgets('a read-only field keeps its text and opens no keyboard', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final changes = <String>[];
      await pumpThemed(
        tester,
        MmTextField(
          label: 'Lease reference',
          initialValue: 'GH-12',
          readOnly: true,
          onChanged: changes.add,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      // It takes focus, so the text can be selected and copied...
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
      // ...but no keyboard connects to change it.
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(valueOf(tester).text, 'GH-12');
      expect(changes, isEmpty);
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(isReadOnly: true, value: 'GH-12'),
      );
      semantics.dispose();
    });

    testWidgets('a controller drives the text', (tester) async {
      final first = TextEditingController(text: 'Ali Raza');
      final second = TextEditingController(text: 'علی رضا');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(TextEditingController controller) =>
          MmTextField(label: 'Tenant name', controller: controller);

      await pumpThemed(tester, build(first), variant: MmVariant.urdu);
      expect(find.text('Ali Raza'), findsOneWidget);
      first.text = 'Ayesha Khan';
      await tester.pump();
      expect(find.text('Ayesha Khan'), findsOneWidget);

      await tester.pumpWidget(themed(build(second), variant: MmVariant.urdu));
      expect(find.text('علی رضا'), findsOneWidget);
      // The old controller no longer drives the field.
      first.text = 'Changed';
      await tester.pump();
      expect(find.text('Changed'), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontFamily,
        contains(MmFontFamily.urdu),
      );
    });

    testEveryVariant('the counter is in the Latin face, with even figures', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'Note', initialValue: 'علی', maxLength: 40),
        variant: variant,
      );
      final style = styleOf(tester, '3/40');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.color, colorsOf(variant).inkMuted);
    });

    testWidgets('counts characters as a reader perceives them', (tester) async {
      await pumpThemed(tester, const MmTextField(label: 'Note', maxLength: 5));
      // A family emoji is one character of eight code units.
      await tester.enterText(find.byType(TextField), 'Ok 👨\u200D👩\u200D👧');
      await tester.pump();
      expect(find.text('4/5'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Ok 👨\u200D👩\u200D👧 ab',
      );
      await tester.pump();
      expect(valueOf(tester).text.characters.length, 5);
    });

    testWidgets('cleans unsafe characters and then applies its formatters', (
      tester,
    ) async {
      final changes = <String>[];
      await pumpThemed(
        tester,
        MmTextField(
          label: 'Unit',
          onChanged: changes.add,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp('x'))],
        ),
      );
      await tester.enterText(find.byType(TextField), 'Ax\u202E1\u200B2');
      expect(valueOf(tester).text, 'A12');
      expect(changes.single, 'A12');
    });

    testWidgets('affixes: a start icon, prefix text and an end widget', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmTextField(
          label: 'Unit',
          prefixIcon: MmIcons.unit,
          prefixText: 'No. ',
          suffix: IconButton(
            onPressed: () {},
            tooltip: 'Clear',
            icon: const Icon(MmIcons.close),
          ),
        ),
      );
      expect(find.byIcon(MmIcons.unit), findsOneWidget);
      expect(find.byIcon(MmIcons.close), findsOneWidget);
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoration.prefixText, 'No. ');
    });

    testWidgets('a disabled field mutes its label and text', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(
          label: 'Property',
          initialValue: 'Gulberg Heights',
          enabled: false,
        ),
      );
      expect(styleOf(tester, 'Property').color, MmColorModes.light.inkMuted);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.style.color, MmColorModes.light.inkMuted);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('MmTextField script', () {
    testWidgets('Latin text in the Urdu UI is set in Atkinson', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'نام'),
        variant: MmVariant.urdu,
      );
      String family() => tester
          .widget<EditableText>(find.byType(EditableText))
          .style
          .fontFamily!;
      expect(family(), contains(MmFontFamily.latin));
      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.pump();
      expect(family(), contains(MmFontFamily.latin));
      await tester.enterText(find.byType(TextField), 'علی');
      await tester.pump();
      expect(family(), contains(MmFontFamily.urdu));
      await tester.enterText(find.byType(TextField), 'Ali Raza');
      await tester.pump();
      expect(family(), contains(MmFontFamily.latin));
    });

    testWidgets('switches to Nastaliq on the very first Urdu letter', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'نام'),
        variant: MmVariant.urdu,
      );
      await tester.enterText(find.byType(TextField), 'ع');
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontFamily,
        contains(MmFontFamily.urdu),
      );
    });

    testWidgets('the English UI keeps Atkinson', (tester) async {
      await pumpThemed(tester, const MmTextField(label: 'Name'));
      await tester.enterText(find.byType(TextField), 'علی');
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontFamily,
        contains(MmFontFamily.latin),
      );
    });
  });

  group('MmTextField layout', () {
    testWidgets('fits 200% text on a 320 dp wide screen', (tester) async {
      const fields = Column(
        children: [
          MmTextField(
            label: 'Name of the tenant as written on the CNIC',
            required: true,
            helper: 'Include the middle name if there is one',
            maxLength: 60,
            prefixIcon: MmIcons.person,
          ),
          MmTextField(
            label: 'Unit',
            optional: true,
            errorText: 'Enter the unit number before saving the lease',
          ),
        ],
      );
      await expectFitsNarrowLargeText(tester, fields);
      // The long label wraps onto more lines instead of being cut.
      await pumpLargeNarrow(tester, const SingleChildScrollView(child: fields));
      expect(
        tester
            .getSize(
              find.text(
                'Name of the tenant as written on the CNIC  Required',
                findRichText: true,
              ),
            )
            .height,
        greaterThan(60),
      );
    });

    testWidgets('mirrors in the Urdu UI', (tester) async {
      await pumpThemed(
        tester,
        const MmTextField(label: 'یونٹ', prefixIcon: MmIcons.unit),
        variant: MmVariant.urdu,
      );
      final field = tester.getRect(find.byType(InputDecorator));
      final icon = tester.getRect(find.byIcon(MmIcons.unit));
      expect(icon.center.dx, greaterThan(field.center.dx));
    });
  });
}
