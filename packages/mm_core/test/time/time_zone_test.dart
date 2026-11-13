import 'package:mm_core/mm_core.dart';
import 'package:mm_core/src/time/time_zone_data.g.dart';
import 'package:test/test.dart';

DateTime utc(String iso) => DateTime.parse(iso);

DateTime fromSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  final london = TimeZoneId.parse('Europe/London');
  final newYork = TimeZoneId.parse('America/New_York');
  final lordHowe = TimeZoneId.parse('Australia/Lord_Howe');

  group('names', () {
    test('parse and tryParse take exactly a stored name', () {
      expect(TimeZoneId.tryParse('Europe/London'), london);
      expect(TimeZoneId.parse('Asia/Karachi'), TimeZoneId.pakistan);
      for (final bad in [
        'Asia/Calcutta',
        'UTC',
        'Etc/GMT+5',
        'europe/london',
        ' Europe/London',
        '',
      ]) {
        expect(TimeZoneId.tryParse(bad), isNull, reason: bad);
        expect(() => TimeZoneId.parse(bad), throwsFormatException);
      }
    });

    test('fromJson keeps a well-formed name it does not know', () {
      expect(TimeZoneId.fromJson('Europe/London').isKnown, isTrue);
      final newer = TimeZoneId.fromJson('America/Somewhere_New');
      expect(newer.name, 'America/Somewhere_New');
      expect(newer.isKnown, isFalse);
      expect(newer.country, isNull);
      expect(TimeZoneId.fromJson('Etc/GMT+5').isKnown, isFalse);
      expect(TimeZoneId.fromJson('America/Argentina/Salta').isKnown, isTrue);
      for (final bad in <Object?>[
        'UTC',
        'Europe/',
        '/London',
        'Europe/London/East/Side',
        'Europe/London\n',
        'Europe/Lon don',
        'A/${'b' * 63}',
        5,
        null,
      ]) {
        expect(
          () => TimeZoneId.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('fromDevice suggests a stored zone or nothing', () {
      expect(TimeZoneId.fromDevice('Europe/London'), london);
      expect(TimeZoneId.fromDevice('Asia/Kuwait')?.name, 'Asia/Kuwait');
      expect(TimeZoneId.fromDevice('Asia/Calcutta')?.name, 'Asia/Kolkata');
      expect(TimeZoneId.fromDevice('US/Eastern'), newYork);
      expect(TimeZoneId.fromDevice('UTC'), isNull);
      expect(TimeZoneId.fromDevice(''), isNull);
    });

    test('all, country, Pakistan and the city', () {
      expect(TimeZoneId.all, hasLength(418));
      expect(TimeZoneId.all.first.name, 'Africa/Abidjan');
      expect(london.country, CountryCode.parse('GB'));
      expect(TimeZoneId.pakistan.isPakistan, isTrue);
      expect(TimeZoneId.parse('Asia/Tashkent').isPakistan, isFalse);
      expect(london.exemplarCity, 'London');
      expect(
        TimeZoneId.parse('America/Argentina/Buenos_Aires').exemplarCity,
        'Buenos Aires',
      );
    });

    test('compares and prints', () {
      expect(london.compareTo(newYork), greaterThan(0));
      expect(london, TimeZoneId.fromJson('Europe/London'));
      expect(london.hashCode, TimeZoneId.parse('Europe/London').hashCode);
      expect(london.toJson(), 'Europe/London');
      expect('$london', 'Europe/London');
    });
  });

  group('offsets', () {
    test('follow the clock changes', () {
      expect(london.offsetAt(utc('2027-03-28T00:59:59Z')), Duration.zero);
      expect(
        london.offsetAt(utc('2027-03-28T01:00:00Z')),
        const Duration(hours: 1),
      );
      expect(
        lordHowe.offsetAt(utc('2026-10-03T15:30:00Z')),
        const Duration(hours: 11),
      );
      expect(
        lordHowe.offsetAt(utc('2026-10-03T15:29:59Z')),
        const Duration(hours: 10, minutes: 30),
      );
    });

    test('keep the 2020 offset before 2020 and the last one from 2100', () {
      expect(london.offsetAt(utc('1990-07-01T00:00:00Z')), Duration.zero);
      expect(london.offsetAt(utc('2150-07-01T00:00:00Z')), Duration.zero);
      expect(
        newYork.offsetAt(utc('2019-07-01T00:00:00Z')),
        const Duration(hours: -5),
      );
    });

    test('work for a local DateTime and with microseconds', () {
      final instant = utc('2027-03-28T01:00:00Z');
      expect(london.offsetAt(instant.toLocal()), const Duration(hours: 1));
      expect(
        london.offsetAt(instant.subtract(const Duration(microseconds: 1))),
        Duration.zero,
      );
    });

    test('nextChangeAfter', () {
      expect(
        london.nextChangeAfter(utc('2027-01-01T00:00:00Z')),
        utc('2027-03-28T01:00:00Z'),
      );
      expect(
        london.nextChangeAfter(utc('2027-03-28T01:00:00Z')),
        utc('2027-10-31T01:00:00Z'),
      );
      expect(TimeZoneId.pakistan.nextChangeAfter(DateTime.now()), isNull);
      expect(london.nextChangeAfter(utc('2100-06-01T00:00:00Z')), isNull);
    });

    test('an unknown zone has none', () {
      final newer = TimeZoneId.fromJson('America/Somewhere_New');
      final instant = utc('2026-11-12T10:15:00Z');
      expect(() => newer.offsetAt(instant), throwsStateError);
      expect(() => newer.at(instant), throwsStateError);
      expect(() => newer.nextChangeAfter(instant), throwsStateError);
      expect(
        () => newer.instantAt(LocalDateTime(CalendarDate(2026, 1, 1), 0, 0)),
        throwsStateError,
      );
    });
  });

  group('local times', () {
    test('at gives the clock and the offset', () {
      final zoned = london.at(utc('2027-07-01T10:15:30.250Z'));
      expect(zoned.local, LocalDateTime(CalendarDate(2027, 7, 1), 11, 15, 30));
      expect(zoned.offset, const Duration(hours: 1));
      expect(zoned.zone, london);
      expect(zoned.instant.isUtc, isTrue);
      expect('$zoned', '2027-07-01T11:15:30+01:00 (Europe/London)');
      expect(
        '${newYork.at(utc('2026-11-12T10:15:00Z'))}',
        '2026-11-12T05:15:00-05:00 (America/New_York)',
      );
      expect(zoned, london.at(utc('2027-07-01T10:15:30.250Z')));
      expect(zoned, isNot(london.at(utc('2027-07-01T10:15:31Z'))));
      expect(zoned.hashCode, london.at(zoned.instant).hashCode);
      expect(
        london.at(utc('1969-12-31T23:59:59.500Z')).local,
        LocalDateTime(CalendarDate(1969, 12, 31), 23, 59, 59),
      );
    });

    test('a skipped or repeated time is the later instant', () {
      LocalDateTime local(String iso) => LocalDateTime.parse(iso);
      expect(
        london.instantAt(local('2027-03-28T01:30:00')),
        utc('2027-03-28T01:30:00Z'),
      );
      expect(
        london.instantAt(local('2027-10-31T01:30:00')),
        utc('2027-10-31T01:30:00Z'),
      );
      expect(
        newYork.instantAt(local('2027-03-14T02:30:00')),
        utc('2027-03-14T07:30:00Z'),
      );
      expect(
        newYork.instantAt(local('2027-11-07T01:30:00')),
        utc('2027-11-07T06:30:00Z'),
      );
      expect(
        lordHowe.instantAt(local('2026-10-04T02:15:00')),
        utc('2026-10-03T15:45:00Z'),
      );
      expect(
        lordHowe.instantAt(local('2026-04-05T01:45:00')),
        utc('2026-04-04T15:15:00Z'),
      );
      expect(
        TimeZoneId.pakistan.instantAt(local('2026-11-12T15:15:00')),
        utc('2026-11-12T10:15:00Z'),
      );
    });

    test('nextAt is strictly later, on the weekday asked', () {
      final eight = ClockTime(8, 0);
      expect(
        london.nextAt(eight, after: utc('2026-11-12T08:00:00Z')),
        utc('2026-11-13T08:00:00Z'),
      );
      expect(
        london.nextAt(eight, after: utc('2026-11-12T07:59:59Z')),
        utc('2026-11-12T08:00:00Z'),
      );
      expect(
        london.nextAt(eight, after: utc('2026-11-12T10:00:00Z'), isoWeekday: 1),
        utc('2026-11-16T08:00:00Z'),
      );
      expect(
        () => london.nextAt(eight, after: DateTime.now(), isoWeekday: 0),
        throwsArgumentError,
      );
      expect(
        () => london.nextAt(eight, after: DateTime.now(), isoWeekday: 8),
        throwsArgumentError,
      );
    });
  });

  group('the bundled data', () {
    test('comes from the release the contracts name', () {
      expect(tzdataVersion, matches(RegExp(r'^\d{4}[a-z]$')));
      expect(tzdataFrom, DateTime.utc(2020).millisecondsSinceEpoch ~/ 1000);
      expect(tzdataUntil, DateTime.utc(2100).millisecondsSinceEpoch ~/ 1000);
    });

    test('keeps the generator assertions', () {
      for (final MapEntry(key: name, value: (index, country))
          in tzZones.entries) {
        expect(index, inInclusiveRange(0, tzSchedules.length - 1));
        expect(tzCountries[country], isNotNull, reason: name);
        final schedule = tzSchedules[index];
        expect(schedule.length.isOdd, isTrue, reason: name);
        for (var i = 1; i < schedule.length; i += 2) {
          expect(
            schedule[i],
            inInclusiveRange(tzdataFrom, tzdataUntil - 1),
            reason: name,
          );
          expect(schedule[i + 1], isNot(schedule[i - 1]), reason: name);
          if (i > 1) {
            expect(
              schedule[i] - schedule[i - 2],
              greaterThanOrEqualTo(2 * 86400),
              reason: '$name: clock changes less than two days apart',
            );
          }
        }
      }
      for (final MapEntry(key: country, value: zones) in tzCountries.entries) {
        for (final zone in zones) {
          expect(tzZones[zone]?.$2, country, reason: zone);
        }
      }
      for (final MapEntry(key: link, value: target) in tzDeviceLinks.entries) {
        expect(tzZones.containsKey(link), isFalse, reason: link);
        expect(tzZones.containsKey(target), isTrue, reason: link);
      }
      expect(tzZones.keys.toList(), [...tzZones.keys]..sort());
      expect(tzCountries.keys.toList(), [...tzCountries.keys]..sort());
    });

    test('offsets are constant between clock changes and change at them', () {
      for (final zone in TimeZoneId.all) {
        final schedule = tzSchedules[tzZones[zone.name]!.$1];
        var previous = schedule[0];
        expect(zone.offsetAt(fromSeconds(tzdataFrom)).inSeconds, previous);
        for (var i = 1; i < schedule.length; i += 2) {
          final at = schedule[i];
          expect(zone.offsetAt(fromSeconds(at - 1)).inSeconds, previous);
          expect(zone.offsetAt(fromSeconds(at)).inSeconds, schedule[i + 1]);
          final middle = i + 2 < schedule.length
              ? (at + schedule[i + 2]) ~/ 2
              : at + 86400;
          expect(zone.offsetAt(fromSeconds(middle)).inSeconds, schedule[i + 1]);
          previous = schedule[i + 1];
        }
      }
    });

    test('instantAt undoes at, except in a repeated hour', () {
      for (final zone in TimeZoneId.all) {
        final schedule = tzSchedules[tzZones[zone.name]!.$1];
        final instants = <int>[1794478500, 1814529600];
        for (var i = 1; i < schedule.length; i += 2) {
          instants.addAll([
            schedule[i] - 3600,
            schedule[i] - 1,
            schedule[i],
            schedule[i] + 3600,
          ]);
        }
        for (final seconds in instants) {
          final instant = fromSeconds(seconds);
          final local = zone.at(instant).local;
          final back = zone.instantAt(local);
          if (back != instant) {
            // Only the first of two instants that read the same.
            expect(zone.at(back).local, local, reason: '${zone.name} $local');
            expect(back.isAfter(instant), isTrue);
          }
        }
      }
    });
  });

  group('Pakistan', () {
    test('is UTC+05:00, the offset business dates use, 2020 to 2099', () {
      for (var year = 2020; year < 2100; year++) {
        for (final month in [1, 7]) {
          expect(
            TimeZoneId.pakistan.offsetAt(DateTime.utc(year, month)),
            pakistanUtcOffset,
            reason: '$year-$month',
          );
        }
      }
    });

    test("agrees with CalendarDate's today", () {
      for (var hours = 0; hours < 24 * 400; hours += 7) {
        final now = DateTime.utc(2026).add(Duration(hours: hours, minutes: 31));
        expect(
          CalendarDate.todayInPakistan(now: now),
          TimeZoneId.pakistan.at(now).local.date,
        );
      }
    });
  });
}
