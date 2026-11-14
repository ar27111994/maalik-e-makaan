import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/residence_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _inPakistan = 'Yes, in Pakistan';
const _abroad = 'No, in another country';
const _notSaying = 'I prefer not to say';
const _tall = Size(390, 1400);

final _gb = CountryCode.parse('GB');
final _us = CountryCode.parse('US');
final _london = TimeZoneId.parse('Europe/London');
final _newYork = TimeZoneId.parse('America/New_York');

/// A test app whose user has never answered.
TestApp _unanswered({FakeDeviceTimeZone device = const FakeDeviceTimeZone()}) =>
    TestApp(residence: AccountResidence.notStated, device: device);

/// Opens the residence screen above another, as the shell and Settings do,
/// and keeps what it closed with.
class _Opener extends StatelessWidget {
  const new({required this.results});

  final List<bool?> results;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () async => results.add(
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ResidenceScreen()),
        ),
      ),
      child: const Text('open'),
    ),
  );
}

Future<List<bool?>> _open(
  WidgetTester tester,
  TestApp app, {
  MmVariant variant = MmVariant.light,
}) async {
  final results = <bool?>[];
  await pumpScreen(
    tester,
    () => _Opener(results: results),
    app: app,
    variant: variant,
    size: _tall,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(MmButton, 'Save'));

Finder _select(String label) => find.byWidgetPredicate(
  (widget) => widget is MmSelectField && widget.label == label,
);

/// Chooses [option] in the select field [label], typing [search] first.
Future<void> _choose(
  WidgetTester tester,
  String label,
  String option, {
  String? search,
}) async {
  await _tap(tester, _select(label));
  if (search != null) {
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      search,
    );
    await tester.pumpAndSettle();
  }
  await _tap(
    tester,
    find.descendant(of: find.byType(BottomSheet), matching: find.text(option)),
  );
}

List<Object?> _updates(TestApp app) => [
  for (final call in app.residences.calls)
    if (call.$1 == 'update') call.$2,
];

/// Checks that no answer is chosen: the group's value, and what screen
/// readers hear for each option (a radio, not checked).
void _expectNothingChosen(WidgetTester tester, List<String> labels) {
  final group = tester.widget<MmRadioGroup<ResidenceAnswer>>(
    find.byType(MmRadioGroup<ResidenceAnswer>),
  );
  expect(group.value, isNull);
  for (final label in labels) {
    expect(
      tester.getSemantics(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(RadioListTile<ResidenceAnswer>),
        ),
      ),
      isSemantics(hasCheckedState: true, isChecked: false),
      reason: label,
    );
  }
}

void main() {
  group('the question', () {
    testWidgets('starts with no answer chosen', (tester) async {
      await _open(tester, _unanswered());
      expect(shown('Do you live in Pakistan?'), findsOneWidget);
      _expectNothingChosen(tester, const [_inPakistan, _abroad, _notSaying]);
      expect(_select('Country'), findsNothing);
      expect(_select('Time zone'), findsNothing);
      expect(find.text('Not now'), findsOneWidget);
      expect(
        find.text(
          'Only you see your answer. Your team and your tenants never do.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('infers nothing from the phone, the language or the device', (
      tester,
    ) async {
      // A +92 number (the fixture's), the Urdu UI, a device on Pakistan
      // time with its zone's name, then one on London's.
      for (final device in const [
        FakeDeviceTimeZone(ianaName: 'Asia/Karachi'),
        FakeDeviceTimeZone(ianaName: 'Europe/London', offset: Duration.zero),
      ]) {
        await _open(
          tester,
          _unanswered(device: device),
          variant: MmVariant.urdu,
        );
        expect(
          tester
              .widget<MmRadioGroup<ResidenceAnswer>>(
                find.byType(MmRadioGroup<ResidenceAnswer>),
              )
              .value,
          isNull,
        );
        expect(find.byType(MmSelectField<CountryCode>), findsNothing);
        expect(find.text('لندن'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('saving with nothing chosen asks for an answer', (
      tester,
    ) async {
      final app = _unanswered();
      await _open(tester, app);
      await _save(tester);
      expect(shown('Choose an answer.'), findsOneWidget);
      expect(_updates(app), isEmpty);
    });

    testWidgets('in Pakistan saves Pakistan without a zone, and closes', (
      tester,
    ) async {
      final app = _unanswered();
      final results = await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      expect(
        find.text('The app will show times in Pakistan time only.'),
        findsOneWidget,
      );
      await _save(tester);
      expect(_updates(app), [
        [testUserId, CountryCode.pakistan, null],
      ]);
      expect(find.text('Saved. Only you can see where you live.'), findsOne);
      expect(results, [true]);
    });

    testWidgets('prefer not to say saves nothing stated', (tester) async {
      final app = _unanswered();
      final results = await _open(tester, app);
      await _tap(tester, find.text(_notSaying));
      expect(
        find.text('The app will show times in Pakistan time only.'),
        findsOneWidget,
      );
      await _save(tester);
      expect(_updates(app), [
        [testUserId, null, null],
      ]);
      expect(app.residences.residence.stated, isTrue);
      expect(results, [true]);
    });

    testWidgets('abroad asks for the country and the zone', (tester) async {
      final app = _unanswered();
      await _open(tester, app);
      await _tap(tester, find.text(_abroad));
      await _save(tester);
      expect(shown('Choose the country you live in.'), findsOneWidget);
      expect(shown('Choose your time zone.'), findsOneWidget);
      expect(_updates(app), isEmpty);
      // The errors go as the fields are answered.
      await _choose(tester, 'Country', 'United Kingdom', search: 'UK');
      expect(shown('Choose the country you live in.'), findsNothing);
      await _choose(tester, 'Time zone', 'London');
      expect(shown('Choose your time zone.'), findsNothing);
    });

    testWidgets('finds the country by a short form, and offers the device '
        'zone only once it is confirmed', (tester) async {
      final app = _unanswered(
        device: const FakeDeviceTimeZone(
          ianaName: 'Europe/London',
          offset: Duration.zero,
        ),
      );
      final results = await _open(tester, app);
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United Kingdom', search: 'UK');
      expect(
        find.text('Your phone or computer is set to London time.'),
        findsOneWidget,
      );
      // A suggestion only: the zone stays empty until it is taken.
      expect(
        tester
            .widget<MmSelectField<TimeZoneId>>(
              find.byType(MmSelectField<TimeZoneId>),
            )
            .value,
        isNull,
      );
      await _tap(tester, find.text('Use London time'));
      expect(find.text('Use London time'), findsNothing);
      await _save(tester);
      expect(_updates(app), [
        [testUserId, _gb, _london],
      ]);
      expect(results, [true]);
    });

    testWidgets('the Urdu search finds a country by its English short form', (
      tester,
    ) async {
      await _open(tester, _unanswered(), variant: MmVariant.urdu);
      await _tap(tester, find.text('نہیں، کسی اور ملک میں'));
      await _choose(tester, 'ملک', 'برطانیہ', search: 'UK');
      expect(
        tester
            .widget<MmSelectField<CountryCode>>(
              find.byType(MmSelectField<CountryCode>),
            )
            .value,
        _gb,
      );
    });

    testWidgets('suggests a zone only within the chosen country', (
      tester,
    ) async {
      await _open(
        tester,
        _unanswered(
          device: const FakeDeviceTimeZone(
            ianaName: 'America/New_York',
            offset: Duration(hours: -5),
          ),
        ),
      );
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United Kingdom', search: 'kingdom');
      expect(find.textContaining('Your phone or computer'), findsNothing);
    });

    testWidgets('a phone without a zone name is matched by its offset', (
      tester,
    ) async {
      // A phone gives only its clock's offsets: London's.
      await _open(
        tester,
        _unanswered(device: FakeDeviceTimeZone(clock: _london)),
      );
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United Kingdom', search: 'UK');
      expect(find.text('Use London time'), findsOneWidget);
    });

    testWidgets('Pakistan time while abroad saves the country alone', (
      tester,
    ) async {
      final app = _unanswered();
      await _open(tester, app);
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United States', search: 'USA');
      await _choose(tester, 'Time zone', 'Pakistan time', search: 'pakistan');
      await _save(tester);
      expect(_updates(app), [
        [testUserId, _us, null],
      ]);
    });

    testWidgets('another country clears a zone outside it, not Pakistan time', (
      tester,
    ) async {
      await _open(tester, _unanswered());
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United States', search: 'USA');
      await _choose(tester, 'Time zone', 'New York', search: 'york');
      SelectZone zone() => tester.widget<MmSelectField<TimeZoneId>>(
        find.byType(MmSelectField<TimeZoneId>),
      );
      expect(zone().value, _newYork);
      await _choose(tester, 'Country', 'United Kingdom', search: 'UK');
      expect(zone().value, isNull);
      await _choose(tester, 'Time zone', 'Pakistan time');
      await _choose(tester, 'Country', 'United States', search: 'USA');
      expect(zone().value, TimeZoneId.pakistan);
    });

    testWidgets('switching answers keeps the country for when it comes back', (
      tester,
    ) async {
      final app = _unanswered();
      await _open(tester, app);
      await _tap(tester, find.text(_abroad));
      await _choose(tester, 'Country', 'United Kingdom', search: 'UK');
      await _tap(tester, find.text(_inPakistan));
      expect(_select('Country'), findsNothing);
      await _tap(tester, find.text(_abroad));
      expect(
        tester
            .widget<MmSelectField<CountryCode>>(
              find.byType(MmSelectField<CountryCode>),
            )
            .value,
        _gb,
      );
    });

    testWidgets('a lost connection keeps the answers and saves on retry', (
      tester,
    ) async {
      final app = _unanswered();
      app.residences.updateFailure = const NetworkFailure();
      final results = await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      await _save(tester);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(results, isEmpty);
      // Another answer clears the message.
      await _tap(tester, find.text(_notSaying));
      expect(find.textContaining('No connection'), findsNothing);
      await _tap(tester, find.text(_inPakistan));
      app.residences.updateFailure = null;
      await _save(tester);
      expect(_updates(app), hasLength(2));
      expect(results, [true]);
    });

    testWidgets('refusals are explained above the form', (tester) async {
      final app = _unanswered();
      await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      app.residences.updateFailure = const RejectedFailure('account_deleted');
      await _save(tester);
      expect(shown('This account is being deleted'), findsOneWidget);
      app.residences.updateFailure = const RejectedFailure(
        'constraint_violation',
      );
      await _save(tester);
      expect(
        find.text(
          'The server does not know this country or time zone yet. Choose '
          'another, or try again later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('saving shows progress and blocks a second tap', (
      tester,
    ) async {
      final app = _unanswered();
      await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      app.residences.gate.close();
      await tester.tap(find.widgetWithText(MmButton, 'Save'));
      await tester.pump();
      final notNow = tester.widget<MmButton>(
        find.widgetWithText(MmButton, 'Not now'),
      );
      expect(notNow.onPressed, isNull);
      expect(
        tester
            .widget<MmRadioGroup<ResidenceAnswer>>(
              find.byType(MmRadioGroup<ResidenceAnswer>),
            )
            .onChanged,
        isNull,
      );
      app.residences.gate.open();
      await tester.pumpAndSettle();
      expect(_updates(app), hasLength(1));
    });

    testWidgets('not now closes without saving', (tester) async {
      final app = _unanswered();
      final results = await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      await _tap(tester, find.text('Not now'));
      expect(results, [false]);
      expect(_updates(app), isEmpty);
    });

    testWidgets('opened by its address, it closes to Settings', (tester) async {
      await pumpScreen(
        tester,
        ResidenceScreen.new,
        app: _unanswered(),
        size: _tall,
      );
      await _tap(tester, find.text('Not now'));
      expect(routeShown(Routes.settings), findsOneWidget);
    });
  });

  group('a given answer', () {
    testWidgets('opens as an edit, with what was stored', (tester) async {
      final app = TestApp(residence: residentInLondon);
      await _open(tester, app);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
      expect(
        tester
            .widget<MmRadioGroup<ResidenceAnswer>>(
              find.byType(MmRadioGroup<ResidenceAnswer>),
            )
            .value,
        ResidenceAnswer.abroad,
      );
      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      // Cleared: prefer not to say.
      await _tap(tester, find.text(_notSaying));
      await _save(tester);
      expect(_updates(app), [
        [testUserId, null, null],
      ]);
    });

    testWidgets('each stored answer is chosen again', (tester) async {
      for (final (stored, answer) in [
        (residentInPakistan, ResidenceAnswer.inPakistan),
        (
          AccountResidence(
            residence: Residence.notStated,
            statedAt: DateTime.utc(2026, 11, 2),
          ),
          ResidenceAnswer.notSaying,
        ),
      ]) {
        await _open(tester, TestApp(residence: stored));
        expect(
          tester
              .widget<MmRadioGroup<ResidenceAnswer>>(
                find.byType(MmRadioGroup<ResidenceAnswer>),
              )
              .value,
          answer,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('abroad without a zone is Pakistan time', (tester) async {
      await _open(
        tester,
        TestApp(
          residence: AccountResidence(
            residence: Residence(country: _gb),
            statedAt: DateTime.utc(2026, 11, 2),
          ),
        ),
      );
      expect(
        tester
            .widget<MmSelectField<TimeZoneId>>(
              find.byType(MmSelectField<TimeZoneId>),
            )
            .value,
        TimeZoneId.pakistan,
      );
    });

    testWidgets('a zone or country this build does not know starts empty', (
      tester,
    ) async {
      final app = TestApp(
        residence: AccountResidence.fromRow(const {
          'residence_country': 'GB',
          'time_zone': 'Europe/Atlantis',
          'stated_at': '2026-11-02T09:00:00Z',
        }),
      );
      await _open(tester, app);
      expect(
        tester
            .widget<MmSelectField<TimeZoneId>>(
              find.byType(MmSelectField<TimeZoneId>),
            )
            .value,
        isNull,
      );
      await _save(tester);
      expect(shown('Choose your time zone.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _open(
        tester,
        TestApp(
          residence: AccountResidence.fromRow(const {
            'residence_country': 'QQ',
            'time_zone': null,
            'stated_at': '2026-11-02T09:00:00Z',
          }),
        ),
      );
      expect(
        tester
            .widget<MmSelectField<CountryCode>>(
              find.byType(MmSelectField<CountryCode>),
            )
            .value,
        isNull,
      );
    });

    testWidgets("the server's answer replaces a saved copy until changed", (
      tester,
    ) async {
      final app = TestApp(residence: residentInLondon);
      await app.cache.write(
        testUserId,
        'residence',
        AccountResidence.notStated.toRow(),
      );
      app.residences.gate.close();
      await _open(tester, app);
      expect(
        tester
            .widget<MmRadioGroup<ResidenceAnswer>>(
              find.byType(MmRadioGroup<ResidenceAnswer>),
            )
            .value,
        isNull,
      );
      app.residences.gate.open();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MmRadioGroup<ResidenceAnswer>>(
              find.byType(MmRadioGroup<ResidenceAnswer>),
            )
            .value,
        ResidenceAnswer.abroad,
      );
    });

    testWidgets('a choice made is kept when the server answers late', (
      tester,
    ) async {
      final app = TestApp(residence: residentInLondon);
      await app.cache.write(
        testUserId,
        'residence',
        AccountResidence.notStated.toRow(),
      );
      app.residences.gate.close();
      await _open(tester, app);
      await _tap(tester, find.text(_inPakistan));
      app.residences.gate.open();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MmRadioGroup<ResidenceAnswer>>(
              find.byType(MmRadioGroup<ResidenceAnswer>),
            )
            .value,
        ResidenceAnswer.inPakistan,
      );
    });
  });

  group('loading', () {
    testWidgets('shows a skeleton, then the form', (tester) async {
      final app = _unanswered()..residences.gate.close();
      await pumpScreen(tester, ResidenceScreen.new, app: app, settle: false);
      expect(find.bySemanticsLabel('Loading your answer'), findsOneWidget);
      app.residences.gate.open();
      await tester.pumpAndSettle();
      expect(shown('Do you live in Pakistan?'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (tester) async {
      final app = _unanswered()
        ..residences.fetchFailure = const ServerFailure('XX000');
      await pumpScreen(tester, ResidenceScreen.new, app: app);
      expect(find.text('Your answer could not be loaded'), findsOneWidget);
      app.residences.fetchFailure = null;
      await _tap(tester, find.text('Try again'));
      expect(shown('Do you live in Pakistan?'), findsOneWidget);
    });

    testWidgets('a stale copy says so', (tester) async {
      final app = TestApp(residence: residentInLondon);
      await app.cache.write(testUserId, 'residence', residentInLondon.toRow());
      app.residences.fetchFailure = const NetworkFailure();
      await pumpScreen(tester, ResidenceScreen.new, app: app, size: _tall);
      expect(find.textContaining('You are offline'), findsOneWidget);
      expect(find.text('United Kingdom'), findsOneWidget);
    });

    testWidgets('signed out, it waits', (tester) async {
      await pumpScreen(
        tester,
        ResidenceScreen.new,
        app: TestApp(auth: const SignedOut()),
        settle: false,
      );
      expect(find.bySemanticsLabel('Loading your answer'), findsOneWidget);
    });
  });

  testEveryVariant('is accessible and fits at 200% and right to left', (
    tester,
    variant,
  ) async {
    await _open(tester, _unanswered(), variant: variant);
    await _tap(tester, find.byType(RadioListTile<ResidenceAnswer>).at(1));
    await expectAccessible(tester);
    expect(tester.takeException(), isNull);
    final direction = Directionality.of(
      tester.element(find.byType(MmRadioGroup<ResidenceAnswer>)),
    );
    expect(
      direction,
      variant == MmVariant.urdu ? TextDirection.rtl : TextDirection.ltr,
    );
  });
}

/// The time-zone field.
typedef SelectZone = MmSelectField<TimeZoneId>;
