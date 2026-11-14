import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/device_time_zone_stub.dart'
    if (dart.library.js_interop) 'package:maalik_e_makaan/src/core/device_time_zone_web.dart'
    as platform;
import 'package:maalik_e_makaan/src/core/place_names.g.dart';
import 'package:mm_core/mm_core.dart';

/// What the phone or browser says about its clock: only ever a suggestion
/// the person confirms, never their residence (D-16).
abstract interface class DeviceTimeZone {
  /// The device's IANA zone name, where the platform gives one (a browser,
  /// through `Intl.DateTimeFormat().resolvedOptions().timeZone`); else
  /// null (Android and iOS give only an abbreviation without a plugin).
  String? get ianaName;

  /// The device's offset from UTC at [now].
  Duration offsetAt(DateTime now);
}

/// The [DeviceTimeZone] of the running platform.
final class PlatformTimeZone implements DeviceTimeZone {
  const new();

  @override
  String? get ianaName => platform.deviceZoneName();

  @override
  Duration offsetAt(DateTime now) => now.toLocal().timeZoneOffset;
}

/// The device's clock, for the residence screen's suggestion. Tests
/// replace it.
final deviceTimeZoneProvider = Provider<DeviceTimeZone>(
  (ref) => const PlatformTimeZone(),
);

/// The zone of [country] to suggest to a person who said they live there,
/// or null: the device's own zone when it names one of [country]'s
/// ([TimeZoneId.fromDevice] reads old names such as `Asia/Calcutta`);
/// otherwise one of the country's zones whose clock reads the device's,
/// now and half a year on (so a zone with other summer rules is not
/// offered), the reviewed big cities first (`suggestedZonesFirst`: Sydney
/// before Lord Howe Island), then in `zone.tab`'s order.
///
/// Only ever offered: the person confirms it. It never chooses or suggests
/// a country, and it is not read before a country is chosen.
TimeZoneId? suggestedZone(
  DeviceTimeZone device,
  CountryCode country,
  DateTime now,
) {
  final zones = country.timeZones;
  final name = device.ianaName;
  if (name != null) {
    final named = TimeZoneId.fromDevice(name);
    if (named != null) return zones.contains(named) ? named : null;
  }
  final later = now.add(const Duration(days: 182));
  bool sameClock(TimeZoneId zone) =>
      zone.offsetAt(now) == device.offsetAt(now) &&
      zone.offsetAt(later) == device.offsetAt(later);
  final first = [
    for (final name in suggestedZonesFirst[country.code] ?? const <String>[])
      ?TimeZoneId.tryParse(name),
  ];
  for (final zone in [...first, ...zones]) {
    if (zones.contains(zone) && sameClock(zone)) return zone;
  }
  return null;
}
