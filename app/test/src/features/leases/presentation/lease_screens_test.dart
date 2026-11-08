import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_form_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/tenancy_list.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

TestApp _asViewer() => TestApp(portfolios: const [gulbergAsViewer, plaza]);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
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

Future<void> _select<T>(
  WidgetTester tester,
  String label,
  String option,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option, findRichText: true).last);
  await tester.pumpAndSettle();
}

Future<void> _money(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is MmMoneyField && widget.label == label,
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Widget _detail() => LeaseDetailScreen(leaseId: aliLease.id);
Widget _newLease() => LeaseFormScreen(unitId: firstFloor.id);

LeaseTerms _terms(TestApp app, String call) {
  final arguments = app.leases.calls.lastWhere((c) => c.$1 == call).$2;
  return arguments.last! as LeaseTerms;
}

void main() {
  group('starting a tenancy', () {
    testWidgets('needs a tenant and a rent, then starts', (tester) async {
      final app = await pumpScreen(
        tester,
        _newLease,
        size: const Size(360, 4200),
      );
      expect(find.text('First floor'), findsOneWidget);
      await _tap(tester, 'Start tenancy');
      expect(find.text('Choose the tenant.'), findsWidgets);
      expect(find.text('Enter the rent, an amount above 0.'), findsOneWidget);
      expect(app.leases.calls.where((c) => c.$1 == 'createLease'), isEmpty);
      await _select<String>(tester, 'Tenant', 'Ali Raza');
      await _money(tester, 'Monthly rent', '65000');
      await _money(tester, 'Security deposit', '130000');
      await _select<Object>(tester, 'Term', '12 months');
      await _tap(tester, 'A percent of the late rent');
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is MmTextField && w.label == 'Fee (%)',
          ),
          matching: find.byType(TextField),
        ),
        '2.5',
      );
      await tester.pump();
      expect(find.textContaining('rounded to Rs\u00a0100'), findsOneWidget);
      await _tap(tester, 'Start tenancy');
      final call = app.leases.calls.lastWhere((c) => c.$1 == 'createLease');
      expect(call.$2[2], firstFloor.id);
      expect(call.$2[3], aliRaza.id);
      final terms = call.$2.last! as LeaseTerms;
      expect(terms.monthlyRent, const Money.fromRupees(65000));
      expect(terms.securityDeposit, const Money.fromRupees(130000));
      expect(terms.endDate, terms.startDate.addMonths(12).addDays(-1));
      expect(terms.lateFee, const PercentLateFee(250));
      expect(terms.rentDueDay, 5);
      expect(terms.incrementBasisPoints, 1000);
      expect(find.text('Tenancy started for Ali Raza.'), findsOneWidget);
    });

    testWidgets('a periodic tenancy with a daily fee, and an overlap', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        () => LeaseFormScreen(unitId: firstFloor.id, tenantId: aliRaza.id),
        size: const Size(360, 4200),
      );
      await _money(tester, 'Monthly rent', '65000');
      await _select<Object>(tester, 'Term', 'Month to month');
      await _tap(tester, 'An amount per day late');
      await _tap(tester, 'Start tenancy');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _money(tester, 'Fee', '300');
      await _money(tester, 'At most', '3000');
      app.leases.gate.failure = const RejectedFailure('lease_overlap');
      await _tap(tester, 'Start tenancy');
      expect(
        find.textContaining('The unit is let for some of these dates'),
        findsOneWidget,
      );
      final terms = _terms(app, 'createLease');
      expect(terms.endDate, isNull);
      expect(
        terms.lateFee,
        const DailyLateFee(Money.fromRupees(300), cap: Money.fromRupees(3000)),
      );
      await _tap(tester, 'Cancel');
      expect(
        routeShown(Routes.unit(gulbergHouse.id, firstFloor.id)),
        findsOneWidget,
      );
    });

    testWidgets('a custom term starts from the term before', (tester) async {
      final app = await pumpScreen(
        tester,
        () => LeaseFormScreen(unitId: firstFloor.id, tenantId: aliRaza.id),
        size: const Size(360, 4200),
      );
      await _money(tester, 'Monthly rent', '65000');
      await _select<Object>(tester, 'Term', 'Until a date');
      await _tap(tester, 'Start tenancy');
      expect(_terms(app, 'createLease').endDate, isNotNull);
    });

    testWidgets('without tenants it says to add one first', (tester) async {
      final app = TestApp()..tenants.byPortfolio[gulberg.id]!.clear();
      await pumpScreen(
        tester,
        _newLease,
        app: app,
        size: const Size(360, 3000),
      );
      expect(find.textContaining('Add the tenant first'), findsOneWidget);
      await _tap(tester, 'Add tenant');
      expect(routeShown(Routes.newTenant), findsOneWidget);
    });

    testWidgets('a unit that cannot load says so', (tester) async {
      final app = TestApp()..properties.readFailure = const Forbidden();
      await pumpScreen(tester, _newLease, app: app);
      expect(find.text('This tenancy could not be loaded'), findsOneWidget);
    });

    testWidgets('without a unit it waits', (tester) async {
      await pumpScreen(tester, LeaseFormScreen.new, settle: false);
      expect(find.bySemanticsLabel('Loading the tenancy'), findsOneWidget);
    });
  });

  group('editing a tenancy', () {
    testWidgets('keeps the rent and saves the terms', (tester) async {
      final app = await pumpScreen(
        tester,
        () => LeaseFormScreen(leaseId: aliLease.id),
        size: const Size(360, 4200),
      );
      expect(find.text('Edit tenancy terms'), findsOneWidget);
      expect(find.text('Monthly rent', findRichText: true), findsWidgets);
      await _select<PoliceStatus>(tester, 'Status', 'Registered');
      await _select<PoliceChannel>(
        tester,
        'Registered through',
        'Online portal',
      );
      await _select<RegistrarStatus>(
        tester,
        'Rent Registrar (Punjab)',
        'Registered',
      );
      await _tap(tester, 'Save');
      final terms = _terms(app, 'updateLease');
      expect(terms.policeStatus, PoliceStatus.registered);
      expect(terms.policeChannel, PoliceChannel.onlinePortal);
      expect(terms.registrarStatus, RegistrarStatus.registered);
      expect(terms.lateFee, aliLease.terms.lateFee);
      expect(find.text('Tenancy terms saved.'), findsOneWidget);
      expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
    });

    testWidgets('a tenancy that cannot load says so; cancel goes back', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => LeaseFormScreen(leaseId: aliLease.id),
        size: const Size(360, 4200),
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
    });

    testWidgets('a failed read', (tester) async {
      final app = TestApp()..leases.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => LeaseFormScreen(leaseId: aliLease.id),
        app: app,
      );
      expect(find.text('This tenancy could not be loaded'), findsOneWidget);
    });
  });

  group('a tenancy', () {
    testWidgets('shows its people, terms and the police deadline', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      expect(shown('Active'), findsOneWidget);
      expect(find.text('Unit\u00a0· Gulberg House'), findsOneWidget);
      expect(find.text("The law's deadline: 30 Jan 2026"), findsOneWidget);
      expect(find.textContaining('Past the deadline'), findsOneWidget);
      expect(find.text('Sana Raza'), findsOneWidget);
      expect(
        find.text('From January 2026\u00a0· Starting rent'),
        findsOneWidget,
      );
      expect(
        find.text(
          detailLine([
            'An amount per day late',
            'Rs\u00a0500',
            'At most Rs\u00a05,000',
          ]),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Open the registration website');
      expect(app.opened.single.host, 'punjabpolice.gov.pk');
      app.canOpenLinks = false;
      await _tap(tester, 'Open the registration website');
      expect(find.text('The link could not be opened.'), findsOneWidget);
      await tester.tap(find.widgetWithText(MmListTile, 'Ali Raza'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.tenant(aliRaza.id)), findsOneWidget);
    });

    testWidgets('opens its unit', (tester) async {
      await pumpScreen(tester, _detail, size: const Size(360, 3600));
      await _tap(tester, 'Unit\u00a0· Gulberg House');
      expect(
        routeShown(Routes.unit(gulbergHouse.id, groundFloor.id)),
        findsOneWidget,
      );
    });

    testWidgets('where no law sets a deadline, it is a reminder', (
      tester,
    ) async {
      final app = TestApp();
      final old = app.leases.leaseList.first;
      app.leases.leaseList[0] = Lease(
        id: old.id,
        unitId: old.unitId,
        tenantId: old.tenantId,
        status: old.status,
        terms: old.terms,
        tenantName: old.tenantName,
        unitLabel: old.unitLabel,
        propertyId: old.propertyId,
        propertyName: old.propertyName,
        province: Province.gilgitBaltistan,
      );
      await pumpScreen(tester, _detail, app: app, size: const Size(360, 3600));
      expect(find.text("The app's reminder: 16 Jan 2026"), findsOneWidget);
      expect(find.textContaining('this is only a reminder'), findsOneWidget);
      expect(find.text('Open the registration website'), findsNothing);
    });

    testWidgets('changes the rent from a month', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      await _tap(tester, 'Change rent');
      expect(find.byType(ChangeRentSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(MmButton, 'Change rent').last);
      await tester.pumpAndSettle();
      expect(shown('Enter the rent, an amount above 0.'), findsOneWidget);
      await _tap(tester, 'Use this');
      await _tap(tester, 'Agreed change');
      await tester.tap(find.widgetWithText(MmButton, 'Change rent').last);
      await tester.pumpAndSettle();
      final call = app.leases.calls.lastWhere((c) => c.$1 == 'changeRent');
      expect(call.$2[2], const Money.fromRupees(93500));
      expect(call.$2[3], RentChangeReason.renegotiation);
      expect(find.byType(ChangeRentSheet), findsNothing);
      expect(find.textContaining('Rent changed to Rs'), findsOneWidget);
    });

    testWidgets('ends after saying what happens to later dues', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      await _tap(tester, 'End tenancy');
      expect(find.byType(EndLeaseSheet), findsOneWidget);
      expect(find.textContaining('is voided, paid or not'), findsOneWidget);
      expect(
        find.textContaining("stays as the tenant's credit"),
        findsOneWidget,
      );
      await _tap(tester, 'Both agreed');
      await tester.tap(find.widgetWithText(MmButton, 'End tenancy').last);
      await tester.pumpAndSettle();
      final call = app.leases.calls.lastWhere((c) => c.$1 == 'endLease');
      expect(call.$2[2], EndReason.mutualAgreement);
      expect(find.text('Tenancy ended.'), findsOneWidget);
      expect(shown('Ended'), findsWidgets);
      expect(find.text('End tenancy'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('a refused end stays in the sheet', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      app.leases.gate.failure = const RejectedFailure('lease_not_active');
      await _tap(tester, 'End tenancy');
      await tester.tap(find.widgetWithText(MmButton, 'End tenancy').last);
      await tester.pumpAndSettle();
      expect(find.byType(EndLeaseSheet), findsOneWidget);
      expect(find.text('This tenancy is not active.'), findsOneWidget);
    });

    testWidgets('people living there are added, edited and removed', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      await _tap(tester, 'Add person');
      expect(find.byType(OccupantSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(MmButton, 'Save'));
      await tester.pumpAndSettle();
      expect(shown('Enter this to continue.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Zara Raza');
      await tester.tap(find.widgetWithText(MmButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Zara Raza saved.'), findsOneWidget);
      expect(find.text('Zara Raza'), findsOneWidget);
      await _tap(tester, 'Sana Raza');
      await tester.enterText(find.byType(TextField).first, 'Sana R.');
      await tester.tap(find.widgetWithText(MmButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Sana R.'), findsOneWidget);
      await _tap(tester, 'Sana R.');
      await tester.tap(find.widgetWithText(MmButton, 'Remove'));
      await tester.pumpAndSettle();
      await _confirm(tester, 'Remove');
      expect(find.text('Sana R.'), findsNothing);
      expect(app.leases.calls.last.$1, 'lease');
    });

    testWidgets('a mistaken tenancy is deleted unless it holds money', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 3600),
      );
      app.leases.gate.failure = const RejectedFailure('lease_has_records');
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(find.textContaining('it cannot be deleted'), findsWidgets);
      app.leases.gate.failure = null;
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(
        routeShown(Routes.unit(gulbergHouse.id, groundFloor.id)),
        findsOneWidget,
      );
      expect(find.text('Tenancy deleted.'), findsOneWidget);
    });

    testWidgets('an ended tenancy shows how it ended', (tester) async {
      await pumpScreen(
        tester,
        () => LeaseDetailScreen(leaseId: endedLease.id),
        size: const Size(360, 3000),
      );
      expect(find.text('31 Aug 2026'), findsOneWidget);
      expect(find.text('The tenant moved out'), findsOneWidget);
      expect(find.text('TRS-88231'), findsOneWidget);
      expect(find.text('Month to month'), findsOneWidget);
      expect(find.textContaining('deadline'), findsNothing);
    });

    testWidgets('viewers only look; failures say so', (tester) async {
      await pumpScreen(
        tester,
        _detail,
        app: _asViewer(),
        size: const Size(360, 3600),
      );
      expect(find.text('Change rent'), findsNothing);
      expect(find.text('End tenancy'), findsNothing);
      expect(find.text('Add person'), findsNothing);
    });

    testWidgets('a tenancy that cannot load says so', (tester) async {
      final app = TestApp()..leases.readFailure = const Forbidden();
      await pumpScreen(tester, _detail, app: app);
      expect(find.text('This tenancy could not be loaded'), findsOneWidget);
    });
  });

  group('tenancy lists', () {
    testWidgets('a vacant unit offers to start one', (tester) async {
      await pumpScreen(
        tester,
        () => TenancyList(unitId: annexe.id, canStart: true),
      );
      expect(find.text('No tenancies yet.'), findsOneWidget);
      await _tap(tester, 'Start tenancy');
      expect(
        find.textContaining('route:/leases/new?unit=${annexe.id}'),
        findsOneWidget,
      );
    });

    testWidgets("a tenant's tenancies lead to them", (tester) async {
      await pumpScreen(tester, () => TenancyList(tenantId: formerTenant.id));
      expect(find.text('First floor, Gulberg House'), findsOneWidget);
      expect(find.text('Start tenancy'), findsNothing);
      await _tap(tester, 'First floor, Gulberg House');
      expect(routeShown(Routes.lease(endedLease.id)), findsOneWidget);
    });

    testWidgets("a unit's tenancies name the tenant", (tester) async {
      await pumpScreen(tester, () => TenancyList(unitId: groundFloor.id));
      expect(find.text('Ali Raza'), findsOneWidget);
    });

    testWidgets('failures say so', (tester) async {
      final app = TestApp()..leases.readFailure = const Forbidden();
      await pumpScreen(
        tester,
        () => TenancyList(unitId: groundFloor.id),
        app: app,
      );
      expect(find.text('The tenancies could not be loaded'), findsOneWidget);
    });
  });

  testEveryVariant('tenancy screens fit at 320 dp', (tester, variant) async {
    for (final screen in <Widget Function()>[
      _detail,
      _newLease,
      () => LeaseFormScreen(leaseId: aliLease.id),
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
