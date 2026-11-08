import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/dashboard_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_card.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/reminders/presentation/reminder_sheet.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(360, 6000);

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Widget _dashboard() => const DashboardScreen();

/// Shows every insight card, past the first three.
Future<void> _showAll(WidgetTester tester) =>
    _tap(tester, find.textContaining('Show all'));

/// The [MmListTile] of the dated item titled [title].
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(MmListTile));

void main() {
  testWidgets('shows the month, what needs attention and who owes', (
    tester,
  ) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    expect(find.text('This month, November 2026'), findsOneWidget);
    // The amount keeps its currency word on its line.
    expect(find.text('of Rs\u00A0245,000 due, 65% collected'), findsOneWidget);
    expect(find.text('4 of 5'), findsOneWidget);
    expect(find.text('80% let, 1 vacant'), findsOneWidget);
    expect(shown('owed for over 90 days'), findsOneWidget);
    expect(
      find.text('1 tenancy is not registered with the police'),
      findsOneWidget,
    );
    expect(find.text('Rent increases to make'), findsOneWidget);
    // Three cards, the rest a tap away.
    expect(find.byType(InsightCard), findsNWidgets(3));
    expect(find.text('Deposits cover only 85% of overdue rent'), findsNothing);
    await _showAll(tester);
    expect(find.byType(InsightCard), findsNWidgets(10));
    expect(
      find.text('Deposits cover only 85% of overdue rent'),
      findsOneWidget,
    );
    expect(find.text('1 unit is let below its asking rent'), findsOneWidget);
    expect(shown('in cash with caretakers'), findsOneWidget);
    // 65% collected: the figures above say it, with no card.
    expect(shown("of this month's dues collected"), findsNothing);
    await _tap(tester, find.text('Show fewer'));
    expect(find.byType(InsightCard), findsNWidgets(3));
    expect(find.text('Owing most'), findsOneWidget);
    // Who owes what comes before what needs attention.
    expect(
      tester.getTopLeft(find.text('Owing most')).dy,
      lessThan(tester.getTopLeft(find.text('What needs attention')).dy),
    );
    // The bar holds the four overdue buckets INS-01 asks for, each in
    // its own tone, after what is not yet due.
    final bar = tester.widget<MmProportionBar>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MmProportionBar &&
            widget.segments.any(
              (segment) => segment.label == '61 to 90 days late',
            ),
      ),
    );
    expect(
      [for (final segment in bar.segments) segment.tone],
      [
        MmSegmentTone.neutral,
        MmSegmentTone.dueSoon,
        MmSegmentTone.overdue,
        MmSegmentTone.overdueOlder,
        MmSegmentTone.overdueSevere,
      ],
    );
    expect(find.text('61 to 90 days late'), findsOneWidget);
    expect(find.text('Over 90 days late'), findsOneWidget);
    expect(bar.semanticSummary, contains('61 to 90 days late'));
    expect(bar.semanticSummary, endsWith('over 90 days late.'));
    expect(find.textContaining('over 60 days late'), findsNothing);
    expect(find.text('Vacant units'), findsOneWidget);
    expect(find.text('Annexe room, Gulberg House'), findsOneWidget);
    // An amount in a sentence never parts from its currency word.
    expect(shown('Asking Rs\u00A040,000'), findsOneWidget);
    expect(find.text('Due and coming up'), findsOneWidget);
    // The dated items, earliest first.
    final titles = [
      'Rent increase not made for Ali Raza',
      'Register Indus Tech (Pvt) Ltd with the police',
      'Register Sana Iqbal with the police',
      'Rent increase for Indus Tech (Pvt) Ltd',
      "Ali Raza's CNIC expires",
      "Ali Raza's tenancy ends",
    ];
    final tops = [
      for (final title in titles) tester.getTopLeft(find.text(title)).dy,
    ];
    expect(tops, [...tops]..sort());
    // Past the law's deadline, in words as well as colour.
    expect(
      shown(
        '30\u00A0Oct 2026\u00A0· Shop 3: the deadline set by law has passed',
      ),
      findsOneWidget,
    );
    // Screen readers hear it too.
    expect(
      tester
          .getSemantics(_row('Register Indus Tech (Pvt) Ltd with the police'))
          .label,
      contains('the deadline set by law has passed'),
    );
    expect(shown('Flat 2B: submitted, not yet confirmed'), findsOneWidget);
  });

  testWidgets('a registration submitted after its date is no alarm', (
    tester,
  ) async {
    final json = dashboardJson();
    for (final row
        in (json['police_pending']! as List).cast<Map<String, Object?>>()) {
      row
        ..['status'] = 'submitted'
        ..['overdue'] = true
        ..['statutory'] = true;
    }
    final app = TestApp()..insights.dashboardAnswer = json;
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    await _showAll(tester);
    expect(shown('not registered with the police'), findsNothing);
    expect(shown("past the law's deadline"), findsNothing);
    expect(
      find.text('2 police registrations are waiting for confirmation'),
      findsOneWidget,
    );
    final card = find.ancestor(
      of: find.text('2 police registrations are waiting for confirmation'),
      matching: find.byType(InsightCard),
    );
    expect(
      find.descendant(of: card, matching: shown('Good to know')),
      findsOneWidget,
    );
    expect(shown('has passed'), findsNothing);
    expect(shown('Shop 3: submitted, not yet confirmed'), findsOneWidget);
    // Its icon is not coloured as late.
    final icon = tester.widget<Icon>(
      find.descendant(
        of: _row('Register Indus Tech (Pvt) Ltd with the police'),
        matching: find.byIcon(MmIcons.police),
      ),
    );
    expect(icon.color, isNull);
  });

  for (final (title, route) in [
    ('Rent increase not made for Ali Raza', Routes.lease(aliLease.id)),
    (
      'Register Indus Tech (Pvt) Ltd with the police',
      Routes.lease(techLeaseId),
    ),
    ("Ali Raza's CNIC expires", Routes.tenant(aliRaza.id)),
    ("Ali Raza's tenancy ends", Routes.lease(aliLease.id)),
  ]) {
    testWidgets('"$title" opens what it is about', (tester) async {
      await pumpScreen(tester, _dashboard, size: _tall);
      await _tap(tester, find.text(title));
      expect(routeShown(route), findsOneWidget);
    });
  }

  testWidgets('a warning is worth a look, not always about time', (
    tester,
  ) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _showAll(tester);
    final vacancy = find.ancestor(
      of: find.text('1 unit is vacant'),
      matching: find.byType(InsightCard),
    );
    final badge = find.descendant(
      of: vacancy,
      matching: find.byType(MmStatusBadge),
    );
    expect(tester.widget<MmStatusBadge>(badge).label, 'Worth a look');
    expect(tester.widget<MmStatusBadge>(badge).icon, MmIcons.warning);
    expect(
      find.text(
        'Empty, it costs you Rs\u00A040,000 a month at the asking rent. '
        'It has been empty for 45 days.',
      ),
      findsOneWidget,
    );
  });

  testWidgets("an insight's action lines up with its words", (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    final card = find.byType(InsightCard).first;
    final words = tester.getTopLeft(
      find.descendant(of: card, matching: find.text('See who owes')),
    );
    final title = tester.getTopLeft(
      find.descendant(of: card, matching: find.textContaining('owed for over')),
    );
    expect(words.dx, title.dx);
  });

  testWidgets('the app bar leads to search and the reports', (tester) async {
    await pumpScreen(tester, _dashboard);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(routeShown(Routes.search), findsOneWidget);
  });

  testWidgets('and to the reports', (tester) async {
    await pumpScreen(tester, _dashboard);
    await tester.tap(find.byTooltip('Reports'));
    await tester.pumpAndSettle();
    expect(routeShown(Routes.reports), findsOneWidget);
  });

  testWidgets('a tenancy owing rent is one tap from paying', (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _tap(tester, find.text('Record payment').first);
    expect(routeShown(Routes.recordPayment(aliLease.id)), findsOneWidget);
  });

  testWidgets('or from a reminder', (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _tap(tester, find.text('Remind').first);
    expect(find.byType(ReminderComposer), findsOneWidget);
  });

  testWidgets('its row opens the ledger', (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _tap(tester, find.text('Indus Tech (Pvt) Ltd').first);
    expect(routeShown(Routes.ledger(techLeaseId)), findsOneWidget);
  });

  testWidgets('a viewer sees who owes, without the money actions', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _dashboard,
      app: TestApp(portfolios: const [gulbergAsViewer]),
      size: _tall,
    );
    expect(find.text('Owing most'), findsOneWidget);
    expect(find.text('Record payment'), findsNothing);
    expect(find.text('Remind'), findsNothing);
  });

  for (final (action, route) in [
    ('See who owes', Routes.money),
    ('See utilities', Routes.utilities),
    ('See expenses', Routes.expenses),
    ('See cash in hand', Routes.cash),
    ('See all', Routes.money),
  ]) {
    testWidgets('"$action" leads on', (tester) async {
      await pumpScreen(tester, _dashboard, size: _tall);
      await _showAll(tester);
      await _tap(tester, find.text(action).first);
      expect(routeShown(route), findsOneWidget);
    });
  }

  testWidgets('an insight about several tenancies leads to them all', (
    tester,
  ) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _showAll(tester);
    // Police (one to register, one submitted) and increases (missed and
    // due) are each about two tenancies.
    final all = find.text('See tenants');
    expect(all, findsNWidgets(2));
    await _tap(tester, all.first);
    expect(routeShown(Routes.tenants), findsOneWidget);
  });

  testWidgets('an insight about one tenancy opens it, by name', (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _showAll(tester);
    // Tenancies ending and underpriced units: both Ali Raza's.
    final open = find.text("Open Ali Raza's tenancy");
    expect(open, findsNWidgets(2));
    await _tap(tester, open.first);
    expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
  });

  testWidgets('a vacant unit opens its screen', (tester) async {
    await pumpScreen(tester, _dashboard, size: _tall);
    await _tap(tester, find.text('Annexe room, Gulberg House'));
    expect(routeShown(Routes.unit(gulbergHouse.id, annexe.id)), findsOneWidget);
  });

  testWidgets('a quiet portfolio says nothing needs attention', (tester) async {
    final quiet = quietDashboardJson();
    final json = dashboardJson()
      ..['month'] = quiet['month']
      ..['outstanding'] = quiet['outstanding']
      ..['top_arrears'] = <Object?>[]
      ..['leases_expiring'] = <Object?>[]
      ..['increments_upcoming'] = <Object?>[]
      ..['increments_missed'] = <Object?>[]
      ..['police_pending'] = <Object?>[]
      ..['cnic_expiring'] = <Object?>[]
      ..['utilities'] = quiet['utilities']
      ..['expenses'] = quiet['expenses']
      ..['deposits'] = quiet['deposits']
      ..['occupancy'] = {
        'units': 5,
        'occupied': 5,
        'vacant': 0,
        'unavailable': 0,
        'rate': 1,
        'vacant_asking_rent': 0,
      }
      ..['vacant_units'] = <Object?>[];
    final app = TestApp()
      ..insights.dashboardAnswer = json
      // No caretaker holds cash in this portfolio.
      ..insights.positions = const []
      ..insights.rentRollAnswer = [];
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    expect(find.text('Nothing has fallen due this month yet.'), findsOneWidget);
    expect(find.text('Nobody owes anything now.'), findsOneWidget);
    expect(find.text('Nothing falls due in the coming weeks.'), findsOneWidget);
    expect(find.text('Vacant units'), findsNothing);
    expect(find.text('Nothing needs your attention today.'), findsOneWidget);
    expect(find.byType(MmProportionBar), findsNothing);
  });

  group('a portfolio with nothing to let', () {
    TestApp appWith({
      required int properties,
      List<PortfolioMembership> portfolios = const [gulberg],
    }) => TestApp(portfolios: portfolios)
      ..insights.dashboardAnswer = {
        ...quietDashboardJson(),
        'counts': {
          'properties': properties,
          'tenants': 0,
          'active_leases': 0,
          'open_maintenance': 0,
          'urgent_maintenance': 0,
        },
      }
      ..insights.positions = const []
      ..insights.rentRollAnswer = [];

    testWidgets('leads an owner to add the first property', (tester) async {
      await pumpScreen(
        tester,
        _dashboard,
        app: appWith(properties: 0),
        size: _tall,
      );
      expect(find.text('No properties yet'), findsOneWidget);
      expect(
        find.text('Add your first property to start collecting rent.'),
        findsOneWidget,
      );
      // No page of zeros.
      expect(find.text('Nobody owes anything now.'), findsNothing);
      expect(find.byType(MmStatTile), findsNothing);
      expect(find.text('What needs attention'), findsNothing);
      await _tap(tester, find.text('Add property'));
      expect(routeShown(Routes.newProperty), findsOneWidget);
    });

    testWidgets('leads to the properties when they have no unit', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _dashboard,
        app: appWith(properties: 2),
        size: _tall,
      );
      expect(find.text('No units yet'), findsOneWidget);
      await _tap(tester, find.text('See properties'));
      expect(routeShown(Routes.properties), findsOneWidget);
    });

    for (final properties in [0, 2]) {
      testWidgets('tells a viewer what will come ($properties)', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          _dashboard,
          app: appWith(
            properties: properties,
            portfolios: const [gulbergAsViewer],
          ),
          size: _tall,
        );
        expect(shown('rent shows here'), findsOneWidget);
        expect(find.byType(MmButton), findsNothing);
      });
    }

    testWidgets('still says what needs attention', (tester) async {
      final app = appWith(properties: 1);
      app.insights.dashboardAnswer = {
        ...app.insights.dashboardAnswer,
        'expenses': {'this_month': 64000, 'trailing_3m_avg': 30000},
      };
      await pumpScreen(tester, _dashboard, app: app, size: _tall);
      expect(find.text('No units yet'), findsOneWidget);
      expect(find.text('What needs attention'), findsOneWidget);
      expect(find.text('Expenses are up this month'), findsOneWidget);
    });
  });

  testWidgets('good news, reminders and expired cards are said too', (
    tester,
  ) async {
    final json = dashboardJson();
    (json['month']! as Map<String, Object?>)
      ..['paid'] = 245000
      ..['collection_rate'] = 1;
    json['increments_missed'] = <Object?>[];
    final utilities = json['utilities']! as Map<String, Object?>;
    ((utilities['high_usage']! as List).single as Map<String, Object?>)
      ..['units_consumed'] = 185
      ..['crossed'] = false;
    ((json['police_pending']! as List).last as Map<String, Object?>)['status'] =
        'pending';
    ((json['cnic_expiring']! as List).single
            as Map<String, Object?>)['expired'] =
        true;
    final app = TestApp()..insights.dashboardAnswer = json;
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    await _showAll(tester);
    expect(shown('Good news'), findsOneWidget);
    expect(find.text('Every due of this month is paid.'), findsOneWidget);
    expect(
      find.text('1 protected-tariff meter is near 200 units.'),
      findsOneWidget,
    );
    expect(
      shown("Flat 2B: the app's reminder, no law sets a deadline"),
      findsOneWidget,
    );
    expect(find.text("Ali Raza's CNIC has expired"), findsOneWidget);
    // The increases card leads to the next one due, by name.
    final increases = find.ancestor(
      of: find.text('Rent increases to make'),
      matching: find.byType(InsightCard),
    );
    await _tap(
      tester,
      find.descendant(
        of: increases,
        matching: find.text("Open Indus Tech (Pvt) Ltd's tenancy"),
      ),
    );
    expect(routeShown(Routes.lease(techLeaseId)), findsOneWidget);
  });

  testWidgets('the cards wait for the cash and rent roll, read once', (
    tester,
  ) async {
    final app = await pumpScreen(tester, _dashboard, size: _tall);
    await _showAll(tester);
    expect(shown('in cash with caretakers'), findsOneWidget);
    // Read again from the device while the server is away.
    app.insights.failure = const NetworkFailure();
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    await _showAll(tester);
    expect(shown('in cash with caretakers'), findsOneWidget);
    expect(find.text('1 unit is let below its asking rent'), findsOneWidget);
  });

  testWidgets('a poor month, a deadline still to come, units all off', (
    tester,
  ) async {
    final json = dashboardJson();
    json['month'] = {
      ...(json['month']! as Map<String, Object?>),
      'collection_rate': 0.3,
      'paid': 73500,
    };
    json['occupancy'] = {
      'units': 2,
      'occupied': 0,
      'vacant': 0,
      'unavailable': 2,
      'rate': null,
      'vacant_asking_rent': 0,
    };
    json['vacant_units'] = <Object?>[];
    final [indus, _] = (json['police_pending']! as List)
        .cast<Map<String, Object?>>();
    indus['overdue'] = false;
    final [ali, tech] = rentRollJson();
    final app = TestApp()
      ..insights.dashboardAnswer = json
      ..insights.rentRollAnswer = [
        ali,
        {
          ...tech,
          'unit': const {
            'label': 'Shop 3',
            'asking_rent': 160000,
            'property': {'name': 'Saddar Plaza'},
          },
        },
      ];
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    await _showAll(tester);
    expect(find.text('No units to let yet'), findsOneWidget);
    expect(shown("of this month's dues collected"), findsOneWidget);
    expect(shown('Shop 3: deadline set by law'), findsOneWidget);
    expect(shown('has passed'), findsNothing);
    // Two units let below their asking rent: their tenants.
    final underpriced = find.ancestor(
      of: find.text('2 units are let below their asking rent'),
      matching: find.byType(InsightCard),
    );
    expect(
      find.descendant(of: underpriced, matching: find.text('See tenants')),
      findsOneWidget,
    );
  });

  testWidgets('a member without a name is named by their role', (tester) async {
    final app = TestApp()
      ..insights.positions = const [
        CashPosition(
          userId: caretakerId,
          fullName: '',
          role: MemberRole.accountant,
          collected: Money.fromRupees(9000),
          handedOver: Money.zero,
          spent: Money.zero,
          inHand: Money.fromRupees(9000),
        ),
      ];
    await pumpScreen(tester, _dashboard, app: app, size: _tall);
    await _showAll(tester);
    expect(find.text('Accountant holds Rs\u00A09,000.'), findsOneWidget);
  });

  testWidgets('says when it cannot be read, and tries again', (tester) async {
    final app = TestApp()..insights.failure = const ServerFailure('x');
    await pumpScreen(tester, _dashboard, app: app);
    expect(find.text('The dashboard could not be loaded'), findsOneWidget);
    app.insights.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('shows nothing until a portfolio is chosen', (tester) async {
    await pumpScreen(tester, _dashboard, app: TestApp(portfolios: const []));
    expect(find.text('What needs attention'), findsNothing);
  });

  testEveryVariant('fits a narrow phone at every size', (
    tester,
    variant,
  ) async {
    await pumpScreen(
      tester,
      _dashboard,
      variant: variant,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
