// The browser's zone name; run with `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/device_time_zone.dart';

void main() {
  test('a browser names its time zone', () {
    // "Europe/London" in London; a test runner's browser is often on UTC.
    final name = const PlatformTimeZone().ianaName;
    expect(name, isNotNull);
    expect(name, isNotEmpty);
  });
}
