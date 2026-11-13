// Contract tests: mm_core's time-zone rules against
// contracts/time_zone_vectors.json, built by tool/contracts/generate.py from
// the pinned tzdata with Python's zoneinfo. The rows marked "pg" are also
// asserted against PostgreSQL by
// supabase/tests/database/23_residence_contract.test.sql, so the app and the
// database read a skipped or repeated local time the same way (the later
// instant).
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:mm_core/src/time/time_zone_data.g.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('../../contracts/time_zone_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (vectors[key] as List<dynamic>).cast<Map<String, dynamic>>();

  TimeZoneId zoneOf(Map<String, dynamic> v) => v['zone'] == null
      ? Residence.notStated.alertZone
      : TimeZoneId.parse(v['zone'] as String);

  DateTime instant(Object? iso) => DateTime.parse(iso! as String);

  ClockTime clock(Object? text) => ClockTime.parse(text! as String);

  test('the bundled data is the release the vectors were built from', () {
    expect(tzdataVersion, vectors['tzdata']);
    expect(vectors['pakistan'], TimeZoneId.pakistan.name);
  });

  group('offsets', () {
    for (final v in cases('offsets')) {
      test(v['name'], () {
        final zoned = zoneOf(v).at(instant(v['utc']));
        expect(zoned.offset.inSeconds, v['offsetSeconds']);
        expect(zoned.local.toIso(), v['local']);
      });
    }
  });

  group('localToInstant', () {
    for (final v in cases('localToInstant')) {
      test('${v['name']} (${v['kind']})', () {
        final zone = zoneOf(v);
        final local = LocalDateTime.parse(v['local'] as String);
        final at = zone.instantAt(local);
        expect(at, instant(v['utc']));
        // Normal and repeated times read back; a skipped one cannot.
        expect(zone.at(at).local == local, v['kind'] != 'gap');
      });
    }
  });

  group('quietHours', () {
    for (final v in cases('quietHours')) {
      test(v['name'], () {
        final hours = QuietHours(clock(v['start']), clock(v['end']));
        final at = instant(v['at']);
        expect(hours.isQuietAt(at, zoneOf(v)), v['quiet']);
        expect(hours.releaseAt(at, zoneOf(v)), instant(v['releaseAt']));
      });
    }
  });

  group('nextAt', () {
    for (final v in cases('nextAt')) {
      test(v['name'], () {
        final next = zoneOf(v).nextAt(
          clock(v['time']),
          after: instant(v['after']),
          isoWeekday: v['isoWeekday'] as int?,
        );
        expect(next, instant(v['utc']));
      });
    }
  });

  group('dualTime', () {
    for (final v in cases('dualTime')) {
      test(v['name'], () {
        final dual = DualTime.at(instant(v['utc']), own: zoneOf(v));
        expect(dual.pakistan.local.toIso(), v['pakistan']);
        expect(dual.own?.local.toIso(), v['own']);
      });
    }
  });
}
