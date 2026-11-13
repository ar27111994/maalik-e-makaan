import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final instant = DateTime.utc(2026, 11, 12, 10, 15);

  test("shows Pakistan's time and the owner's own", () {
    final dual = DualTime.at(instant, own: TimeZoneId.parse('Europe/London'));
    expect(dual.pakistan.local.clockTime, ClockTime(15, 15));
    expect(dual.own?.local.clockTime, ClockTime(10, 15));
    expect(dual.own?.zone.exemplarCity, 'London');
    expect(
      '$dual',
      '2026-11-12T15:15:00+05:00 (Asia/Karachi) / '
          '2026-11-12T10:15:00+00:00 (Europe/London)',
    );
  });

  test('shows one time when the clocks read the same', () {
    for (final zone in ['Asia/Karachi', 'Asia/Tashkent']) {
      final dual = DualTime.at(instant, own: TimeZoneId.parse(zone));
      expect(dual.own, isNull, reason: zone);
      expect('$dual', '2026-11-12T15:15:00+05:00 (Asia/Karachi)');
    }
  });

  test('compares', () {
    final dubai = TimeZoneId.parse('Asia/Dubai');
    expect(DualTime.at(instant, own: dubai), DualTime.at(instant, own: dubai));
    expect(
      DualTime.at(instant, own: dubai).hashCode,
      DualTime.at(instant, own: dubai).hashCode,
    );
    expect(
      DualTime.at(instant, own: dubai),
      isNot(DualTime.at(instant, own: TimeZoneId.pakistan)),
    );
  });

  test('needs a zone this build knows', () {
    expect(
      () => DualTime.at(instant, own: TimeZoneId.fromJson('Mars/Olympus')),
      throwsStateError,
    );
  });
}
