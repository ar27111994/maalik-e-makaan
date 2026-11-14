import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/device_time_zone.dart';
import 'package:mm_core/mm_core.dart';

import '../../support/fakes.dart';

final _gb = CountryCode.parse('GB');
final _us = CountryCode.parse('US');
final _au = CountryCode.parse('AU');
final _in = CountryCode.parse('IN');

/// 7 November 2026: London on GMT, New York on EST, Sydney on AEDT.
final _november = DateTime.utc(2026, 11, 7, 5);

void main() {
  group('suggestedZone', () {
    test("the device's own zone, when it names one of the country's", () {
      expect(
        suggestedZone(
          const FakeDeviceTimeZone(ianaName: 'Europe/London'),
          _gb,
          _november,
        ),
        TimeZoneId.parse('Europe/London'),
      );
      // An old name the tz database links to a stored one.
      expect(
        suggestedZone(
          const FakeDeviceTimeZone(ianaName: 'Asia/Calcutta'),
          _in,
          _november,
        ),
        TimeZoneId.parse('Asia/Kolkata'),
      );
    });

    test('nothing when the named zone is in another country', () {
      expect(
        suggestedZone(
          const FakeDeviceTimeZone(
            ianaName: 'America/New_York',
            offset: Duration(hours: -5),
          ),
          _gb,
          _november,
        ),
        isNull,
      );
    });

    test("without a name, a zone of the country on the device's clock", () {
      FakeDeviceTimeZone following(String zone) =>
          FakeDeviceTimeZone(clock: TimeZoneId.parse(zone));
      for (final (device, country, zone) in [
        ('Europe/London', _gb, 'Europe/London'),
        ('America/New_York', _us, 'America/New_York'),
        ('America/Chicago', _us, 'America/Chicago'),
        // Phoenix keeps -7 all year; Los Angeles is -7 only in summer.
        ('America/Phoenix', _us, 'America/Phoenix'),
        ('America/Los_Angeles', _us, 'America/Los_Angeles'),
        // Lord Howe Island, Macquarie Island and Hobart come before Sydney
        // in zone.tab, and some share its clock: the city goes first.
        ('Australia/Sydney', _au, 'Australia/Sydney'),
        ('Australia/Lord_Howe', _au, 'Australia/Lord_Howe'),
        ('Australia/Adelaide', _au, 'Australia/Adelaide'),
        ('Australia/Brisbane', _au, 'Australia/Brisbane'),
        ('Australia/Perth', _au, 'Australia/Perth'),
      ]) {
        expect(
          suggestedZone(following(device), country, _november),
          TimeZoneId.parse(zone),
          reason: device,
        );
      }
      // A clock that does not change (a fixed offset): London's in winter
      // matches London only while London is on GMT.
      expect(
        suggestedZone(
          const FakeDeviceTimeZone(offset: Duration.zero),
          _gb,
          _november,
        ),
        isNull,
      );
      // A name that is not a place (UTC) is matched by the clock too.
      expect(
        suggestedZone(
          FakeDeviceTimeZone(
            ianaName: 'UTC',
            clock: TimeZoneId.parse('Europe/London'),
          ),
          _gb,
          _november,
        ),
        TimeZoneId.parse('Europe/London'),
      );
    });

    test('nothing when no zone of the country reads the device clock', () {
      // A phone still on Pakistan time, for someone who says the UK.
      expect(suggestedZone(const FakeDeviceTimeZone(), _gb, _november), isNull);
    });
  });

  test('the platform has no zone name outside a browser', () {
    const platform = PlatformTimeZone();
    expect(platform.ianaName, isNull);
    final now = DateTime.now();
    expect(platform.offsetAt(now), now.timeZoneOffset);
    final container = ProviderContainer.test();
    expect(container.read(deviceTimeZoneProvider), isA<PlatformTimeZone>());
  });
}
