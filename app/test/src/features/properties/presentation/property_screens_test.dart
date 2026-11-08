import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/properties_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_form_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/unit_screens.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

/// The test app working in Saddar Plaza, where the user is a manager.
TestApp _asManager() => TestApp(
  settings: {AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}'},
);

/// The test app where the user is a viewer of Gulberg Houses.
TestApp _asViewer() => TestApp(portfolios: const [gulbergAsViewer, plaza]);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byWidgetPredicate((widget) => widget is Dialog),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is MmTextField && widget.label == label,
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(
    find.descendant(of: _field(label), matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  final target = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == field,
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option, findRichText: true).last);
  await tester.pumpAndSettle();
}

Widget _detail() => PropertyDetailScreen(propertyId: gulbergHouse.id);
Widget _unit() =>
    UnitDetailScreen(propertyId: gulbergHouse.id, unitId: groundFloor.id);

void main() {
  group('the property list', () {
    testWidgets('shows properties in use, archived, and leads on', (
      tester,
    ) async {
      final app = await pumpScreen(tester, PropertiesScreen.new);
      expect(find.text('Gulberg House'), findsOneWidget);
      expect(find.text('House\u00a0· Gulberg III, Lahore'), findsOneWidget);
      expect(find.text('DHA plot'), findsNothing);
      await _tap(tester, 'Archived');
      expect(find.text('DHA plot'), findsOneWidget);
      expect(find.text('Plot\u00a0· Karachi'), findsOneWidget);
      await _tap(tester, 'In use');
      await _tap(tester, 'Gulberg House');
      expect(routeShown(Routes.property(gulbergHouse.id)), findsOneWidget);
      expect(app.properties.calls.first.$2, [gulberg.id, false, null]);
    });

    testWidgets('reads more, page by page', (tester) async {
      final app = TestApp()..properties.pageLimit = 1;
      app.properties.byPortfolio[gulberg.id]!.add(saddarPlaza);
      await pumpScreen(tester, PropertiesScreen.new, app: app);
      expect(find.text('Saddar Plaza'), findsNothing);
      app.properties.gate.failure = const NetworkFailure();
      await _tap(tester, 'Show more');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      app.properties.gate.failure = null;
      await _tap(tester, 'Show more');
      expect(find.text('Saddar Plaza'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('empty lists say what to do', (tester) async {
      final app = TestApp()..properties.byPortfolio[gulberg.id]!.clear();
      await pumpScreen(tester, PropertiesScreen.new, app: app);
      expect(find.text('No properties yet'), findsOneWidget);
      await _tap(tester, 'Archived');
      expect(find.text('No archived properties.'), findsOneWidget);
    });

    testWidgets('owners and managers add; viewers do not', (tester) async {
      await pumpScreen(tester, PropertiesScreen.new);
      await _tap(tester, 'Add property');
      expect(routeShown(Routes.newProperty), findsOneWidget);
      await pumpScreen(tester, PropertiesScreen.new, app: _asViewer());
      expect(find.text('Add property'), findsNothing);
    });

    testWidgets('a list that cannot load says so; loading shows a skeleton', (
      tester,
    ) async {
      final app = TestApp()..properties.readFailure = const Forbidden();
      await pumpScreen(tester, PropertiesScreen.new, app: app);
      expect(find.text('The properties could not be loaded'), findsOneWidget);
      app.properties.readFailure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Gulberg House'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton', (tester) async {
      final slow = TestApp()..portfolios.gate.close();
      await pumpScreen(tester, PropertiesScreen.new, app: slow, settle: false);
      expect(find.bySemanticsLabel('Loading the properties'), findsOneWidget);
      slow.portfolios.gate.open();
      await tester.pumpAndSettle();
    });
  });

  group('a property', () {
    testWidgets('shows its details, rule and units', (tester) async {
      await pumpScreen(tester, _detail, size: const Size(360, 2400));
      expect(find.byType(MmNameplate), findsOneWidget);
      expect(find.text('42-B, Main Boulevard'), findsOneWidget);
      expect(find.text('10 Marla'), findsOneWidget);
      expect(find.text('3200 sq ft'), findsOneWidget);
      expect(find.text('1 Mar 2015'), findsOneWidget);
      expect(
        find.textContaining('within 15 days of the tenant moving in'),
        findsOneWidget,
      );
      expect(find.text('Ground floor'), findsOneWidget);
      expect(find.text('Portion\u00a0· Asking Rs\u00a085,000'), findsOneWidget);
      expect(shown('Let'), findsOneWidget);
      expect(shown('Vacant since 1 Sept 2026'), findsOneWidget);
      expect(shown('Not available'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.editProperty(gulbergHouse.id)), findsOneWidget);
    });

    testWidgets('leads to its units and adds one', (tester) async {
      await pumpScreen(tester, _detail, size: const Size(360, 2400));
      await _tap(tester, 'Add unit');
      expect(routeShown(Routes.newUnit(gulbergHouse.id)), findsOneWidget);
      await pumpScreen(tester, _detail, size: const Size(360, 2400));
      await _tap(tester, 'First floor');
      expect(
        routeShown(Routes.unit(gulbergHouse.id, firstFloor.id)),
        findsOneWidget,
      );
    });

    testWidgets('is archived after confirming, and restored', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 2400),
      );
      await _tap(tester, 'Archive');
      expect(find.text('Archive Gulberg House?'), findsOneWidget);
      await _confirm(tester, 'Archive');
      expect(find.text('Gulberg House archived.'), findsOneWidget);
      expect(find.textContaining('Archived on 7 Nov 2026.'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.text('Add unit'), findsNothing);
      await _tap(tester, 'Put back in use');
      expect(find.text('Gulberg House is back in use.'), findsOneWidget);
      expect(
        app.properties.calls.where((c) => c.$1 == 'archiveProperty'),
        hasLength(2),
      );
    });

    testWidgets('is deleted by an owner typing its name', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 2400),
      );
      await _tap(tester, 'Delete');
      expect(find.text('Delete Gulberg House?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is Dialog),
          matching: find.byType(TextField),
        ),
        'Gulberg House',
      );
      await tester.pump();
      await _confirm(tester, 'Delete');
      expect(app.properties.calls.last.$1, 'deleteProperty');
      expect(routeShown(Routes.properties), findsOneWidget);
      expect(find.text('Gulberg House deleted.'), findsOneWidget);
    });

    testWidgets('a refused delete says to archive instead', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 2400),
      );
      app.properties.gate.failure = const RejectedFailure('still_in_use');
      await _tap(tester, 'Delete');
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is Dialog),
          matching: find.byType(TextField),
        ),
        'Gulberg House',
      );
      await tester.pump();
      await _confirm(tester, 'Delete');
      expect(find.textContaining('Archive it instead.'), findsOneWidget);
    });

    testWidgets('managers archive but do not delete; viewers only look', (
      tester,
    ) async {
      final app = _asManager();
      await pumpScreen(
        tester,
        () => PropertyDetailScreen(propertyId: saddarPlaza.id),
        app: app,
      );
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await pumpScreen(tester, _detail, app: _asViewer());
      expect(find.text('Archive'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.text('Add unit'), findsNothing);
    });

    testWidgets('a property or its units that cannot load say so', (
      tester,
    ) async {
      final app = TestApp()..properties.readFailure = const NotFoundFailure();
      await pumpScreen(tester, _detail, app: app);
      expect(find.text('This property could not be loaded'), findsOneWidget);
      final noUnits = TestApp()..properties.unitList.clear();
      await pumpScreen(
        tester,
        _detail,
        app: noUnits,
        size: const Size(360, 2400),
      );
      expect(find.textContaining('No units yet.'), findsOneWidget);
    });

    testWidgets('units read more, page by page', (tester) async {
      final app = TestApp()..properties.pageLimit = 2;
      await pumpScreen(tester, _detail, app: app, size: const Size(360, 2600));
      expect(find.text('Annexe room'), findsNothing);
      await _tap(tester, 'Show more');
      expect(find.text('Annexe room'), findsOneWidget);
    });
  });

  group('the property form', () {
    testWidgets('checks, shows the province rule, and adds', (tester) async {
      final app = await pumpScreen(
        tester,
        PropertyFormScreen.new,
        size: const Size(360, 3000),
      );
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsWidgets);
      expect(
        app.properties.calls.where((c) => c.$1 == 'createProperty'),
        isEmpty,
      );
      await _type(tester, 'Name', 'Model Town flat');
      await _type(tester, 'City', 'Lahore');
      await _type(tester, 'Plot size', '0');
      await _type(tester, 'Covered area (sq ft)', '0');
      await _type(tester, 'Year built', '1700');
      await _tap(tester, 'Save');
      expect(shown('Enter a number above 0'), findsOneWidget);
      expect(shown('Enter a number from 1 to 9999999.'), findsOneWidget);
      expect(shown('Enter a number from 1850 to 2100.'), findsOneWidget);
      await _type(tester, 'Plot size', '۵.۵');
      await _type(tester, 'Covered area (sq ft)', '1200');
      await _type(tester, 'Year built', '2019');
      await _type(tester, 'Notes', 'Top floor');
      await _choose(tester, 'Type', 'Flat');
      await _choose(tester, 'Province', 'Khyber Pakhtunkhwa');
      expect(
        find.textContaining('within 7 days of signing the agreement'),
        findsOneWidget,
      );
      await _choose(tester, 'Province', 'Islamabad');
      expect(
        find.textContaining('no law the app knows of sets a deadline'),
        findsOneWidget,
      );
      await _choose(tester, 'Measured in', 'Kanal');
      await tester.ensureVisible(find.byType(MmMoneyField).first);
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is MmMoneyField && w.label == 'Purchase price',
          ),
          matching: find.byType(TextField),
        ),
        '2500000',
      );
      await tester.pump();
      await _tap(tester, 'Save');
      final created =
          app.properties.calls
                  .firstWhere((c) => c.$1 == 'createProperty')
                  .$2
                  .last!
              as Property;
      expect(created.name, 'Model Town flat');
      expect(created.type, PropertyType.apartment);
      expect(created.province, Province.islamabad);
      expect(created.plotSize, const Hundredths(550));
      expect(created.plotSizeUnit, AreaUnit.kanal);
      expect(created.coveredAreaSqft, 1200);
      expect(created.yearBuilt, 2019);
      expect(created.purchasePrice, const Money.fromRupees(2500000));
      expect(find.text('Model Town flat added.'), findsOneWidget);
      expect(routeShown(Routes.property(created.id)), findsOneWidget);
    });

    testWidgets('a name in use is shown on the field; a retry is the same', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        PropertyFormScreen.new,
        size: const Size(360, 3000),
      );
      await _type(tester, 'Name', 'Gulberg House');
      await _type(tester, 'City', 'Lahore');
      await _choose(tester, 'Province', 'Punjab');
      app.properties.gate.failure = const RejectedFailure(
        'duplicate_property_name',
      );
      await _tap(tester, 'Save');
      expect(
        tester.widget<MmTextField>(_field('Name')).errorText,
        'Another property in use has this name. Choose another.',
      );
      app.properties.gate.failure = const NetworkFailure();
      await _type(tester, 'Name', 'Gulberg House 2');
      await _tap(tester, 'Save');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      app.properties.gate.failure = null;
      await _tap(tester, 'Save');
      final ids = {
        for (final call in app.properties.calls)
          if (call.$1 == 'createProperty') (call.$2.last! as Property).id,
      };
      expect(ids, hasLength(1));
      await pumpScreen(
        tester,
        PropertyFormScreen.new,
        size: const Size(360, 3000),
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.properties), findsOneWidget);
    });

    testWidgets('editing starts from the property and saves it', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        () => PropertyFormScreen(propertyId: gulbergHouse.id),
        size: const Size(360, 3000),
      );
      expect(find.text('Edit property'), findsOneWidget);
      expect(find.text('Gulberg House'), findsOneWidget);
      await _type(tester, 'Name', 'Gulberg Home');
      await _type(tester, 'Plot size', '');
      await _tap(tester, 'Save');
      final saved = app.properties.calls.last.$2.single! as Property;
      expect(saved.name, 'Gulberg Home');
      expect(saved.plotSize, isNull);
      expect(saved.plotSizeUnit, isNull);
      expect(find.text('Gulberg Home saved.'), findsOneWidget);
      await pumpScreen(
        tester,
        () => PropertyFormScreen(propertyId: gulbergHouse.id),
        size: const Size(360, 3000),
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.property(gulbergHouse.id)), findsOneWidget);
    });

    testWidgets('a property to edit that cannot load says so', (tester) async {
      final app = TestApp()..properties.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => PropertyFormScreen(propertyId: gulbergHouse.id),
        app: app,
      );
      expect(find.text('This property could not be loaded'), findsOneWidget);
    });
  });

  group('a unit', () {
    testWidgets('shows what it is and whether it is let', (tester) async {
      await pumpScreen(tester, _unit, size: const Size(360, 1600));
      expect(find.text('Ground floor'), findsWidgets);
      expect(shown('Let'), findsOneWidget);
      expect(find.text('Gulberg House'), findsOneWidget);
      expect(find.text('Portion'), findsOneWidget);
      expect(find.text('Unfurnished'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(
        routeShown(Routes.editUnit(gulbergHouse.id, groundFloor.id)),
        findsOneWidget,
      );
    });

    testWidgets('is archived, restored and deleted', (tester) async {
      final app = await pumpScreen(tester, _unit, size: const Size(360, 1600));
      await _tap(tester, 'Archive');
      await _confirm(tester, 'Archive');
      expect(find.text('Ground floor archived.'), findsOneWidget);
      await _tap(tester, 'Put back in use');
      expect(find.text('Ground floor is back in use.'), findsOneWidget);
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(app.properties.calls.last.$1, 'deleteUnit');
      expect(routeShown(Routes.property(gulbergHouse.id)), findsOneWidget);
    });

    testWidgets('a refused delete is explained', (tester) async {
      final app = await pumpScreen(tester, _unit, size: const Size(360, 1600));
      app.properties.gate.failure = const RejectedFailure('still_in_use');
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(find.textContaining('Archive it instead.'), findsOneWidget);
    });

    testWidgets('a unit that cannot load says so; viewers only look', (
      tester,
    ) async {
      final app = TestApp()..properties.readFailure = const Forbidden();
      await pumpScreen(tester, _unit, app: app);
      expect(find.text('This unit could not be loaded'), findsOneWidget);
      await pumpScreen(tester, _unit, app: _asViewer());
      expect(find.text('Archive'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('extra content from later features shows', (tester) async {
      await pumpScreen(
        tester,
        () => UnitDetailScreen(
          propertyId: gulbergHouse.id,
          unitId: groundFloor.id,
          extras: (summary) => Text('extra ${summary.unit.label}'),
        ),
        size: const Size(360, 1600),
      );
      expect(find.text('extra Ground floor'), findsOneWidget);
    });
  });

  group('the unit form', () {
    testWidgets('checks, then adds a unit', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UnitFormScreen(propertyId: gulbergHouse.id),
        size: const Size(360, 2000),
      );
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _type(tester, 'Name or number', 'Shop 5');
      await _type(tester, 'Bedrooms', '99');
      await _tap(tester, 'Save');
      expect(shown('Enter a number from 0 to 50.'), findsOneWidget);
      await _type(tester, 'Bedrooms', '');
      await _type(tester, 'Bathrooms', '1');
      await _type(tester, 'Floor', 'Ground');
      await _choose(tester, 'Type', 'Shop');
      await tester.tap(find.text('Furnished', findRichText: true));
      await tester.tap(find.text('Available to rent', findRichText: true));
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byType(MmMoneyField),
          matching: find.byType(TextField),
        ),
        '45000',
      );
      await tester.pump();
      await _tap(tester, 'Save');
      final created =
          app.properties.calls.firstWhere((c) => c.$1 == 'createUnit').$2.last!
              as Unit;
      expect(created.label, 'Shop 5');
      expect(created.type, UnitType.shop);
      expect(created.bathrooms, 1);
      expect(created.bedrooms, isNull);
      expect(created.furnished, isTrue);
      expect(created.isAvailable, isFalse);
      expect(created.askingRent, const Money.fromRupees(45000));
      expect(find.text('Shop 5 added.'), findsOneWidget);
    });

    testWidgets('a label in use is shown on the field; cancel goes back', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        () => UnitFormScreen(propertyId: gulbergHouse.id),
        size: const Size(360, 2000),
      );
      app.properties.gate.failure = const RejectedFailure(
        'duplicate_unit_label',
      );
      await _type(tester, 'Name or number', 'Ground floor');
      await _tap(tester, 'Save');
      expect(
        tester.widget<MmTextField>(_field('Name or number')).errorText,
        'Another unit of this property has this name. Choose another.',
      );
      app.properties.gate.failure = const Forbidden();
      await _type(tester, 'Name or number', 'Ground floor 2');
      await _tap(tester, 'Save');
      expect(
        find.text('You do not have permission to do this.'),
        findsOneWidget,
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.property(gulbergHouse.id)), findsOneWidget);
    });

    testWidgets('editing saves the unit', (tester) async {
      final app = await pumpScreen(
        tester,
        () =>
            UnitFormScreen(propertyId: gulbergHouse.id, unitId: groundFloor.id),
        size: const Size(360, 2000),
      );
      expect(find.text('Edit unit'), findsOneWidget);
      await _type(tester, 'Name or number', 'Ground portion');
      await _tap(tester, 'Save');
      expect(
        (app.properties.calls.firstWhere((c) => c.$1 == 'updateUnit').$2.single!
                as Unit)
            .label,
        'Ground portion',
      );
      expect(find.text('Ground portion saved.'), findsOneWidget);
      await pumpScreen(
        tester,
        () =>
            UnitFormScreen(propertyId: gulbergHouse.id, unitId: groundFloor.id),
        size: const Size(360, 2000),
      );
      await _tap(tester, 'Cancel');
      expect(
        routeShown(Routes.unit(gulbergHouse.id, groundFloor.id)),
        findsOneWidget,
      );
      final broken = TestApp()..properties.readFailure = const Forbidden();
      await pumpScreen(
        tester,
        () =>
            UnitFormScreen(propertyId: gulbergHouse.id, unitId: groundFloor.id),
        app: broken,
      );
      expect(find.text('This unit could not be loaded'), findsOneWidget);
    });
  });

  testEveryVariant('property screens fit at 320 dp', (tester, variant) async {
    for (final screen in <Widget Function()>[
      PropertiesScreen.new,
      _detail,
      PropertyFormScreen.new,
      () => PropertyFormScreen(propertyId: gulbergHouse.id),
      _unit,
      () => UnitFormScreen(propertyId: gulbergHouse.id),
    ]) {
      await pumpScreen(
        tester,
        screen,
        variant: variant,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: '$screen');
      await expectAccessible(tester);
    }
  });
}
