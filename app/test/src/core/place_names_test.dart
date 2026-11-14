import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/core/place_names.dart';
import 'package:maalik_e_makaan/src/core/place_names.g.dart';
import 'package:mm_core/mm_core.dart';

/// What [label] says in [locale].
Future<T> _say<T>(
  WidgetTester tester,
  T Function(BuildContext context) label, {
  Locale locale = const Locale('en'),
}) async {
  late T said;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) {
          said = label(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return said;
}

const _urdu = Locale('ur');
final _gb = CountryCode.parse('GB');

/// The Arabic keyboard's yeh, kaf and heh, and the Arabic vowel marks,
/// none of which an Urdu name should hold.
final _notUrdu = RegExp('[يكهً-ْ]');

void main() {
  test('every stored country and zone is named in both languages', () {
    for (final country in CountryCode.all) {
      final names = placeCountries[country.code];
      expect(names, isNotNull, reason: country.code);
      expect(names!.$1.trim(), isNotEmpty);
      expect(names.$2.trim(), isNotEmpty);
      expect(_notUrdu.hasMatch(names.$2), isFalse, reason: names.$2);
    }
    for (final zone in TimeZoneId.all) {
      final names = placeCities[zone.name];
      expect(names, isNotNull, reason: zone.name);
      expect(names!.$1.trim(), isNotEmpty);
      expect(names.$2.trim(), isNotEmpty);
      expect(_notUrdu.hasMatch(names.$2), isFalse, reason: names.$2);
    }
    expect(placeCountries, hasLength(CountryCode.all.length));
    expect(placeCities, hasLength(TimeZoneId.all.length));
    expect(cldrVersion, isNotEmpty);
    expect(cldrLicence, startsWith('UNICODE LICENSE V3'));
  });

  test('each order holds every country once', () {
    final codes = {for (final c in CountryCode.all) c.code};
    for (final order in [countriesByEnglish, countriesByUrdu]) {
      expect(order.toSet(), codes);
      expect(order, hasLength(codes.length));
    }
  });

  testWidgets('names a country and a city in the app language', (tester) async {
    final london = TimeZoneId.parse('Europe/London');
    expect(await _say(tester, (c) => countryName(c, _gb)), 'United Kingdom');
    expect(
      await _say(tester, (c) => countryName(c, _gb), locale: _urdu),
      'برطانیہ',
    );
    expect(await _say(tester, (c) => cityName(c, london)), 'London');
    expect(
      await _say(tester, (c) => cityName(c, london), locale: _urdu),
      'لندن',
    );
    expect(countryNameInEnglish(_gb), 'United Kingdom');
  });

  testWidgets('falls back for a code or zone this build does not know', (
    tester,
  ) async {
    final unknown = CountryCode.fromJson('QQ');
    expect(await _say(tester, (c) => countryName(c, unknown)), 'QQ');
    expect(countryNameInEnglish(unknown), isNull);
    expect(countrySearchTerms(unknown), ['QQ']);
    final zone = TimeZoneId.fromJson('Europe/New_Place');
    expect(await _say(tester, (c) => cityName(c, zone)), 'New Place');
    expect(citySearchTerms(zone), ['Europe/New_Place']);
  });

  test('a country is found by both names, its code and short forms', () {
    final terms = countrySearchTerms(_gb);
    expect(terms, containsAll(['GB', 'United Kingdom', 'برطانیہ', 'UK']));
    expect(
      countrySearchTerms(CountryCode.parse('AE')),
      containsAll(['UAE', 'Dubai', 'دبئی']),
    );
    expect(
      citySearchTerms(TimeZoneId.parse('Asia/Dubai')),
      containsAll(['Asia/Dubai', 'Dubai', 'دبئی']),
    );
  });

  testWidgets('orders countries by the app language, Pakistan on request', (
    tester,
  ) async {
    final english = await _say(tester, countriesInOrder);
    expect(english, isNot(contains(CountryCode.pakistan)));
    expect(english.first.code, 'AF');
    final withPakistan = await _say(
      tester,
      (c) => countriesInOrder(c, withPakistan: true),
    );
    expect(withPakistan, contains(CountryCode.pakistan));
    final urdu = await _say(
      tester,
      (c) => countriesInOrder(c, withPakistan: true),
      locale: _urdu,
    );
    // بھارت before پاکستان; Unicode's order would put پ before ب.
    expect(
      urdu.indexOf(CountryCode.parse('IN')),
      lessThan(urdu.indexOf(CountryCode.pakistan)),
    );
  });

  testWidgets('labels a zone: Pakistan time, or the city time', (tester) async {
    expect(await _say(tester, (c) => zoneLabel(c, null)), 'Pakistan time');
    expect(
      await _say(tester, (c) => zoneLabel(c, TimeZoneId.pakistan)),
      'Pakistan time',
    );
    expect(
      await _say(
        tester,
        (c) => zoneLabel(c, TimeZoneId.parse('Europe/London')),
      ),
      'London time',
    );
    expect(
      await _say(
        tester,
        (c) => zoneLabel(c, TimeZoneId.parse('Europe/London')),
        locale: _urdu,
      ),
      'لندن کا وقت',
    );
  });

  testWidgets("says how far a zone's clock is from Pakistan's", (tester) async {
    final november = DateTime.utc(2026, 11, 7, 5);
    Future<String> difference(String zone, {Locale? locale}) => _say(
      tester,
      (c) => zoneDifference(c, TimeZoneId.parse(zone), november),
      locale: locale ?? const Locale('en'),
    );
    expect(await difference('Europe/London'), 'Now 5 hours behind Pakistan');
    expect(
      await difference('Asia/Kolkata'),
      'Now 30 minutes ahead of Pakistan',
    );
    expect(
      await difference('Asia/Kathmandu'),
      'Now 45 minutes ahead of Pakistan',
    );
    expect(await difference('Asia/Dubai'), 'Now 1 hour behind Pakistan');
    expect(
      await difference('Australia/Adelaide'),
      'Now 5 hours 30 minutes ahead of Pakistan',
    );
    expect(await difference('Asia/Tashkent'), 'Now the same time as Pakistan');
    expect(
      await difference('Europe/London', locale: _urdu),
      'ابھی پاکستان سے 5 گھنٹے پیچھے',
    );
  });

  test('the licence is added to the licence page once', () async {
    debugResetPlaceNameLicence();
    addTearDown(debugResetPlaceNameLicence);
    final before = await LicenseRegistry.licenses.length;
    registerPlaceNameLicence();
    registerPlaceNameLicence();
    final entries = await LicenseRegistry.licenses.toList();
    expect(entries, hasLength(before + 1));
    expect(entries.last.packages, ['Unicode CLDR $cldrVersion']);
    expect(
      entries.last.paragraphs.first.text,
      startsWith('UNICODE LICENSE V3'),
    );
  });
}
