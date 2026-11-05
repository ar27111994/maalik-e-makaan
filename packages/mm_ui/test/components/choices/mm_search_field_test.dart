import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

/// Swaps the field's controller.
class _Swapping extends StatefulWidget {
  const new({required this.first, required this.second});

  final TextEditingController first;
  final TextEditingController? second;

  @override
  State<_Swapping> createState() => _SwappingState();
}

class _SwappingState extends State<_Swapping> {
  bool swapped = false;

  void swap() => setState(() => swapped = true);

  @override
  Widget build(BuildContext context) =>
      MmSearchField(controller: swapped ? widget.second : widget.first);
}

void main() {
  group('MmSearchField', () {
    testWidgets('is a sunken well named "Search" with a search icon', (
      tester,
    ) async {
      await pumpThemed(tester, const MmSearchField());
      final decoration = _decoration(tester);
      expect(find.text('Search'), findsOneWidget);
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, MmColorModes.light.surfaceSunken);
      expect(decoration.enabledBorder!.borderSide, BorderSide.none);
      expect(
        decoration.focusedBorder!.borderSide,
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      expect(find.byIcon(MmIcons.search), findsOneWidget);
      expect(find.byTooltip('Clear'), findsNothing);
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Search', isTextField: true),
      );
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(MmSize.minTarget),
      );
    });

    testWidgets('a hint names the field', (tester) async {
      await pumpThemed(tester, const MmSearchField(hint: 'Search tenants'));
      expect(find.text('Search tenants'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Search tenants', isTextField: true),
      );
    });

    testWidgets('Urdu says "Search" in Urdu', (tester) async {
      await pumpThemed(tester, const MmSearchField(), variant: MmVariant.urdu);
      expect(find.text('تلاش کریں'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'تلاش کریں', isTextField: true),
      );
    });

    testWidgets('reports changes and submissions', (tester) async {
      final changes = <String>[];
      final submissions = <String>[];
      await pumpThemed(
        tester,
        MmSearchField(onChanged: changes.add, onSubmitted: submissions.add),
      );
      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(changes, ['Ali']);
      // Still named by the hint, with the search as its value.
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Search', value: 'Ali', isTextField: true),
      );
      expect(submissions, ['Ali']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.search,
      );
    });

    testWidgets('the clear button empties the field and keeps focus', (
      tester,
    ) async {
      final changes = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(
        tester,
        MmSearchField(onChanged: changes.add, focusNode: focus),
      );
      await tester.enterText(find.byType(TextField), 'Gulberg');
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byTooltip('Clear')),
        matchesSemantics(
          tooltip: 'Clear',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      // From the keyboard: Tab to the button, Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['Gulberg', '']);
      expect(find.text('Gulberg'), findsNothing);
      expect(find.byTooltip('Clear'), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);
    });

    testWidgets('removes control and spoofing characters as typed', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpThemed(tester, MmSearchField(controller: controller));
      await tester.showKeyboard(find.byType(TextField));
      // A right-to-left override and a zero-width space inside a name.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Ali\u202E Raza\u200B',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      await tester.pump();
      expect(controller.text, 'Ali Raza');
      expect(controller.selection, const TextSelection.collapsed(offset: 8));

      // The composing region of an input method moves with the text.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '\u202Aعلی رضا',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 5, end: 8),
        ),
      );
      await tester.pump();
      expect(controller.text, 'علی رضا');
      expect(controller.value.composing, const TextRange(start: 4, end: 7));

      // A composing region that ends up empty is dropped.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'علی\u200B',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 3, end: 4),
        ),
      );
      await tester.pump();
      expect(controller.text, 'علی');
      expect(controller.value.composing, TextRange.empty);
    });

    testWidgets('follows its controller, and a swapped one', (tester) async {
      final first = TextEditingController(text: 'Ali Raza');
      final second = TextEditingController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await pumpThemed(tester, _Swapping(first: first, second: second));
      expect(find.byTooltip('Clear'), findsOneWidget);
      first.text = '';
      await tester.pump();
      expect(find.byTooltip('Clear'), findsNothing);

      tester.state<_SwappingState>(find.byType(_Swapping)).swap();
      await tester.pump();
      second.text = 'Ayesha';
      await tester.pump();
      expect(find.byTooltip('Clear'), findsOneWidget);
      // The old controller no longer drives the field.
      first.text = 'Ali';
      await tester.pump();
      expect(find.text('Ayesha'), findsOneWidget);
    });

    testWidgets('can swap to and from a controller of its own', (tester) async {
      final first = TextEditingController(text: 'Ali Raza');
      addTearDown(first.dispose);
      await pumpThemed(tester, _Swapping(first: first, second: null));
      tester.state<_SwappingState>(find.byType(_Swapping)).swap();
      await tester.pump();
      expect(find.byTooltip('Clear'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Gulberg');
      await tester.pump();
      expect(find.byTooltip('Clear'), findsOneWidget);
    });

    testWidgets('autofocus takes focus when shown', (tester) async {
      await pumpThemed(tester, const MmSearchField(autofocus: true));
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('sets Latin text in Atkinson and Urdu in Nastaliq', (
      tester,
    ) async {
      await pumpThemed(tester, const MmSearchField(), variant: MmVariant.urdu);
      TextStyle style() =>
          tester.widget<EditableText>(find.byType(EditableText)).style;
      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.pump();
      expect(style().fontFamily, contains(MmFontFamily.latin));
      await tester.enterText(find.byType(TextField), 'Ali علی');
      await tester.pump();
      expect(style().fontFamily, contains(MmFontFamily.urdu));
      // Same script, longer text: nothing to rebuild.
      await tester.enterText(find.byType(TextField), 'Ali علی رضا');
      await tester.pump();
      expect(style().fontFamily, contains(MmFontFamily.urdu));
    });

    testWidgets('right to left: the search icon at the right', (tester) async {
      await pumpThemed(
        tester,
        MmSearchField(controller: TextEditingController(text: 'علی')),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getRect(find.byIcon(MmIcons.search)).left,
        greaterThan(tester.getRect(find.byIcon(MmIcons.close)).right),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Localised(
          (context, tr) => MmSearchField(
            hint: tr(
              'Search tenants and properties',
              'کرایہ دار اور جائیداد تلاش کریں',
            ),
            controller: TextEditingController(text: 'Ali Raza, Gulberg'),
          ),
        ),
      );
    });
  });
}
