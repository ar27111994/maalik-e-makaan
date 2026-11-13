import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final gb = CountryCode.parse('GB');
  final london = TimeZoneId.parse('Europe/London');

  group('CountryCode', () {
    test('tryParse reads typed input, supported codes only', () {
      expect(CountryCode.tryParse(' gb '), gb);
      expect(CountryCode.tryParse('pk'), CountryCode.pakistan);
      for (final bad in ['UK', 'XK', 'XX', 'PAK', 'G', '', '586']) {
        expect(CountryCode.tryParse(bad), isNull, reason: bad);
      }
    });

    test('parse is strict', () {
      expect(CountryCode.parse('PK').isPakistan, isTrue);
      for (final bad in ['pk', ' PK', 'UK', '']) {
        expect(() => CountryCode.parse(bad), throwsFormatException);
      }
    });

    test('fromJson keeps two letters it does not know', () {
      expect(CountryCode.fromJson('GB').isKnown, isTrue);
      final newer = CountryCode.fromJson('XK');
      expect(newer.isKnown, isFalse);
      expect(newer.timeZones, isEmpty);
      for (final bad in <Object?>['gb', 'GBR', '', ' GB', 44, null]) {
        expect(
          () => CountryCode.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('its zones, in zone.tab order', () {
      expect(CountryCode.pakistan.timeZones, [TimeZoneId.pakistan]);
      expect(gb.timeZones, [london]);
      expect(CountryCode.parse('US').timeZones.first.name, 'America/New_York');
      expect(CountryCode.parse('BV').timeZones, isEmpty);
      expect(CountryCode.all, hasLength(249));
      expect(CountryCode.all.first.code, 'AD');
    });

    test('compares and prints', () {
      expect(gb.compareTo(CountryCode.pakistan), lessThan(0));
      expect(gb, CountryCode.fromJson('GB'));
      expect(gb.hashCode, CountryCode.parse('GB').hashCode);
      expect(gb.toJson(), 'GB');
      expect('$gb', 'GB');
    });
  });

  group('Residence', () {
    test('status', () {
      expect(Residence.notStated.status, ResidenceStatus.notStated);
      expect(
        const Residence(country: CountryCode.pakistan).status,
        ResidenceStatus.pakistan,
      );
      expect(Residence(country: gb).status, ResidenceStatus.abroad);
      // A zone alone says nothing about where the person lives.
      expect(Residence(timeZone: london).status, ResidenceStatus.notStated);
    });

    test('an owner abroad without a zone is asked for one', () {
      expect(Residence(country: gb).needsTimeZone, isTrue);
      expect(Residence(country: gb, timeZone: london).needsTimeZone, isFalse);
      expect(
        const Residence(country: CountryCode.pakistan).needsTimeZone,
        isFalse,
      );
      expect(Residence.notStated.needsTimeZone, isFalse);
    });

    test('alerts follow a known stated zone, else Pakistan time', () {
      expect(Residence(country: gb, timeZone: london).alertZone, london);
      expect(Residence(country: gb).alertZone, TimeZoneId.pakistan);
      expect(Residence.notStated.alertZone, TimeZoneId.pakistan);
      expect(
        Residence(timeZone: TimeZoneId.fromJson('Mars/Olympus')).alertZone,
        TimeZoneId.pakistan,
      );
    });

    test('compares and prints', () {
      expect(
        Residence(country: gb, timeZone: london),
        Residence(country: CountryCode.parse('GB'), timeZone: london),
      );
      expect(Residence(country: gb), isNot(Residence.notStated));
      expect(
        Residence(country: gb).hashCode,
        Residence(country: CountryCode.parse('GB')).hashCode,
      );
      expect(
        '${Residence(country: gb, timeZone: london)}',
        'Residence(GB, Europe/London)',
      );
      expect('${Residence.notStated}', 'Residence(-, -)');
    });
  });

  group('OwnerAbroad', () {
    test('NULL is not yet answered, never a default', () {
      expect(OwnerAbroad.fromJson(null), OwnerAbroad.notAnswered);
      expect(OwnerAbroad.fromJson(true), OwnerAbroad.abroad);
      expect(OwnerAbroad.fromJson(false), OwnerAbroad.inPakistan);
      expect(() => OwnerAbroad.fromJson('true'), throwsFormatException);
      for (final answer in OwnerAbroad.values) {
        expect(OwnerAbroad.fromJson(answer.toJson()), answer);
      }
    });

    test('the overseas-owner rules run only when abroad', () {
      expect(OwnerAbroad.notAnswered.needsAnswer, isTrue);
      expect(OwnerAbroad.abroad.needsAnswer, isFalse);
      expect(OwnerAbroad.inPakistan.needsAnswer, isFalse);
      expect(OwnerAbroad.abroad.overseasRulesApply, isTrue);
      expect(OwnerAbroad.notAnswered.overseasRulesApply, isFalse);
      expect(OwnerAbroad.inPakistan.overseasRulesApply, isFalse);
    });
  });
}
