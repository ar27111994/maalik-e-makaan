import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

final _london = TimeZoneId.parse('Europe/London');

AccountResidence _stated(String country, TimeZoneId? zone) => AccountResidence(
  residence: Residence(country: CountryCode.parse(country), timeZone: zone),
  statedAt: DateTime.utc(2026, 11, 2),
);

void main() {
  group('the residence', () {
    test('loads through the cache', () async {
      final app = TestApp()..residences.residence = _stated('GB', _london);
      final container = containerFor(app);
      listen(container, residenceProvider(testUserId));
      await pumpEventQueue();
      final snapshot = container.read(residenceProvider(testUserId)).value!;
      expect(snapshot.value, _stated('GB', _london));
      expect(snapshot.source, SnapshotSource.network);
      expect(app.residences.calls.single.$2, [testUserId]);
    });

    test('saving shows what the server stored and keeps it', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, residenceProvider(testUserId));
      await pumpEventQueue();
      await container
          .read(residenceProvider(testUserId).notifier)
          .save(country: CountryCode.parse('NO'), timeZone: null);
      final shown = container.read(residenceProvider(testUserId)).value!;
      expect(shown.value.residence.status, ResidenceStatus.abroad);
      expect(shown.value.residence.needsTimeZone, isTrue);
      expect(shown.value.statedAt, app.residences.now);
      expect(app.residences.calls.last.$2, [
        testUserId,
        CountryCode.parse('NO'),
        null,
      ]);
      final saved = await app.cache.read(
        testUserId,
        ResidenceController.query,
        AccountResidence.fromRow,
      );
      expect(saved!.value, shown.value);
    });

    test('a refused save throws and keeps what was shown', () async {
      final app = TestApp(residence: AccountResidence.notStated)
        ..residences.updateFailure = const RejectedFailure('account_deleted');
      final container = containerFor(app);
      listen(container, residenceProvider(testUserId));
      await pumpEventQueue();
      await expectLater(
        container
            .read(residenceProvider(testUserId).notifier)
            .save(country: CountryCode.pakistan, timeZone: null),
        throwsA(isA<RejectedFailure>()),
      );
      expect(
        container.read(residenceProvider(testUserId)).value!.value,
        AccountResidence.notStated,
      );
    });

    test('a save after nobody watches any more only saves', () async {
      final app = TestApp();
      final container = containerFor(app);
      final subscription = listen(container, residenceProvider(testUserId));
      await pumpEventQueue();
      final notifier = container.read(residenceProvider(testUserId).notifier);
      app.residences.gate.close();
      final saving = notifier.save(
        country: CountryCode.parse('GB'),
        timeZone: _london,
      );
      subscription.close();
      await pumpEventQueue();
      app.residences.gate.open();
      await saving;
      expect(app.residences.residence.residence.timeZone, _london);
      final saved = await app.cache.read(
        testUserId,
        ResidenceController.query,
        AccountResidence.fromRow,
      );
      expect(saved!.value.residence.timeZone, _london);
    });
  });

  group('the zone of alerts', () {
    test('is the stated zone', () async {
      final app = TestApp()..residences.residence = _stated('GB', _london);
      final container = containerFor(app);
      listen(container, alertZoneProvider);
      await pumpEventQueue();
      expect(container.read(alertZoneProvider), _london);
    });

    test(
      'is Pakistan time when signed out, loading, failing or unstated',
      () async {
        final signedOut = containerFor(TestApp(auth: const SignedOut()));
        expect(signedOut.read(alertZoneProvider), TimeZoneId.pakistan);

        final loading = TestApp()..residences.gate.close();
        final whileLoading = containerFor(loading);
        listen(whileLoading, alertZoneProvider);
        await pumpEventQueue();
        expect(whileLoading.read(alertZoneProvider), TimeZoneId.pakistan);

        final failing = TestApp()
          ..residences.fetchFailure = const NetworkFailure();
        final whenFailing = containerFor(failing);
        listen(whenFailing, alertZoneProvider);
        await pumpEventQueue();
        expect(whenFailing.read(alertZoneProvider), TimeZoneId.pakistan);

        final unstated = containerFor(
          TestApp(residence: AccountResidence.notStated),
        );
        listen(unstated, alertZoneProvider);
        await pumpEventQueue();
        expect(unstated.read(alertZoneProvider), TimeZoneId.pakistan);

        // Abroad without a zone, or a zone this app does not know.
        final noZone = TestApp()..residences.residence = _stated('GB', null);
        final withoutZone = containerFor(noZone);
        listen(withoutZone, alertZoneProvider);
        await pumpEventQueue();
        expect(withoutZone.read(alertZoneProvider), TimeZoneId.pakistan);
        final newer = TestApp()
          ..residences.residence = _stated(
            'GB',
            TimeZoneId.fromJson('Europe/Somewhere_New'),
          );
        final withNewer = containerFor(newer);
        listen(withNewer, alertZoneProvider);
        await pumpEventQueue();
        expect(withNewer.read(alertZoneProvider), TimeZoneId.pakistan);
      },
    );
  });

  group('the residence question', () {
    TestApp unanswered({Map<String, Object> settings = const {}}) =>
        TestApp(residence: AccountResidence.notStated, settings: settings);

    Future<bool> asked(TestApp app) async {
      final container = containerFor(app);
      listen(container, residenceQuestionProvider);
      await pumpEventQueue();
      final due = container.read(residenceQuestionProvider);
      return due;
    }

    test('is asked once the server says it was never answered', () async {
      expect(await asked(unanswered()), isTrue);
    });

    test('is not asked from a saved copy, only from the server', () async {
      final app = unanswered();
      await app.cache.write(
        testUserId,
        ResidenceController.query,
        AccountResidence.notStated.toRow(),
      );
      app.residences.gate.close();
      final container = containerFor(app);
      listen(container, residenceQuestionProvider);
      await pumpEventQueue();
      expect(container.read(residenceQuestionProvider), isFalse);
      app.residences.gate.open();
      await pumpEventQueue();
      expect(container.read(residenceQuestionProvider), isTrue);
    });

    test('is not asked when the server cannot be read', () async {
      final app = unanswered()
        ..residences.fetchFailure = const NetworkFailure();
      await app.cache.write(
        testUserId,
        ResidenceController.query,
        AccountResidence.notStated.toRow(),
      );
      expect(await asked(app), isFalse);
    });

    test('is not asked once answered, even with nothing stated', () async {
      expect(await asked(TestApp()), isFalse);
      final notSaying = TestApp(
        residence: AccountResidence(
          residence: Residence.notStated,
          statedAt: DateTime.utc(2026, 11, 2),
        ),
      );
      expect(await asked(notSaying), isFalse);
    });

    test('is not asked while signed out', () async {
      final container = containerFor(TestApp(auth: const SignedOut()));
      expect(container.read(residenceQuestionProvider), isFalse);
    });

    test('Not now sets it aside for seven days, on this device', () async {
      final app = unanswered();
      final container = containerFor(app);
      listen(container, residenceQuestionProvider);
      await pumpEventQueue();
      await container
          .read(residenceSnoozeProvider(testUserId).notifier)
          .snooze();
      expect(
        app.settings.values[AppSettings.residenceSnoozeKey],
        '$testUserId/2026-11-14T05:00:00.000Z',
      );
      expect(
        container.read(residenceSnoozeProvider(testUserId)),
        DateTime.utc(2026, 11, 14, 5),
      );
      expect(container.read(residenceQuestionProvider), isFalse);
      // A later run of the app, within the seven days and after them.
      final kept = {
        AppSettings.residenceSnoozeKey: '$testUserId/2026-11-14T05:00:00.000Z',
      };
      final sixDays = unanswered(settings: kept)
        ..now = DateTime.utc(2026, 11, 13, 5);
      expect(await asked(sixDays), isFalse);
      final eightDays = unanswered(settings: kept)
        ..now = DateTime.utc(2026, 11, 15, 5);
      expect(await asked(eightDays), isTrue);
    });

    test(
      "another user's Not now, or an unreadable one, counts as none",
      () async {
        for (final value in [
          'someone-else/2099-01-01T00:00:00.000Z',
          '$testUserId/not a time',
        ]) {
          final app = unanswered(
            settings: {AppSettings.residenceSnoozeKey: value},
          );
          expect(await asked(app), isTrue, reason: value);
        }
      },
    );
  });
}
