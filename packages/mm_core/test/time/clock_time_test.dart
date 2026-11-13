import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  test('validates hours and minutes', () {
    expect(ClockTime(0, 0).minuteOfDay, 0);
    expect(ClockTime(23, 59).minuteOfDay, 1439);
    expect(() => ClockTime(24, 0), throwsArgumentError);
    expect(() => ClockTime(-1, 0), throwsArgumentError);
    expect(() => ClockTime(7, 60), throwsArgumentError);
    expect(() => ClockTime(7, -1), throwsArgumentError);
  });

  test('parses exactly HH:MM', () {
    expect(ClockTime.parse('07:05'), ClockTime(7, 5));
    expect(ClockTime.parse('23:59'), ClockTime(23, 59));
    for (final bad in [
      '24:00',
      '07:60',
      '7:05',
      '07:5',
      '0705',
      ' 07:05',
      '07:05 ',
      '07:05:00',
      '۰۷:۰۵',
      '',
    ]) {
      expect(() => ClockTime.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('decodes HH:MM and PostgreSQL time', () {
    expect(ClockTime.fromJson('22:00'), ClockTime(22, 0));
    expect(ClockTime.fromJson('22:00:00'), ClockTime(22, 0));
    expect(() => ClockTime.fromJson('22:00:30'), throwsFormatException);
    expect(() => ClockTime.fromJson(2200), throwsFormatException);
    expect(() => ClockTime.fromJson(null), throwsFormatException);
  });

  test('orders, compares and prints', () {
    expect(ClockTime(7, 0).compareTo(ClockTime(22, 0)), lessThan(0));
    expect(ClockTime(7, 0), isNot(ClockTime(7, 1)));
    expect(ClockTime(7, 0).hashCode, ClockTime(7, 0).hashCode);
    expect(ClockTime(7, 5).toJson(), '07:05');
    expect('${ClockTime(17, 30)}', '17:30');
  });
}
