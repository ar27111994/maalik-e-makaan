// Business dates stay on Pakistan time: rent, the ledger, due dates, police
// deadlines and the tax year never read a person's own time zone. This
// fails if one of their files reaches the time-zone code through any chain
// of imports and exports inside the package: directly, through the
// package's barrel (package:mm_core/mm_core.dart), through the residence
// types, or through any other file.
import 'dart:io';

import 'package:test/test.dart';

/// The time-zone code: a person's own zone, its bundled data, local times
/// in a zone, quiet hours, the dual time and the residence types.
bool _isTimeZoneCode(String path) =>
    path.startsWith('lib/src/residence/') ||
    const {
      'lib/src/time/time_zone.dart',
      'lib/src/time/time_zone_data.g.dart',
      'lib/src/time/local_date_time.dart',
      'lib/src/time/quiet_hours.dart',
      'lib/src/time/dual_time.dart',
    }.contains(path);

final _directive = RegExp(
  r'^\s*(?:import|export|part)\b([^;]*);',
  multiLine: true,
);
final _uri = RegExp('''['"]([^'"]+)['"]''');

/// The files of this package that [path] (relative to the package root)
/// imports, exports or includes, conditional URIs included. dart: and other
/// packages' URIs are left out: they cannot import this package's code.
List<String> _dependencies(String path) {
  final directory = path.substring(0, path.lastIndexOf('/'));
  return [
    for (final directive in _directive.allMatches(
      File(path).readAsStringSync(),
    ))
      for (final uri in _uri.allMatches(directive.group(1)!))
        ?_resolve(directory, uri.group(1)!),
  ];
}

String? _resolve(String directory, String uri) {
  if (uri.startsWith('package:mm_core/')) {
    return 'lib/${uri.substring('package:mm_core/'.length)}';
  }
  if (uri.contains(':')) return null;
  final parts = directory.split('/');
  for (final segment in uri.split('/')) {
    switch (segment) {
      case '..':
        parts.removeLast();
      case '.':
        break;
      default:
        parts.add(segment);
    }
  }
  return parts.join('/');
}

/// The first chain of imports from [start] that reaches the time-zone code,
/// or null when none does.
List<String>? _chainToTimeZoneCode(String start) {
  final cameFrom = <String, String?>{start: null};
  final queue = [start];
  while (queue.isNotEmpty) {
    final path = queue.removeAt(0);
    if (_isTimeZoneCode(path)) {
      return [for (String? at = path; at != null; at = cameFrom[at]) at]
          .reversed
          .toList();
    }
    for (final next in _dependencies(path)) {
      if (!cameFrom.containsKey(next)) {
        cameFrom[next] = path;
        queue.add(next);
      }
    }
  }
  return null;
}

void main() {
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
    test('${file.path} does not reach the time-zone code', () {
      expect(_chainToTimeZoneCode(file.path), isNull);
    });
  }

  group('the guard', () {
    test('follows the barrel to the time-zone code', () {
      final chain = _chainToTimeZoneCode('lib/mm_core.dart')!;
      expect(chain.first, 'lib/mm_core.dart');
      expect(_isTimeZoneCode(chain.last), isTrue);
      expect(_isTimeZoneCode('lib/src/time/time_zone_data.g.dart'), isTrue);
    });

    test('follows the residence types to the time-zone code', () {
      expect(_chainToTimeZoneCode('lib/src/residence/residence.dart'), [
        'lib/src/residence/residence.dart',
      ]);
      expect(_chainToTimeZoneCode('lib/src/time/dual_time.dart'), [
        'lib/src/time/dual_time.dart',
      ]);
    });

    test('resolves package, relative and conditional URIs', () {
      expect(
        _resolve('lib/src/rent', 'package:mm_core/mm_core.dart'),
        'lib/mm_core.dart',
      );
      expect(
        _resolve('lib/src/rent', '../time/time_zone_data.g.dart'),
        'lib/src/time/time_zone_data.g.dart',
      );
      expect(
        _resolve('lib/src/rent', './late_fee_policy.dart'),
        'lib/src/rent/late_fee_policy.dart',
      );
      expect(_resolve('lib/src/rent', 'dart:core'), isNull);
      expect(_resolve('lib/src/rent', 'package:meta/meta.dart'), isNull);
      final conditional = _uri
          .allMatches(
            _directive
                .firstMatch(
                  "import 'a.dart'\n    if (dart.library.io) '../time/quiet_hours.dart';",
                )!
                .group(1)!,
          )
          .map((match) => match.group(1))
          .toList();
      expect(conditional, ['a.dart', '../time/quiet_hours.dart']);
    });

    test('names the chain to a file that reaches it', () {
      expect(_chainToTimeZoneCode('lib/src/time/quiet_hours.dart'), [
        'lib/src/time/quiet_hours.dart',
      ]);
      expect(_chainToTimeZoneCode('lib/src/time/calendar_date.dart'), isNull);
    });
  });
}
