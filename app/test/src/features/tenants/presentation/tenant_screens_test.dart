import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_form_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenants_screen.dart';
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

Finder _input(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        (widget is MmTextField && widget.label == label) ||
        (widget is MmPhoneField && widget.label == label) ||
        (widget is MmCnicField && widget.label == label),
  ),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  // The first field so labelled (the tenant's own phone before the
  // emergency contact's).
  await tester.ensureVisible(_input(label).first);
  await tester.enterText(_input(label).first, text);
  await tester.pump();
}

Widget _detail() => TenantDetailScreen(tenantId: aliRaza.id);

Tenant _call(TestApp app, String name) =>
    app.tenants.calls.lastWhere((c) => c.$1 == name).$2.last! as Tenant;

void main() {
  group('the tenant list', () {
    testWidgets('shows tenants, searches, filters and leads on', (
      tester,
    ) async {
      final app = await pumpScreen(tester, TenantsScreen.new);
      expect(find.text('Ali Raza'), findsOneWidget);
      expect(
        find.text('0300 1112233\u00a0· Son of Ahmed Raza'),
        findsOneWidget,
      );
      expect(find.text('Hamid Ali'), findsNothing);
      await tester.enterText(find.byType(TextField), 'indus');
      await tester.pump(TenantsScreen.searchDelay);
      await tester.pumpAndSettle();
      expect(find.text('Ali Raza'), findsNothing);
      expect(find.text('Indus Tech (Pvt) Ltd'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump(TenantsScreen.searchDelay);
      await tester.pumpAndSettle();
      expect(find.text('No tenant matches nobody.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(TenantsScreen.searchDelay);
      await tester.pumpAndSettle();
      await _tap(tester, 'Archived');
      expect(find.text('Hamid Ali'), findsOneWidget);
      await _tap(tester, 'Hamid Ali');
      expect(routeShown(Routes.tenant(formerTenant.id)), findsOneWidget);
      expect(app.tenants.calls.first.$2, [gulberg.id, false, '', null]);
    });

    testWidgets('a company shows what it is; pages read more', (tester) async {
      final app = TestApp()..tenants.pageLimit = 1;
      await pumpScreen(tester, TenantsScreen.new, app: app);
      expect(find.text('Indus Tech (Pvt) Ltd'), findsNothing);
      await _tap(tester, 'Show more');
      expect(find.text('0423 5000000'), findsNothing);
      expect(find.text('04235000000'), findsOneWidget);
    });

    testWidgets('empty lists say what to do; viewers cannot add', (
      tester,
    ) async {
      final app = TestApp()..tenants.byPortfolio[gulberg.id]!.clear();
      await pumpScreen(tester, TenantsScreen.new, app: app);
      expect(find.text('No tenants yet'), findsOneWidget);
      await _tap(tester, 'Add tenant');
      expect(routeShown(Routes.newTenant), findsOneWidget);
    });

    testWidgets('archived empty, and a viewer', (tester) async {
      final app = TestApp()..tenants.byPortfolio[gulberg.id]!.clear();
      await pumpScreen(tester, TenantsScreen.new, app: app);
      await _tap(tester, 'Archived');
      expect(find.text('No archived tenants.'), findsOneWidget);
    });

    testWidgets('viewers do not add', (tester) async {
      await pumpScreen(tester, TenantsScreen.new, app: _asViewer());
      expect(find.text('Add tenant'), findsNothing);
    });

    testWidgets('a list that cannot load says so', (tester) async {
      final app = TestApp()..tenants.readFailure = const Forbidden();
      await pumpScreen(tester, TenantsScreen.new, app: app);
      expect(find.text('The tenants could not be loaded'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton', (tester) async {
      final app = TestApp()..portfolios.gate.close();
      await pumpScreen(tester, TenantsScreen.new, app: app, settle: false);
      expect(find.bySemanticsLabel('Loading the tenants'), findsOneWidget);
      app.portfolios.gate.open();
      await tester.pumpAndSettle();
    });
  });

  group('a tenant', () {
    testWidgets('shows their details with the CNIC masked', (tester) async {
      await pumpScreen(tester, _detail, size: const Size(360, 2400));
      expect(find.text('Son of Ahmed Raza'), findsOneWidget);
      expect(find.textContaining('1234567'), findsNothing);
      expect(find.text('0300 1112233'), findsOneWidget);
      expect(find.text('Sana Raza'), findsOneWidget);
      expect(find.text('Reference 1'), findsOneWidget);
      expect(find.text('Reference 2'), findsNothing);
      expect(find.text('Consent recorded on 10 Jan 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.editTenant(aliRaza.id)), findsOneWidget);
    });

    testWidgets('an expired CNIC and missing consent are pointed out', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => TenantDetailScreen(
          tenantId: formerTenant.id,
          extras: (tenant) => Text('extra ${tenant.fullName}'),
        ),
        size: const Size(360, 1600),
      );
      expect(shown('CNIC expired'), findsOneWidget);
      expect(find.text('Consent not recorded'), findsOneWidget);
      expect(find.text('extra Hamid Ali'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNothing);
      await _tap(tester, 'Put back in use');
      expect(find.text('Hamid Ali is back in use.'), findsOneWidget);
    });

    testWidgets('a company says it deducts tax', (tester) async {
      await pumpScreen(
        tester,
        () => TenantDetailScreen(tenantId: techCorp.id),
        size: const Size(360, 1600),
      );
      expect(find.text('Company'), findsOneWidget);
      expect(find.text('1234567-8'), findsOneWidget);
      expect(find.textContaining('section 155'), findsOneWidget);
    });

    testWidgets('is archived and deleted', (tester) async {
      final app = await pumpScreen(
        tester,
        _detail,
        size: const Size(360, 2400),
      );
      await _tap(tester, 'Archive');
      await _confirm(tester, 'Archive');
      expect(find.text('Ali Raza archived.'), findsOneWidget);
      app.tenants.gate.failure = const RejectedFailure('still_in_use');
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(find.textContaining('Archive it instead.'), findsOneWidget);
      app.tenants.gate.failure = null;
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(routeShown(Routes.tenants), findsOneWidget);
      expect(find.text('Ali Raza deleted.'), findsOneWidget);
    });

    testWidgets('viewers only look; failures say so', (tester) async {
      await pumpScreen(tester, _detail, app: _asViewer());
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('a tenant that cannot load says so', (tester) async {
      final app = TestApp()..tenants.readFailure = const NotFoundFailure();
      await pumpScreen(tester, _detail, app: app);
      expect(find.text('This tenant could not be loaded'), findsOneWidget);
    });
  });

  group('the tenant form', () {
    testWidgets('checks the details and adds a tenant', (tester) async {
      final app = await pumpScreen(
        tester,
        TenantFormScreen.new,
        size: const Size(360, 5000),
      );
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _type(tester, 'Full name', 'Nadia Khan');
      await _type(tester, 'CNIC', '12345');
      await _type(tester, 'Phone', '123');
      await _type(tester, 'NTN', 'x');
      await _type(tester, 'E-mail', 'nadia@');
      await _type(tester, 'People living there', '0');
      await _tap(tester, 'Save');
      expect(shown('Enter the 13 digits of a CNIC'), findsOneWidget);
      expect(shown('Enter a phone number like 03001234567.'), findsOneWidget);
      expect(shown('Enter the NTN as issued'), findsOneWidget);
      expect(
        shown('Enter an e-mail address like name@example.com.'),
        findsOneWidget,
      );
      expect(shown('Enter a number from 1 to 50.'), findsOneWidget);
      await _type(tester, 'CNIC', '3520298765431');
      await _type(tester, 'Phone', '03219876543');
      await _type(tester, 'NTN', '');
      await _type(tester, 'E-mail', 'Nadia@Example.com');
      await _type(tester, 'People living there', '3');
      await _type(tester, "Father's or husband's name", 'Imran Khan');
      final relation = find.byWidgetPredicate((w) => w is MmSelectField);
      await tester.ensureVisible(relation);
      await tester.tap(relation);
      await tester.pumpAndSettle();
      await _tap(tester, 'Wife of');
      await _type(tester, 'Reference 1: name', 'Bilal');
      await _type(tester, 'Reference 1: phone', '03001234567');
      await _tap(tester, 'I told the tenant what details are kept and why');
      await _type(tester, 'What they agreed to', 'CNIC copy for police');
      await _tap(tester, 'Save');
      final created = _call(app, 'createTenant');
      expect(created.fullName, 'Nadia Khan');
      expect(created.cnic, Cnic.parse('35202-9876543-1'));
      expect(created.phone, PhoneNumber.fromE164('+923219876543'));
      expect(created.guardianRelation, GuardianRelation.wifeOf);
      expect(created.householdSize, 3);
      expect(created.reference1.name, 'Bilal');
      expect(created.consentRecordedAt, isNotNull);
      expect(find.text('Nadia Khan added.'), findsOneWidget);
    });

    testWidgets('a company has no guardian; tax can be set', (tester) async {
      final app = await pumpScreen(
        tester,
        TenantFormScreen.new,
        size: const Size(360, 4000),
      );
      await _tap(tester, 'Company');
      expect(find.text('S/O, D/O or W/O', findRichText: true), findsNothing);
      await _type(tester, 'Full name', 'Shan Foods');
      await _tap(tester, 'Deducts withholding tax');
      await _tap(tester, 'Save');
      final created = _call(app, 'createTenant');
      expect(created.kind, TenantKind.company);
      expect(created.deductsWithholdingTax, isTrue);
      expect(created.consentRecordedAt, isNull);
    });

    testWidgets('warns about another tenant with the same phone', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        TenantFormScreen.new,
        size: const Size(360, 4000),
      );
      await _type(tester, 'Full name', 'Ali R.');
      await _type(tester, 'Phone', '03001112233');
      await _tap(tester, 'Save');
      expect(find.text('Is this the same tenant?'), findsOneWidget);
      expect(find.textContaining('Ali Raza already has'), findsOneWidget);
      await _tap(tester, 'Cancel');
      expect(app.tenants.calls.where((c) => c.$1 == 'createTenant'), isEmpty);
      await _tap(tester, 'Save');
      await _confirm(tester, 'Save anyway');
      expect(_call(app, 'createTenant').fullName, 'Ali R.');
    });

    testWidgets('a CNIC in use is shown on its field', (tester) async {
      final app = await pumpScreen(
        tester,
        TenantFormScreen.new,
        size: const Size(360, 4000),
      );
      await _type(tester, 'Full name', 'Someone');
      app.tenants.gate.failure = const RejectedFailure('duplicate_cnic');
      await _tap(tester, 'Save');
      expect(
        tester.widget<MmCnicField>(find.byType(MmCnicField)).errorText,
        'Another tenant in use has this CNIC.',
      );
      app.tenants.gate.failure = const NetworkFailure();
      await _type(tester, 'CNIC', '3520298765431');
      await _tap(tester, 'Save');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.tenants), findsOneWidget);
    });

    testWidgets('editing keeps the consent date and saves', (tester) async {
      final app = await pumpScreen(
        tester,
        () => TenantFormScreen(tenantId: aliRaza.id),
        size: const Size(360, 5000),
      );
      expect(find.text('Edit tenant'), findsOneWidget);
      await _type(tester, 'Occupation', 'Branch manager');
      await _tap(tester, 'Save');
      final saved = _call(app, 'updateTenant');
      expect(saved.occupation, 'Branch manager');
      expect(saved.consentRecordedAt, aliRaza.consentRecordedAt);
      // Nothing to compare when the CNIC and phone did not change.
      expect(app.tenants.calls.where((c) => c.$1 == 'matches'), isEmpty);
      expect(find.text('Ali Raza saved.'), findsOneWidget);
    });

    testWidgets('editing can be cancelled; a failed read says so', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => TenantFormScreen(tenantId: aliRaza.id),
        size: const Size(360, 5000),
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.tenant(aliRaza.id)), findsOneWidget);
    });

    testWidgets('a tenant to edit that cannot load says so', (tester) async {
      final app = TestApp()..tenants.readFailure = const Forbidden();
      await pumpScreen(
        tester,
        () => TenantFormScreen(tenantId: aliRaza.id),
        app: app,
      );
      expect(find.text('This tenant could not be loaded'), findsOneWidget);
    });
  });

  testEveryVariant('tenant screens fit at 320 dp', (tester, variant) async {
    for (final screen in <Widget Function()>[
      TenantsScreen.new,
      _detail,
      TenantFormScreen.new,
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
