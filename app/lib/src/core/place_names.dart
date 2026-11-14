import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/place_names.g.dart';
import 'package:mm_core/mm_core.dart';

/// Whether [context]'s language is Urdu.
bool _urdu(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ur';

/// The name of [country] in the app's language ("United Kingdom",
/// "برطانیہ"), from CLDR (`place_names.g.dart`, `make place-names`). A code
/// this build does not know (a newer build stored it) is shown as itself.
String countryName(BuildContext context, CountryCode country) {
  final names = placeCountries[country.code];
  if (names == null) return country.code;
  return _urdu(context) ? names.$2 : names.$1;
}

/// The English name of [country], shown under its Urdu name, so a person
/// who knows the country by its English name still recognises it. Null
/// for an unknown code.
String? countryNameInEnglish(CountryCode country) =>
    placeCountries[country.code]?.$1;

/// The city a time zone is named by, in the app's language ("London",
/// "لندن"). A zone this build does not know is named by the place in its
/// IANA name ([TimeZoneId.exemplarCity]).
String cityName(BuildContext context, TimeZoneId zone) {
  final names = placeCities[zone.name];
  if (names == null) return zone.exemplarCity;
  return _urdu(context) ? names.$2 : names.$1;
}

/// Every country a person may say they live in, sorted by its name in the
/// app's language (Urdu by the Urdu alphabet), without Pakistan unless
/// [withPakistan].
List<CountryCode> countriesInOrder(
  BuildContext context, {
  bool withPakistan = false,
}) => [
  for (final code in _urdu(context) ? countriesByUrdu : countriesByEnglish)
    if (withPakistan || code != CountryCode.pakistan.code)
      ?CountryCode.tryParse(code),
];

/// The words a search finds [country] by: its names in both languages, its
/// code, and CLDR's and the overrides' other forms ("UK", "یو کے",
/// "Dubai").
List<String> countrySearchTerms(CountryCode country) {
  final names = placeCountries[country.code];
  return [
    country.code,
    if (names != null) ...[names.$1, names.$2, ...names.$3],
  ];
}

/// The words a search finds [zone] by: its city in both languages and its
/// IANA name.
List<String> citySearchTerms(TimeZoneId zone) {
  final names = placeCities[zone.name];
  return [
    zone.name,
    if (names != null) ...[names.$1, names.$2],
  ];
}

/// The zone [zone] as a person chooses it: "Pakistan time" for Pakistan's
/// or none (what no zone means), otherwise "London time".
String zoneLabel(BuildContext context, TimeZoneId? zone) {
  final l10n = AppLocalizations.of(context);
  if (zone == null || zone.isPakistan) return l10n.zonePakistanOption;
  return l10n.zoneCityTime(cityName(context, zone));
}

/// How far [zone]'s clocks are from Pakistan's at [now]: "Now 5 hours
/// behind Pakistan", "Now 30 minutes ahead of Pakistan", "Now the same time
/// as Pakistan". It may change with the seasons, so it says "now".
String zoneDifference(BuildContext context, TimeZoneId zone, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final difference = zone.offsetAt(now) - pakistanUtcOffset;
  if (difference == Duration.zero) return l10n.zoneSameNow;
  final minutes = difference.inMinutes.abs();
  final hours = minutes ~/ 60;
  final duration = minutes % 60 == 0
      ? l10n.durationHours(hours)
      : l10n.durationHoursMinutes(hours, minutes % 60);
  return difference.isNegative
      ? l10n.zoneBehindNow(duration)
      : l10n.zoneAheadNow(duration);
}

/// Adds the licence of the CLDR names (the Unicode License v3) to the
/// licence page. Call it once, before the app runs; calling it again adds
/// nothing more.
void registerPlaceNameLicence() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks([
        'Unicode CLDR $cldrVersion',
      ], cldrLicence),
    ),
  );
}

bool _registered = false;

/// Forgets that [registerPlaceNameLicence] ran, so a test can register
/// again.
@visibleForTesting
void debugResetPlaceNameLicence() => _registered = false;
