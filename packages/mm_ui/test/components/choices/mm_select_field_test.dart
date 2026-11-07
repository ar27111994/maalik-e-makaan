import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';

import '../../support/testing.dart';

const List<MmOption<String>> _properties = [
  MmOption(value: 'gulberg', label: 'Gulberg Heights', icon: MmIcons.property),
  MmOption(
    value: 'dha',
    label: 'DHA Phase 5 house',
    description: 'Lahore Cantt',
    icon: MmIcons.home,
  ),
  MmOption(value: 'johar', label: 'Johar Town flats'),
];

/// Twelve units, so the sheet has a search field.
final List<MmOption<int>> _units = [
  for (var i = 1; i <= 12; i++) MmOption(value: i, label: 'Flat A-$i'),
];

/// A select field over [options] that records what it reports in [log].
Widget _field<T>({
  required List<MmOption<T>> options,
  List<T>? log,
  T? value,
  String label = 'Property',
  String? placeholder,
  String? helper,
  String? errorText,
  bool required = false,
  bool optional = false,
  bool enabled = true,
}) => MmSelectField<T>(
  label: label,
  options: options,
  value: value,
  placeholder: placeholder,
  helper: helper,
  errorText: errorText,
  required: required,
  optional: optional,
  onChanged: enabled ? (value) => log?.add(value) : null,
);

/// The tappable part of the field.
Finder get _box => find
    .descendant(of: find.byType(MmChoiceBox), matching: find.byType(InkWell))
    .first;

/// The sheet's row showing [label].
Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ListTile));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_box);
  await tester.pumpAndSettle();
}

/// Rebuilds the field disabled while its sheet is open.
class _Disabling extends StatefulWidget {
  const new({required this.log});

  final List<String> log;

  @override
  State<_Disabling> createState() => _DisablingState();
}

class _DisablingState extends State<_Disabling> {
  bool enabled = true;

  void disable() => setState(() => enabled = false);

  @override
  Widget build(BuildContext context) => MmSelectField<String>(
    label: 'Property',
    options: _properties,
    onChanged: enabled ? widget.log.add : null,
  );
}

void main() {
  group('MmOption', () {
    test('compares by value, label, description and icon', () {
      const a = MmOption(
        value: 1,
        label: 'Cash',
        description: 'At the door',
        icon: MmIcons.cash,
      );
      final same = MmOption(
        value: int.parse('1'),
        label: 'Cash',
        description: 'At the door',
        icon: MmIcons.cash,
      );
      expect(same, a);
      expect(same.hashCode, a.hashCode);
      expect(
        a,
        isNot(
          const MmOption(
            value: 2,
            label: 'Cash',
            description: 'At the door',
            icon: MmIcons.cash,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const MmOption(
            value: 1,
            label: 'Bank',
            description: 'At the door',
            icon: MmIcons.cash,
          ),
        ),
      );
      expect(
        a,
        isNot(const MmOption(value: 1, label: 'Cash', icon: MmIcons.cash)),
      );
      expect(
        a,
        isNot(
          const MmOption(value: 1, label: 'Cash', description: 'At the door'),
        ),
      );
      expect(a, isNot('Cash'));
    });
  });

  group('MmSelectField', () {
    testWidgets('shows the chosen option with its icon and a chevron', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(options: _properties, value: 'gulberg', required: true),
      );
      expect(find.text('Property  Required', findRichText: true), findsOne);
      expect(find.text('Gulberg Heights'), findsOneWidget);
      expect(find.byIcon(MmIcons.property), findsOneWidget);
      expect(find.byIcon(MmIcons.expand), findsOneWidget);
      expect(
        tester.getSize(_box).height,
        greaterThanOrEqualTo(MmSize.fieldHeight),
      );
      expect(
        tester.getSemantics(_box),
        matchesSemantics(
          label: 'Property',
          value: 'Gulberg Heights',
          hint: 'Required',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasRequiredState: true,
          isRequired: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('shows the placeholder in muted ink until a choice', (
      tester,
    ) async {
      for (final value in [null, 'nowhere']) {
        await pumpThemed(
          tester,
          _field(
            options: _properties,
            value: value,
            placeholder: 'Choose a property',
            optional: true,
          ),
        );
        final text = tester.widget<Text>(find.text('Choose a property'));
        expect(text.style!.color, MmColorModes.light.inkMuted);
        expect(
          tester.getSemantics(_box),
          matchesSemantics(
            label: 'Property',
            hint: 'Choose a property\nOptional',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasRequiredState: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      }
    });

    testWidgets('opens a sheet titled with the label; the choice is checked', (
      tester,
    ) async {
      await pumpThemed(tester, _field(options: _properties, value: 'dha'));
      await _open(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Property'),
          ),
        ),
        matchesSemantics(label: 'Property', isHeader: true),
      );
      expect(find.byType(MmSearchField), findsNothing);
      expect(find.text('Lahore Cantt'), findsOneWidget);
      // One check mark, on the chosen row.
      expect(find.byIcon(MmIcons.check), findsOneWidget);
      expect(
        find.descendant(
          of: _row('DHA Phase 5 house'),
          matching: find.byIcon(MmIcons.check),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_row('DHA Phase 5 house')),
        matchesSemantics(
          label: 'DHA Phase 5 house\nLahore Cantt',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(_row('Johar Town flats')),
        matchesSemantics(
          label: 'Johar Town flats',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('choosing reports the value, closes and refocuses the field', (
      tester,
    ) async {
      final log = <String>[];
      await pumpThemed(
        tester,
        _field(options: _properties, value: 'dha', log: log),
      );
      await _open(tester);
      await tester.tap(find.text('Johar Town flats'));
      await tester.pumpAndSettle();
      expect(log, ['johar']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MmSelectField');

      // The chosen option again, or dismissing, reports nothing.
      await _open(tester);
      await tester.tap(_row('DHA Phase 5 house'));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(log, ['johar']);
    });

    testWidgets('an option whose value is null can be chosen', (tester) async {
      final log = <String?>[];
      await pumpThemed(
        tester,
        _field<String?>(
          options: const [
            MmOption(value: null, label: 'No property yet'),
            MmOption(value: 'gulberg', label: 'Gulberg Heights'),
          ],
          value: 'gulberg',
          log: log,
        ),
      );
      await _open(tester);
      await tester.tap(find.text('No property yet'));
      await tester.pumpAndSettle();
      expect(log, [null]);
    });

    testWidgets('the keyboard opens, moves through and chooses options', (
      tester,
    ) async {
      final log = <String>[];
      await pumpThemed(
        tester,
        _field(options: _properties, value: 'gulberg', log: log),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MmSelectField');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // The chosen row has focus, and the focus ring.
      final focused = find.ancestor(
        of: _row('Gulberg Heights'),
        matching: find.byType(DecoratedBox),
      );
      final ring = tester.widget<DecoratedBox>(focused.first).decoration;
      expect((ring as BoxDecoration).border, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, ['dha']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MmSelectField');
      expect(log, ['dha']);
    });

    testWidgets('more than eight options can be searched', (tester) async {
      final log = <int>[];
      await pumpThemed(
        tester,
        _field(options: _units, value: 12, label: 'Unit', log: log),
      );
      await _open(tester);
      expect(find.byType(MmSearchField), findsOneWidget);
      // The chosen option, far down the list, is scrolled into view.
      expect(find.text('Flat A-12'), findsNWidgets(2));
      expect(tester.getRect(_row('Flat A-12')).bottom, lessThanOrEqualTo(740));

      // Case and Urdu digits do not matter.
      await tester.enterText(find.byType(TextField), '  fLaT a-۱');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(4),
      );
      await tester.enterText(find.byType(TextField), 'a-۱۱');
      await tester.pumpAndSettle();
      expect(_row('Flat A-11'), findsOneWidget);
      expect(_row('Flat A-1'), findsNothing);
      await tester.tap(_row('Flat A-11'));
      await tester.pumpAndSettle();
      expect(log, [11]);
    });

    testWidgets('a search that matches nothing says so, live', (tester) async {
      await pumpThemed(tester, _field(options: _units, label: 'Unit'));
      await _open(tester);
      await tester.enterText(find.byType(TextField), 'Gulberg');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(
        tester.getSemantics(find.text('No matches')),
        matchesSemantics(label: 'No matches', isLiveRegion: true),
      );
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsNothing);
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('says that nothing matches in Urdu in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(options: _units, label: 'یونٹ'),
        variant: MmVariant.urdu,
      );
      await _open(tester);
      await tester.enterText(find.byType(TextField), 'Gulberg');
      await tester.pumpAndSettle();
      expect(find.text(MmLocalizations.urdu.noMatches), findsOneWidget);
    });

    testWidgets('eight options have no search field', (tester) async {
      await pumpThemed(
        tester,
        _field(options: _units.take(8).toList(), label: 'Unit'),
      );
      await _open(tester);
      expect(find.byType(MmSearchField), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(8));
    });

    testWidgets('a disabled field opens nothing and is announced so', (
      tester,
    ) async {
      final log = <String>[];
      await pumpThemed(
        tester,
        _field(
          options: _properties,
          value: 'gulberg',
          enabled: false,
          log: log,
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.getSemantics(_box),
        matchesSemantics(
          label: 'Property',
          value: 'Gulberg Heights',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      final text = tester.widget<Text>(find.text('Gulberg Heights'));
      expect(text.style!.color, MmColorModes.light.inkMuted);
    });

    testWidgets('a choice made after the field is disabled is dropped', (
      tester,
    ) async {
      final log = <String>[];
      await pumpThemed(tester, _Disabling(log: log));
      await _open(tester);
      tester.state<_DisablingState>(find.byType(_Disabling)).disable();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Johar Town flats'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('helper and error sit below the field', (tester) async {
      await pumpThemed(
        tester,
        _field(options: _properties, helper: 'Gulberg, Lahore'),
      );
      expect(find.text('Gulberg, Lahore'), findsOneWidget);
      await pumpThemed(
        tester,
        _field(
          options: _properties,
          helper: 'Gulberg, Lahore',
          errorText: 'Choose a property',
        ),
      );
      expect(find.text('Gulberg, Lahore'), findsNothing);
      expect(find.byIcon(MmIcons.error), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Choose a property')),
        isSemantics(label: 'Choose a property', isLiveRegion: true),
      );
      // The field itself is marked invalid while it has an error.
      expect(
        tester.getSemantics(_box),
        isSemantics(
          label: 'Property',
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
    });

    testWidgets('the sheet closes with its close button; focus comes back', (
      tester,
    ) async {
      final log = <String>[];
      await pumpThemed(tester, _field(options: _properties, log: log));
      await _open(tester);
      final close = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(MmIcons.close),
      );
      expect(
        tester.getSemantics(close),
        matchesSemantics(
          label: 'Close',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(log, isEmpty);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MmSelectField');
    });

    testWidgets('the sheet opens as every sheet does', (tester) async {
      await pumpThemed(
        tester,
        _field(options: _properties),
        size: const Size(1000, 740),
      );
      await _open(tester);
      // At most the widest a sheet grows, centred, in the system's time.
      final sheet = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheet.width, MmSize.sheetMax);
      expect(sheet.center.dx, 500);
      final route = ModalRoute.of(tester.element(find.byType(BottomSheet)))!;
      expect(route.transitionDuration, MmDuration.standard);
      // With reduced motion it opens at once.
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await pumpThemed(tester, withoutAnimations(_field(options: _properties)));
      await tester.tap(_box);
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(BottomSheet)))!
            .transitionDuration,
        Duration.zero,
      );
    });

    testEveryVariant('the sheet has an edge where the page is dark', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _field(options: _properties), variant: variant);
      await _open(tester);
      final shape =
          tester.widget<BottomSheet>(find.byType(BottomSheet)).shape!
              as RoundedRectangleBorder;
      final framed =
          variant.brightness == Brightness.dark || variant.highContrast;
      expect(
        shape.side,
        framed ? BorderSide(color: variant.colors.outline) : BorderSide.none,
      );
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MmRadius.lg)),
      );
    });

    testWidgets('labels line up whether or not a row has an icon', (
      tester,
    ) async {
      await pumpThemed(tester, _field(options: _properties));
      await _open(tester);
      final starts = {
        for (final option in _properties)
          tester.getTopLeft(find.text(option.label).last).dx,
      };
      expect(starts, hasLength(1));
      // Without any icon, rows keep no room for one.
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await pumpThemed(tester, _field(options: _units));
      await _open(tester);
      expect(
        tester.getTopLeft(find.text('Flat A-1')).dx -
            tester.getTopLeft(_row('Flat A-1')).dx,
        MmSpace.s4,
      );
    });

    test('is either required or optional', () {
      expect(
        () => MmSelectField<String>(
          label: 'Property',
          options: _properties,
          required: true,
          optional: true,
          onChanged: null,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('right to left: the chevron at the left, the icon at the '
        'right', (tester) async {
      await pumpThemed(
        tester,
        _field(
          options: const [
            MmOption(
              value: 'gulberg',
              label: 'گلبرگ ہائٹس',
              icon: MmIcons.property,
            ),
          ],
          value: 'gulberg',
          label: 'جائیداد',
        ),
        variant: MmVariant.urdu,
      );
      final text = tester.getRect(find.text('گلبرگ ہائٹس'));
      expect(
        tester.getRect(find.byIcon(MmIcons.expand)).right,
        lessThan(text.left),
      );
      expect(
        tester.getRect(find.byIcon(MmIcons.property)).left,
        greaterThan(text.right),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone, sheet included', (
      tester,
    ) async {
      final field = Builder(
        builder: (context) {
          final tr = sayIn(context);
          return _field(
            options: [
              for (var i = 1; i <= 10; i++)
                MmOption(
                  value: i,
                  label: tr('Upper portion, House $i', 'بالائی حصہ، مکان $i'),
                  description: tr('Ayesha Khan, Rs 1,25,000', 'عائشہ خان'),
                  icon: MmIcons.home,
                ),
            ],
            value: 4,
            label: tr('Unit rented by Ali Raza', 'علی رضا کا کرایہ کا یونٹ'),
            required: true,
            helper: tr('Gulberg, Lahore', 'گلبرگ، لاہور'),
          );
        },
      );
      await expectFitsNarrowLargeText(tester, field);
      await tester.tap(find.byType(MmChoiceBox));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
