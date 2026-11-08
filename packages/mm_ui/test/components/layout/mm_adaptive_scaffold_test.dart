import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _urduDestinations = [
  MmDestination(icon: MmIcons.property, label: 'جائیدادیں'),
  MmDestination(icon: MmIcons.tenants, label: 'کرایہ دار'),
  MmDestination(icon: MmIcons.receipt, label: 'واجبات', badgeCount: 3),
  MmDestination(icon: MmIcons.reports, label: 'رپورٹس'),
];

/// Pumps [child] as the whole screen in [locale] at [textScale], in a
/// window of [size].
Future<void> _pumpIn(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
  required double textScale,
  Size size = _phone,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Where the glyphs of [label] reach on screen, top and bottom.
({double top, double bottom}) _inkOf(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  var top = 0.0;
  var bottom = paragraph.size.height;
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: label.length),
  )) {
    if (box.top < top) top = box.top;
    if (box.bottom > bottom) bottom = box.bottom;
  }
  final origin = paragraph.localToGlobal(Offset.zero);
  return (top: origin.dy + top, bottom: origin.dy + bottom);
}

/// The tap target of the destination labelled [label].
Rect _targetOf(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is InkResponse),
      )
      .first,
);

/// Where the glyph of [icon] is inked inside its square at [size]: the
/// bounding box of its painted pixels.
Future<Rect> _glyphInk(WidgetTester tester, IconData icon, double size) async {
  const key = Key('glyph');
  await tester.pumpWidget(
    themed(
      Center(
        child: RepaintBoundary(
          key: key,
          child: Icon(icon, size: size),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(boundary.toImage))!;
  final bytes = (await tester.runAsync(image.toByteData))!;
  var left = image.width;
  var top = image.height;
  var right = 0;
  var bottom = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (bytes.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
      left = x < left ? x : left;
      top = y < top ? y : top;
      right = x + 1 > right ? x + 1 : right;
      bottom = y + 1 > bottom ? y + 1 : bottom;
    }
  }
  image.dispose();
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

/// The icon of a destination, with what is painted over it.
Finder _iconPaint(IconData icon) => find
    .ancestor(of: find.byIcon(icon), matching: find.byType(CustomPaint))
    .first;

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
      // Not a constant, so the assertion runs when the test does.
      final count = int.parse('-1');
      expect(
        () =>
            MmDestination(icon: MmIcons.home, label: 'Home', badgeCount: count),
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

    for (final locale in const [Locale('en'), Locale('ur')]) {
      for (final (window, size) in const [
        ('bar', _phone),
        ('rail', _landscapeTablet),
      ]) {
        testWidgets(
          'the badge never covers its icon (${locale.languageCode}, $window)',
          (tester) async {
            // Narrow and wide glyphs: the dots of "More" and a bell.
            for (final glyph in [MmIcons.more, MmIcons.notifications]) {
              final ink = await _glyphInk(tester, glyph, 24);
              await _pumpIn(
                tester,
                MmAdaptiveScaffold(
                  destinations: [
                    const MmDestination(icon: MmIcons.home, label: 'Home'),
                    MmDestination(icon: glyph, label: 'More', badgeCount: 3),
                  ],
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  body: const SizedBox.shrink(),
                ),
                locale: locale,
                textScale: 1,
                size: size,
              );
              final icon = tester.getRect(find.byIcon(glyph));
              expect(icon.size, const Size.square(24));
              final glyphRect = ink.shift(icon.topLeft);
              final badge = tester.getRect(
                find.descendant(
                  of: find.byType(Badge),
                  matching: find.byType(Container),
                ),
              );
              expect(
                badge.intersect(glyphRect).isEmpty,
                isTrue,
                reason: 'badge $badge over glyph $glyphRect',
              );
              // Past the icon's top end corner: to its right in English,
              // to its left in Urdu, its middle above the icon's middle.
              if (locale.languageCode == 'ur') {
                expect(badge.right, lessThanOrEqualTo(glyphRect.left));
                expect(badge.right, greaterThan(icon.left));
              } else {
                expect(badge.left, greaterThanOrEqualTo(glyphRect.right));
                expect(badge.left, lessThan(icon.right));
              }
              expect(badge.center.dy, lessThan(icon.center.dy));
            }
          },
        );
      }
    }

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

    for (final (language, destinations) in [
      ('English', _destinations),
      ('Urdu', _urduDestinations),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'bar: $language labels at ${scale}x stay inside the bar, clear of '
          'the indicator',
          (tester) async {
            await _pumpIn(
              tester,
              _scaffold(destinations: destinations),
              locale: Locale(language == 'Urdu' ? 'ur' : 'en'),
              textScale: scale,
              size: const Size(320, 640),
            );
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(find.byType(NavigationBar));
            expect(bar.height, greaterThanOrEqualTo(72));
            for (final destination in destinations) {
              final ink = _inkOf(tester, destination.label);
              expect(
                ink.bottom,
                lessThanOrEqualTo(bar.bottom - MmSpace.s1),
                reason: destination.label,
              );
              // The indicator is 32 dp tall, centred on the icon.
              final icon = tester.getRect(find.byIcon(destination.icon));
              expect(
                ink.top,
                greaterThanOrEqualTo(icon.center.dy + 16),
                reason: destination.label,
              );
              expect(
                _targetOf(tester, destination.label).height,
                greaterThanOrEqualTo(MmSize.minTarget),
              );
            }
            // Whole pixels keep the icons sharp.
            final icon = tester.getRect(find.byIcon(MmIcons.property));
            expect(icon.top, icon.top.roundToDouble());
          },
        );
      }
    }

    testWidgets("bar: sized by the theme's label style by default", (
      tester,
    ) async {
      await _pumpIn(
        tester,
        Builder(
          builder: (context) => Theme(
            // A bar theme without label styles or a height of its own.
            data: Theme.of(context)
                .copyWith(navigationBarTheme: const NavigationBarThemeData()),
            child: _scaffold(destinations: _urduDestinations),
          ),
        ),
        locale: const Locale('ur'),
        textScale: 1,
      );
      final bar = tester.getRect(find.byType(NavigationBar));
      expect(bar.height, greaterThan(72));
      for (final destination in _urduDestinations) {
        expect(
          _inkOf(tester, destination.label).bottom,
          lessThanOrEqualTo(bar.bottom - MmSpace.s1),
        );
      }
    });

    testWidgets('bar: English at 100% keeps the theme height', (tester) async {
      await pumpScreen(tester, _scaffold());
      expect(tester.getRect(find.byType(NavigationBar)).height, 72);
    });

    for (final (name, size) in [
      ('bar', _phone),
      ('rail', _tablet),
      ('extended rail', _desktop),
    ]) {
      for (final (language, destinations) in [
        ('English', _destinations),
        ('Urdu', _urduDestinations),
      ]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '$name: $language destinations at ${scale}x are 48 dp targets',
            (tester) async {
              await _pumpIn(
                tester,
                _scaffold(destinations: destinations),
                locale: Locale(language == 'Urdu' ? 'ur' : 'en'),
                textScale: scale,
                size: size,
              );
              final targets = [
                for (final destination in destinations)
                  _targetOf(tester, destination.label),
              ];
              for (final target in targets) {
                expect(target.height, greaterThanOrEqualTo(MmSize.minTarget));
                expect(target.width, greaterThanOrEqualTo(MmSize.minTarget));
              }
            },
          );
        }
      }
    }

    testWidgets('extended rail: lines of large Urdu labels do not touch', (
      tester,
    ) async {
      await _pumpIn(
        tester,
        _scaffold(destinations: _urduDestinations),
        locale: const Locale('ur'),
        textScale: 2,
        size: _desktop,
      );
      for (var i = 1; i < _urduDestinations.length; i++) {
        final above = _labelRect(tester, _urduDestinations[i - 1].label);
        final below = _labelRect(tester, _urduDestinations[i].label);
        expect(below.top - above.bottom, greaterThanOrEqualTo(2 * MmSpace.s1));
      }
    });

    for (final (name, size, indicator) in [
      ('bar', _phone, const Size(64, 32)),
      ('rail', _tablet, const Size(56, 32)),
      ('extended rail', _desktop, const Size(56, 32)),
    ]) {
      testEveryVariant('$name: keyboard focus rings the indicator', (
        tester,
        variant,
      ) async {
        useKeyboardHighlights();
        final colors = colorsOf(variant);
        await pumpScreen(tester, _scaffold(), size: size, variant: variant);
        final tenants = _iconPaint(MmIcons.tenants);
        final ring = paints..rrect(color: colors.focus);
        expect(tenants, isNot(ring));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        // The ring follows the indicator's edge, centred on the icon.
        final icon = tester.getSize(tenants);
        final edge = Rect.fromCenter(
          center: icon.center(Offset.zero),
          width: indicator.width,
          height: indicator.height,
        ).deflate(MmSize.focusRing / 2);
        expect(
          tenants,
          paints..rrect(
            rrect: RRect.fromRectAndRadius(
              edge,
              Radius.circular(edge.height / 2),
            ),
            color: colors.focus,
            strokeWidth: MmSize.focusRing,
            style: PaintingStyle.stroke,
          ),
        );
        // Only the focused destination is ringed.
        expect(_iconPaint(MmIcons.property), isNot(ring));
        // The ring stands out from the surface and from a selected
        // destination's indicator.
        expect(
          mmContrastRatio(colors.focus, colors.surface),
          greaterThanOrEqualTo(mmMinimumIconContrast),
        );
        expect(
          mmContrastRatio(colors.focus, colors.primaryContainer),
          greaterThanOrEqualTo(mmMinimumIconContrast),
        );
        // Focus is the ring alone: no tinted pill that would read as a
        // second selection.
        expect(
          Theme.of(tester.element(find.byIcon(MmIcons.tenants))).focusColor,
          Colors.transparent,
        );
        // The selected destination is ringed too when it has focus.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(_iconPaint(MmIcons.property), ring);
        expect(_iconPaint(MmIcons.tenants), isNot(ring));
      });

      testWidgets('$name: no ring for touch focus', (tester) async {
        await pumpScreen(tester, _scaffold(), size: size);
        Focus.of(tester.element(find.byIcon(MmIcons.tenants))).requestFocus();
        await tester.pumpAndSettle();
        expect(
          Focus.of(tester.element(find.byIcon(MmIcons.tenants))).hasFocus,
          isTrue,
        );
        expect(
          _iconPaint(MmIcons.tenants),
          isNot(paints..rrect(color: MmColorModes.light.focus)),
        );
      });
    }

    testWidgets('bar: Tab moves right to left in Urdu', (tester) async {
      await pumpScreen(tester, _scaffold(), variant: MmVariant.urdu);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Properties')),
        isSemantics(isFocused: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Tenants')),
        isSemantics(isFocused: true),
      );
      expect(
        _labelRect(tester, 'Tenants').center.dx,
        lessThan(_labelRect(tester, 'Properties').center.dx),
      );
    });

    testWidgets('bar: the indicator moves in the standard duration, or cuts '
        'with reduced motion', (tester) async {
      await pumpScreen(tester, _scaffold());
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        MmDuration.standard,
      );
      await pumpScreen(tester, withoutAnimations(_scaffold()));
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero,
      );
    });

    for (final (name, size) in [('bar', _phone), ('rail', _tablet)]) {
      testWidgets('$name: a snack bar from the screen clears its action bar', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          _scaffold(
            body: Builder(
              builder: (context) => MmPage(
                title: 'Record payment',
                body: const Text('Rs 45,000 from Ayesha Khan'),
                bottomBar: MmActionBar(
                  primary: FilledButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded')),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ),
            ),
          ),
          size: size,
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final snack = tester.getRect(find.byType(SnackBar));
        expect(
          snack.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(MmActionBar)).top),
        );
        expect(
          snack.overlaps(tester.getRect(find.byType(FilledButton))),
          isFalse,
        );
      });
    }

    testWidgets('the body keeps its snack bar across size classes', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _scaffold(
          body: Builder(
            builder: (context) => MmPage(
              title: 'Dues',
              body: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder sent'),
                    duration: Duration(minutes: 1),
                  ),
                ),
                child: const Text('Remind'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Remind'));
      await tester.pumpAndSettle();
      await resizeScreen(tester, _tablet);
      expect(find.text('Reminder sent'), findsOneWidget);
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

    group("holds at most five destinations in a phone's bar", () {
      const six = [
        ..._destinations,
        MmDestination(icon: MmIcons.ledger, label: 'Money'),
        MmDestination(icon: MmIcons.settings, label: 'Settings'),
      ];

      testWidgets('and says so in debug builds for a sixth', (tester) async {
        await pumpScreen(tester, _scaffold(destinations: six));
        final error = tester.takeException();
        expect(error, isAssertionError);
        expect(
          '$error',
          allOf(
            contains('6 destinations'),
            contains('at most 5'),
            contains('"More"'),
          ),
        );
      });

      testWidgets('takes five', (tester) async {
        await pumpScreen(tester, _scaffold(destinations: six.sublist(0, 5)));
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationDestination), findsNWidgets(5));
      });

      for (final size in const [_tablet, _desktop]) {
        testWidgets('but any number in the rail (${size.width} dp)', (
          tester,
        ) async {
          await pumpScreen(tester, _scaffold(destinations: six), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('Settings'), findsOneWidget);
        });
      }
    });
  });

  group('MmAdaptiveScaffold bar labels', () {
    const five = [
      MmDestination(icon: MmIcons.reports, label: 'Dashboard'),
      MmDestination(icon: MmIcons.property, label: 'Properties'),
      MmDestination(icon: MmIcons.tenants, label: 'Tenants'),
      MmDestination(icon: MmIcons.receipt, label: 'Dues', badgeCount: 3),
      MmDestination(icon: MmIcons.settings, label: 'Settings'),
    ];

    /// The text scale the bar's labels are set at.
    double labelScale(WidgetTester tester, String label) {
      final paragraph = paragraphOf(tester, label);
      final size = paragraph.text.style!.fontSize!;
      return paragraph.textScaler.scale(size) / size;
    }

    for (final (variant, width) in [
      (MmVariant.largeText, 320.0),
      (MmVariant.largeText, 360.0),
      (MmVariant.light, 320.0),
    ]) {
      testWidgets('five destinations never break a word '
          '(${variant.name}, $width dp)', (tester) async {
        await pumpScreen(
          tester,
          _scaffold(destinations: five),
          size: Size(width, 740),
          variant: variant,
        );
        expect(tester.takeException(), isNull);
        expectWholeWords(tester, within: find.byType(NavigationBar));
        for (final destination in five) {
          expect(find.text(destination.label), findsOneWidget);
          // Never below the labels' standard size.
          expect(
            labelScale(tester, destination.label),
            greaterThanOrEqualTo(1),
          );
        }
      });
    }

    testWidgets('in Urdu at 200%, never break a word either', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedApp(
          _scaffold(
            destinations: const [
              MmDestination(icon: MmIcons.reports, label: 'ڈیش بورڈ'),
              MmDestination(icon: MmIcons.property, label: 'جائیدادیں'),
              MmDestination(icon: MmIcons.tenants, label: 'کرایہ دار'),
              MmDestination(icon: MmIcons.receipt, label: 'واجبات'),
              MmDestination(icon: MmIcons.settings, label: 'ترتیبات'),
            ],
          ),
          variant: MmVariant.largeText,
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectWholeWords(tester, within: find.byType(NavigationBar));
      expect(find.text('جائیدادیں'), findsOneWidget);
    });

    testWidgets('shrink only as far as the longest word needs', (tester) async {
      await pumpScreen(
        tester,
        _scaffold(destinations: five),
        size: const Size(320, 740),
        variant: MmVariant.largeText,
      );
      final scale = labelScale(tester, 'Dashboard');
      // Material lets bar labels grow to 130%; "Dashboard" in a 64 dp
      // destination cannot.
      expect(scale, lessThan(1.3));
      final word = paragraphOf(tester, 'Dashboard');
      expect(word.size.width, lessThanOrEqualTo(320 / 5));
      // Every label shares the scale.
      expect(labelScale(tester, 'Dues'), closeTo(scale, 1e-9));

      // Four destinations at 360 dp have room for 130%.
      await pumpScreen(tester, _scaffold(), variant: MmVariant.largeText);
      expect(labelScale(tester, 'Properties'), closeTo(1.3, 1e-9));
    });

    testWidgets('show icons alone, with the labels as tooltips and for '
        'screen readers, when a word does not fit even at the standard size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const long = [
        MmDestination(icon: MmIcons.reports, label: 'Dashboard'),
        MmDestination(icon: MmIcons.property, label: 'Neighbourhoods'),
        MmDestination(icon: MmIcons.tenants, label: 'Tenancies'),
        MmDestination(icon: MmIcons.receipt, label: 'Collections'),
        MmDestination(icon: MmIcons.settings, label: 'Preferences'),
      ];
      await pumpScreen(
        tester,
        _scaffold(destinations: long),
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == 'Neighbourhoods',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Neighbourhoods')), findsOneWidget);
      semantics.dispose();
    });
  });
}
