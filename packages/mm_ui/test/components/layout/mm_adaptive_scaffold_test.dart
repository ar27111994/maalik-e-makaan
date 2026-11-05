import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _destinations = [
  MmDestination(icon: MmIcons.property, label: 'Properties'),
  MmDestination(
    icon: MmIcons.tenants,
    selectedIcon: MmIcons.person,
    label: 'Tenants',
  ),
  MmDestination(icon: MmIcons.receipt, label: 'Dues', badgeCount: 3),
  MmDestination(icon: MmIcons.reports, label: 'Reports'),
];

const _phone = Size(360, 740);
const _tablet = Size(700, 800);
const _landscapeTablet = Size(1000, 800);
const _desktop = Size(1280, 800);

Widget _scaffold({
  int selected = 0,
  ValueChanged<int>? onSelected,
  Widget body = const Center(child: Text('Rent roll')),
  Widget? fab,
  List<MmDestination> destinations = _destinations,
}) => MmAdaptiveScaffold(
  destinations: destinations,
  selectedIndex: selected,
  onDestinationSelected: onSelected ?? (_) {},
  floatingActionButton: fab,
  body: body,
);

/// The rectangle of the destination labelled [label].
Rect _labelRect(WidgetTester tester, String label) =>
    tester.getRect(find.text(label));

void main() {
  group('MmDestination', () {
    test('has value equality', () {
      const a = MmDestination(icon: MmIcons.home, label: 'Home');
      const b = MmDestination(icon: MmIcons.home, label: 'Home');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == _destinations[0], isFalse);
      expect(
        a,
        isNot(
          const MmDestination(
            icon: MmIcons.home,
            label: 'Home',
            selectedIcon: MmIcons.property,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const MmDestination(icon: MmIcons.home, label: 'Home', badgeCount: 1),
        ),
      );
      expect(
        a,
        isNot(const MmDestination(icon: MmIcons.ledger, label: 'Home')),
      );
      expect(a == Object(), isFalse);
    });

    test('rejects a negative count', () {
      expect(
        () => MmDestination(
          icon: MmIcons.home,
          label: 'Home',
          badgeCount: -1 + 0 * DateTime.now().year,
        ),
        throwsAssertionError,
      );
    });
  });

  group('MmAdaptiveScaffold', () {
    testWidgets('compact: a bottom navigation bar under a hairline rule', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(
          fab: const FloatingActionButton(
            onPressed: tapped,
            tooltip: 'Add property',
            child: Icon(MmIcons.add),
          ),
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final destination in _destinations) {
        expect(find.text(destination.label), findsOneWidget);
      }
      final bar = tester.getRect(find.byType(NavigationBar));
      expect(bar.bottom, _phone.height);
      expect(bar.width, _phone.width);
      final rule = tester.widget<Divider>(find.byType(Divider));
      expect(rule.height, MmSize.hairline);
      expect(rule.thickness, MmSize.hairline);
      expect(tester.getRect(find.byType(Divider)).bottom, bar.top);
      expect(find.text('Rent roll'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    for (final (name, size) in [
      ('medium', _tablet),
      ('expanded', _landscapeTablet),
    ]) {
      testWidgets('$name: a labelled rail at the start, a rule, the body', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          _scaffold(
            fab: const FloatingActionButton(
              onPressed: tapped,
              tooltip: 'Add property',
              child: Icon(MmIcons.add),
            ),
          ),
          size: size,
        );
        expect(find.byType(NavigationBar), findsNothing);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isFalse);
        expect(rail.labelType, NavigationRailLabelType.all);
        expect(rail.scrollable, isTrue);
        final railRect = tester.getRect(find.byType(NavigationRail));
        expect(railRect.left, 0);
        expect(railRect.height, size.height);
        final rule = tester.getRect(find.byType(VerticalDivider));
        expect(rule.left, railRect.right);
        expect(rule.width, MmSize.hairline);
        expect(
          tester.getRect(find.text('Rent roll')).center.dx,
          greaterThan(rule.right),
        );
        // Labels sit under their icons.
        final icon = tester.getRect(find.byIcon(MmIcons.reports));
        expect(_labelRect(tester, 'Reports').top, greaterThan(icon.bottom));
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });
    }

    testWidgets('large: the rail extended, labels beside the icons', (
      tester,
    ) async {
      await pumpScreen(tester, _scaffold(), size: _desktop);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(rail.labelType, NavigationRailLabelType.none);
      final icon = tester.getRect(find.byIcon(MmIcons.reports));
      final label = _labelRect(tester, 'Reports');
      expect(label.left, greaterThan(icon.right));
      expect(label.center.dy, closeTo(icon.center.dy, 2));
      // Beside the icons, labels are set at the size of button labels.
      final style = rail.selectedLabelTextStyle!;
      final theme = MmVariant.light.theme;
      expect(style.fontSize, theme.textTheme.labelLarge!.fontSize);
      expect(style.color, MmColorModes.light.ink);
      expect(rail.unselectedLabelTextStyle!.color, MmColorModes.light.inkMuted);
    });

    testWidgets('the narrow rail keeps the theme label styles', (tester) async {
      await pumpScreen(tester, _scaffold(), size: _tablet);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedLabelTextStyle, isNull);
      expect(rail.unselectedLabelTextStyle, isNull);
    });

    testWidgets('mirrors in Urdu: the rail on the right', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(),
        size: _tablet,
        variant: MmVariant.urdu,
      );
      final rail = tester.getRect(find.byType(NavigationRail));
      expect(rail.right, _tablet.width);
      final rule = tester.getRect(find.byType(VerticalDivider));
      expect(rule.right, rail.left);
      expect(
        tester.getRect(find.text('Rent roll')).center.dx,
        lessThan(rule.left),
      );
    });

    testWidgets('mirrors in Urdu: the extended rail on the right', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(),
        size: _desktop,
        variant: MmVariant.urdu,
      );
      expect(tester.getRect(find.byType(NavigationRail)).right, _desktop.width);
      final icon = tester.getRect(find.byIcon(MmIcons.reports));
      expect(_labelRect(tester, 'Reports').right, lessThan(icon.left));
    });

    for (final (name, size) in [('bar', _phone), ('rail', _tablet)]) {
      testWidgets('$name: tapping a destination reports its index', (
        tester,
      ) async {
        final selected = <int>[];
        await pumpScreen(
          tester,
          _scaffold(onSelected: selected.add),
          size: size,
        );
        await tester.tap(find.text('Dues'));
        await tester.tap(find.text('Properties'));
        expect(selected, [2, 0]);
      });

      testWidgets('$name: Tab reaches the destinations, Enter selects', (
        tester,
      ) async {
        final selected = <int>[];
        await pumpScreen(
          tester,
          _scaffold(onSelected: selected.add),
          size: size,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.text('Tenants')),
          isSemantics(isFocused: true),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(selected, [1, 2]);
      });

      testWidgets('$name: each destination reads as a tab with its count', (
        tester,
      ) async {
        await pumpScreen(tester, _scaffold(selected: 1), size: size);
        expect(
          tester.getSemantics(find.text('Tenants')),
          isSemantics(
            label: 'Tenants\nTab 2 of 4',
            isSelected: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.text('Dues')),
          isSemantics(
            label: 'Dues\nTab 3 of 4',
            value: '3',
            isSelected: false,
            hasTapAction: true,
          ),
        );
        // The badge is drawn but read only as the value.
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('$name: the selected destination shows its selected icon', (
        tester,
      ) async {
        await pumpScreen(tester, _scaffold(), size: size);
        expect(find.byIcon(MmIcons.tenants), findsOneWidget);
        expect(find.byIcon(MmIcons.person), findsNothing);
        await pumpScreen(tester, _scaffold(selected: 1), size: size);
        expect(find.byIcon(MmIcons.person), findsOneWidget);
        expect(find.byIcon(MmIcons.tenants), findsNothing);
      });
    }

    testWidgets('a zero count shows no badge', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(
          destinations: const [
            MmDestination(icon: MmIcons.receipt, label: 'Dues', badgeCount: 0),
            MmDestination(icon: MmIcons.reports, label: 'Reports'),
          ],
        ),
      );
      expect(find.byType(Badge), findsNothing);
      expect(
        tester.getSemantics(find.text('Dues')),
        isSemantics(label: 'Dues\nTab 1 of 2', value: ''),
      );
    });

    testWidgets('counts over 999 show 999+ and are read in full', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(
          destinations: const [
            MmDestination(
              icon: MmIcons.receipt,
              label: 'Dues',
              badgeCount: 1200,
            ),
            MmDestination(icon: MmIcons.reports, label: 'Reports'),
          ],
        ),
      );
      expect(find.text('999+'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Dues')),
        isSemantics(value: '1200'),
      );
    });

    testEveryVariant('the badge count is Latin and grows at most 130%', (
      tester,
      variant,
    ) async {
      await pumpScreen(tester, _scaffold(), variant: variant);
      final text = tester.widget<Text>(find.text('3'));
      // The theme sets counts in the Latin face with tabular figures.
      final style = styleOf(tester, '3');
      expect(style.fontFamily, contains(MmFontFamily.latin));
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('3'))).scale(10),
        closeTo(10 * (variant.textScale > 1.3 ? 1.3 : variant.textScale), 0.01),
      );
      expect(text.data, '3');
      // Badges sit at the icon's top end, mirrored in Urdu.
      final icon = tester.getRect(find.byIcon(MmIcons.receipt));
      final count = tester.getRect(find.text('3'));
      if (variant == MmVariant.urdu) {
        expect(count.center.dx, lessThan(icon.center.dx));
      } else {
        expect(count.center.dx, greaterThan(icon.center.dx));
      }
    });

    testEveryVariant('the bar and the rail sit on the surface', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpScreen(tester, _scaffold(), variant: variant);
      Material material(Finder of) => tester.widget<Material>(
        find.descendant(of: of, matching: find.byType(Material)).first,
      );
      expect(material(find.byType(NavigationBar)).color, colors.surface);
      await resizeScreen(tester, _tablet);
      expect(material(find.byType(NavigationRail)).color, colors.surface);
    });

    testWidgets('the body keeps its state across size classes', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(body: const Scaffold(body: TextField())),
      );
      await tester.enterText(find.byType(TextField), 'Gulberg');
      for (final size in [_tablet, _desktop, _phone]) {
        await resizeScreen(tester, size);
        expect(find.text('Gulberg'), findsOneWidget);
      }
    });

    testWidgets('the body is not padded again on the rail side', (
      tester,
    ) async {
      EdgeInsets? bodyPadding;
      final body = Builder(
        builder: (context) {
          bodyPadding = MediaQuery.paddingOf(context);
          return const SizedBox.expand();
        },
      );
      tester.view.padding = const FakeViewPadding(left: 40, right: 30);
      addTearDown(tester.view.resetPadding);
      await pumpScreen(tester, _scaffold(body: body), size: _tablet);
      expect(bodyPadding!.left, 0);
      expect(bodyPadding!.right, 30);

      await pumpScreen(
        tester,
        _scaffold(body: body),
        size: _tablet,
        variant: MmVariant.urdu,
      );
      expect(bodyPadding!.left, 40);
      expect(bodyPadding!.right, 0);
    });

    testWidgets('keyboard focus finishes the rail before the body', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(
          body: const Align(
            alignment: AlignmentDirectional.topStart,
            child: TextButton(onPressed: tapped, child: Text('Add')),
          ),
        ),
        size: _tablet,
      );
      for (var i = 0; i < _destinations.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Reports')),
        isSemantics(isFocused: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Add')), isTrue);
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(),
        size: const Size(320, 640),
        variant: MmVariant.largeText,
      );
      expect(tester.takeException(), isNull);
      for (final destination in _destinations) {
        expect(find.text(destination.label), findsOneWidget);
      }
    });

    testWidgets('200% text in a short landscape window scrolls the rail', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(),
        size: const Size(720, 320),
        variant: MmVariant.largeText,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Reports'),
        50,
        scrollable: find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Reports'));
    });

    testWidgets('needs two destinations and a valid selection', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(
          destinations: const [
            MmDestination(icon: MmIcons.home, label: 'Home'),
          ],
        ),
      );
      expect(tester.takeException(), isAssertionError);
      await pumpScreen(tester, _scaffold(selected: 4));
      expect(tester.takeException(), isAssertionError);
    });
  });
}
