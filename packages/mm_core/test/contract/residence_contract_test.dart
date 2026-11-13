// Contract tests: the countries and time zones mm_core accepts are exactly
// those in contracts/residence_vectors.json, which the database stores
// (app.supported_country_codes, app.supported_time_zones; asserted by
// supabase/tests/database/23_residence_contract.test.sql). A value only one
// side accepted would either be refused on save or break every read of the
// person's residence.
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('../../contracts/residence_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (vectors[key] as List<dynamic>).cast<Map<String, dynamic>>();

  String label(Map<String, dynamic> v) =>
      '${jsonEncode(v['value'])} (${v['name']})';

  test('the countries and their zones', () {
    final countries = cases('countries');
    expect(CountryCode.all.map((c) => c.code), [
      for (final c in countries) c['code'],
    ]);
    for (final c in countries) {
      expect(
        CountryCode.parse(c['code'] as String).timeZones.map((z) => z.name),
        c['zones'],
        reason: c['code'] as String,
      );
    }
  });

  test('the time zones and their countries', () {
    final zones = cases('timeZones');
    expect(TimeZoneId.all.map((z) => z.name), [
      for (final z in zones) z['name'],
    ]);
    for (final z in zones) {
      expect(
        TimeZoneId.parse(z['name'] as String).country?.code,
        z['country'],
        reason: z['name'] as String,
      );
    }
    expect(vectors['pakistan'], TimeZoneId.pakistan.name);
    expect(vectors['retainedZones'], isEmpty);
  });

  test('a device link is offered as the zone it links to', () {
    final links = (vectors['deviceLinks'] as Map<String, dynamic>)
        .cast<String, String>();
    for (final MapEntry(key: name, value: target) in links.entries) {
      expect(TimeZoneId.tryParse(name), isNull, reason: name);
      expect(TimeZoneId.fromDevice(name)?.name, target, reason: name);
    }
  });

  group('countryCases', () {
    final shape = RegExp(r'^[A-Z]{2}$');
    for (final v in cases('countryCases')) {
      final value = v['value'] as String;
      final valid = v['valid'] as bool;
      test(label(v), () {
        expect(CountryCode.tryParse(value)?.code == value, valid);
        if (valid) {
          expect(CountryCode.parse(value).code, value);
        } else {
          expect(() => CountryCode.parse(value), throwsFormatException);
        }
        // A stored value is read leniently: well-formed but unknown is kept.
        if (shape.hasMatch(value)) {
          expect(CountryCode.fromJson(value).isKnown, valid);
        } else {
          expect(() => CountryCode.fromJson(value), throwsFormatException);
        }
      });
    }
  });

  group('timeZoneCases', () {
    final shape = RegExp(r'^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+){1,2}$');
    for (final v in cases('timeZoneCases')) {
      final value = v['value'] as String;
      final valid = v['valid'] as bool;
      test(label(v), () {
        expect(TimeZoneId.tryParse(value) != null, valid);
        expect(TimeZoneId.fromDevice(value)?.name, v['device']);
        if (shape.hasMatch(value)) {
          expect(TimeZoneId.fromJson(value).isKnown, valid);
        } else {
          expect(() => TimeZoneId.fromJson(value), throwsFormatException);
        }
      });
    }
  });
}
