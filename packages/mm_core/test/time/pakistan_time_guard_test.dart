// Business dates stay on Pakistan time: rent, the ledger, due dates, police
// deadlines and the tax year never read a person's own time zone. This
// fails if one of their files starts to import the time-zone code.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  const forbidden = ['time_zone.dart', 'quiet_hours.dart', 'dual_time.dart'];
  final business = [
    ...Directory('lib/src/rent').listSync(recursive: true),
    ...Directory('lib/src/ledger').listSync(recursive: true),
    for (final name in [
      'calendar_date.dart',
      'month_period.dart',
      'tax_year.dart',
      'date_range.dart',
    ])
      File('lib/src/time/$name'),
  ].whereType<File>().where((file) => file.path.endsWith('.dart')).toList();

  test('there are business files to check', () {
    expect(business.length, greaterThanOrEqualTo(6));
  });

  for (final file in business) {
    test('${file.path} does not import the time-zone code', () {
      final imports = file
          .readAsLinesSync()
          .where(
            (line) => line.startsWith('import ') || line.startsWith('export '),
          )
          .where((line) => forbidden.any(line.contains));
      expect(imports, isEmpty);
    });
  }
}
