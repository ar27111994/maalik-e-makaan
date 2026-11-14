import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/settings/presentation/settings_screen.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../support/harness.dart';

const _tall = Size(390, 2400);

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) =>
        (w is MmTextField && w.label == label) ||
        (w is MmPhoneField && w.label == label),
  ),
  matching: find.byType(TextField),
);

String _valueOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  group('details', () {
    testWidgets('show the profile and save edits', (tester) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      expect(_valueOf(tester, 'Your name'), 'Ayesha Khan');
      expect(_valueOf(tester, 'Phone'), '0300 1234567');
      final save = find.widgetWithText(MmButton, 'Save details');
      expect(tester.widget<MmButton>(save).onPressed, isNull);

      await tester.enterText(_field('Your name'), 'Ayesha  Raza');
      await tester.enterText(_field('Phone'), '');
      await tester.pump();
      await _tap(tester, save);
      expect(app.profiles.calls.last.$1, 'updateDetails');
      expect(app.profiles.calls.last.$2, [testUserId, 'Ayesha  Raza', null]);
      expect(find.text('Your details are saved.'), findsOneWidget);
      expect(tester.widget<MmButton>(save).onPressed, isNull);
    });

    testWidgets('a phone number is checked and saved in E.164', (tester) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      // A typo is not "no phone": it is reported and nothing is saved.
      await tester.enterText(_field('Phone'), '0300 123');
      await tester.pump();
      await _tap(tester, find.widgetWithText(MmButton, 'Save details'));
      expect(shown('Enter a phone number like 03001234567.'), findsOneWidget);
      expect(
        app.profiles.calls.map((c) => c.$1),
        isNot(contains('updateDetails')),
      );
      await tester.enterText(_field('Phone'), '+44 20 7946 0958');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        app.profiles.calls.last.$2.last,
        PhoneNumber.fromE164('+442079460958'),
      );
    });

    testWidgets('a refused save is shown in the form', (tester) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      app.profiles.gate.failure = const RejectedFailure('account_deleted');
      await tester.enterText(_field('Your name'), 'A');
      await tester.pump();
      await _tap(tester, find.widgetWithText(MmButton, 'Save details'));
      expect(find.text('This account is being deleted.'), findsOneWidget);
      await tester.enterText(_field('Your name'), 'Ab');
      await tester.pump();
      expect(find.text('This account is being deleted.'), findsNothing);
    });

    testWidgets('a fresher profile replaces untouched fields only', (
      tester,
    ) async {
      final app = TestApp();
      await app.cache.write(testUserId, 'profile', {
        ...ayesha.toRow(),
        'full_name': 'Old name',
      });
      app.profiles.gate.close();
      await pumpScreen(tester, SettingsScreen.new, app: app, size: _tall);
      expect(_valueOf(tester, 'Your name'), 'Old name');
      app.profiles.gate.open();
      await tester.pumpAndSettle();
      expect(_valueOf(tester, 'Your name'), 'Ayesha Khan');
    });

    testWidgets('offline with a saved copy, it says so', (tester) async {
      final app = TestApp()..profiles.fetchFailure = const NetworkFailure();
      await app.cache.write(testUserId, 'profile', ayesha.toRow());
      await pumpScreen(tester, SettingsScreen.new, app: app, size: _tall);
      expect(find.textContaining('You are offline.'), findsOneWidget);
      expect(_valueOf(tester, 'Your name'), 'Ayesha Khan');
      expect(
        find.textContaining(RegExp('You are offline.*Pakistan time')),
        findsNothing,
      );
    });

    testWidgets('offline, an owner abroad sees the saved time in theirs too', (
      tester,
    ) async {
      final app = TestApp(residence: residentInLondon)
        ..profiles.fetchFailure = const NetworkFailure();
      await app.cache.write(testUserId, 'profile', ayesha.toRow());
      await pumpScreen(tester, SettingsScreen.new, app: app, size: _tall);
      expect(
        find.textContaining(RegExp(r'Pakistan time \(.*London\)\.$')),
        findsOneWidget,
      );
    });

    testWidgets('without a saved copy, a failure offers a retry', (
      tester,
    ) async {
      final app = TestApp()..profiles.fetchFailure = const ServerFailure('x');
      await pumpScreen(tester, SettingsScreen.new, app: app, size: _tall);
      expect(find.text('Your details could not be loaded'), findsOneWidget);
      app.profiles.fetchFailure = null;
      await _tap(tester, find.text('Try again'));
      expect(_valueOf(tester, 'Your name'), 'Ayesha Khan');
    });

    testWidgets('while loading, a placeholder says what is coming', (
      tester,
    ) async {
      final app = TestApp()..profiles.gate.close();
      await pumpScreen(
        tester,
        SettingsScreen.new,
        app: app,
        size: _tall,
        settle: false,
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Loading your details'), findsOneWidget);
      app.profiles.gate.open();
    });
  });

  group('display settings', () {
    testWidgets('the language applies at once and is saved to the profile', (
      tester,
    ) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      await _tap(tester, find.text('اردو'));
      expect(app.settings.values[AppSettings.localeKey], 'ur');
      expect(app.profiles.calls.last.$2, [testUserId, AppLanguage.urdu]);
    });

    testWidgets('a language the profile could not take is still applied', (
      tester,
    ) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      app.profiles.gate.failure = const NetworkFailure();
      await _tap(tester, find.text('اردو'));
      expect(app.settings.values[AppSettings.localeKey], 'ur');
      expect(
        find.textContaining('could not be saved to your account'),
        findsOneWidget,
      );
    });

    testWidgets('theme, contrast and grouping are kept on the device', (
      tester,
    ) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      await _tap(tester, find.text('Dark'));
      expect(app.settings.values[AppSettings.themeKey], 'dark');
      await _tap(tester, find.text('High contrast'));
      expect(app.settings.values[AppSettings.highContrastKey], isTrue);
      await _tap(tester, find.text('Lakh and crore (Rs\u00a012,50,000)'));
      expect(app.settings.values[AppSettings.groupingKey], 'southAsian');
    });

    testWidgets('the text size preview shows the phone setting', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        SettingsScreen.new,
        variant: MmVariant.largeText,
        size: const Size(390, 4200),
      );
      expect(find.textContaining('text size is 200%'), findsOneWidget);
      expect(find.byType(MmAmount), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Preview')), findsOneWidget);
    });
  });

  group('account', () {
    testWidgets('shows who is signed in and signs out', (tester) async {
      final app = await pumpScreen(tester, SettingsScreen.new, size: _tall);
      expect(find.text(breakableEmail(testEmail)), findsOneWidget);
      await _tap(tester, find.widgetWithText(MmButton, 'Sign out'));
      expect(app.auth.calls.last.$2, [SignOutCause.userRequest]);
    });

    testWidgets('leads to account deletion', (tester) async {
      await pumpScreen(tester, SettingsScreen.new, size: _tall);
      await _tap(tester, find.widgetWithText(MmButton, 'Delete account'));
      expect(routeShown(Routes.deleteAccount), findsOneWidget);
    });
  });

  testWidgets('shows the open-source licences, the fonts and icons among '
      'them', (tester) async {
    addTearDown(MmLicenses.debugReset);
    MmLicenses.register(bundle: _LicenceFiles());
    await pumpScreen(tester, SettingsScreen.new, size: _tall);
    await _tap(tester, find.widgetWithText(MmButton, 'Open-source licences'));
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Maalik-e-Makaan'), findsWidgets);
    for (final name in MmLicenses.files.keys) {
      await tester.scrollUntilVisible(find.text(name), 200);
      expect(find.text(name), findsOneWidget);
    }
  });

  testEveryVariant('fits at 320 dp and meets the guidelines', (
    tester,
    variant,
  ) async {
    await pumpScreen(
      tester,
      SettingsScreen.new,
      variant: variant,
      size: Size(320, variant == MmVariant.largeText ? 5200 : 2600),
    );
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });

  group('where you live', () {
    Finder row() => find.ancestor(
      of: find.byIcon(MmIcons.location),
      matching: find.byType(MmListTile),
    );

    String textOf(WidgetTester tester) => [
      for (final text in tester.widgetList<Text>(
        find.descendant(of: row(), matching: find.byType(Text)),
      ))
        text.data ?? '',
    ].join(' | ');

    testWidgets('shows each kind of answer, only to the person', (
      tester,
    ) async {
      for (final (residence, expected) in [
        (
          AccountResidence.notStated,
          'Not answered yet | Answer to see your own time beside Pakistan '
              'time.',
        ),
        (
          AccountResidence(
            residence: Residence.notStated,
            statedAt: DateTime.utc(2026, 11, 2),
          ),
          'You chose not to say | Pakistan time',
        ),
        (residentInPakistan, 'Pakistan | Pakistan time'),
        (
          residentInLondon,
          'United Kingdom | London time\nNow 5 hours behind Pakistan',
        ),
        (
          AccountResidence(
            residence: Residence(country: CountryCode.parse('GB')),
            statedAt: DateTime.utc(2026, 11, 2),
          ),
          'United Kingdom | Pakistan time',
        ),
        (
          AccountResidence.fromRow(const {
            'residence_country': 'GB',
            'time_zone': 'Europe/Atlantis',
            'stated_at': '2026-11-02T09:00:00Z',
          }),
          'United Kingdom | Pakistan time',
        ),
      ]) {
        await pumpScreen(
          tester,
          SettingsScreen.new,
          app: TestApp(residence: residence),
          size: _tall,
        );
        expect(find.text('Where you live'), findsOneWidget);
        expect(find.text('Only you see this.'), findsOneWidget);
        expect(textOf(tester), expected);
        // A fresh app for the next answer.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('opens the question to answer or change it', (tester) async {
      await pumpScreen(tester, SettingsScreen.new, size: _tall);
      await _tap(tester, row());
      expect(routeShown(Routes.residence), findsOneWidget);
    });

    testWidgets('shows a skeleton while it loads', (tester) async {
      final app = TestApp()..residences.gate.close();
      await pumpScreen(
        tester,
        SettingsScreen.new,
        app: app,
        size: _tall,
        settle: false,
      );
      expect(find.bySemanticsLabel('Loading your answer'), findsOneWidget);
      app.residences.gate.open();
      await tester.pumpAndSettle();
      expect(row(), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (tester) async {
      final failing = TestApp()
        ..residences.fetchFailure = const ServerFailure('XX000');
      await pumpScreen(tester, SettingsScreen.new, app: failing, size: _tall);
      expect(find.text('Your answer could not be loaded'), findsOneWidget);
      failing.residences.fetchFailure = null;
      await _tap(
        tester,
        find.descendant(
          of: find.byType(MmErrorState),
          matching: find.text('Try again'),
        ),
      );
      expect(row(), findsOneWidget);
    });

    testWidgets('a stale copy says so', (tester) async {
      final offline = TestApp()
        ..residences.fetchFailure = const NetworkFailure();
      await offline.cache.write(
        testUserId,
        'residence',
        residentInPakistan.toRow(),
      );
      await pumpScreen(tester, SettingsScreen.new, app: offline, size: _tall);
      expect(find.textContaining('You are offline.'), findsOneWidget);
      expect(row(), findsOneWidget);
    });

    testWidgets('is not shown while signed out', (tester) async {
      await pumpScreen(
        tester,
        SettingsScreen.new,
        app: TestApp(auth: const SignedOut()),
        size: _tall,
      );
      expect(find.text('Where you live'), findsNothing);
    });
  });
}

/// The licence files, as mm_ui's package on disk holds them.
class _LicenceFiles extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(
      '../packages/mm_ui/${key.replaceFirst('packages/mm_ui/', '')}',
    );
    return ByteData.sublistView(file.readAsBytesSync());
  }
}
