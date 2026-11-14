import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/saved_at.dart';
import 'package:mm_core/mm_core.dart';

/// What [label] says in [locale].
Future<String> _say(
  WidgetTester tester,
  String Function(BuildContext context) label, {
  Locale locale = const Locale('en'),
}) async {
  late String said;
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

const _nb = ' ';
final _london = TimeZoneId.parse('Europe/London');
final _newYork = TimeZoneId.parse('America/New_York');
final _tashkent = TimeZoneId.parse('Asia/Tashkent');

/// Saturday 7 November 2026, 10 AM in Pakistan, 5 AM in London.
final _morning = DateTime.utc(2026, 11, 7, 5);

void main() {
  group('dualMomentLabel', () {
    testWidgets('Pakistan time alone for a reader on Pakistan time', (
      tester,
    ) async {
      for (final zone in [TimeZoneId.pakistan, _tashkent]) {
        expect(
          await _say(tester, (c) => dualMomentLabel(c, _morning, zone)),
          await _say(tester, (c) => momentLabel(c, _morning)),
          reason: '$zone',
        );
      }
    });

    testWidgets("Pakistan time first, then the reader's city", (tester) async {
      expect(
        await _say(tester, (c) => dualMomentLabel(c, _morning, _london)),
        '7 Nov 2026, 10:00${_nb}AM Pakistan time (5:00${_nb}AM London)',
      );
    });

    testWidgets("the reader's side carries its date on another day", (
      tester,
    ) async {
      // 02:00 on the 7th in Pakistan is 16:00 on the 6th in New York.
      final night = DateTime.utc(2026, 11, 6, 21);
      expect(
        await _say(tester, (c) => dualMomentLabel(c, night, _newYork)),
        '7 Nov 2026, 2:00${_nb}AM Pakistan time '
        '(6 Nov, 4:00${_nb}PM New York)',
      );
    });

    testWidgets('follows the clock change in London', (tester) async {
      // 29 March 2026: London moves from GMT to BST.
      expect(
        await _say(
          tester,
          (c) => dualMomentLabel(c, DateTime.utc(2026, 3, 28, 12), _london),
        ),
        '28 Mar 2026, 5:00${_nb}PM Pakistan time (12:00${_nb}PM London)',
      );
      expect(
        await _say(
          tester,
          (c) => dualMomentLabel(c, DateTime.utc(2026, 3, 30, 12), _london),
        ),
        '30 Mar 2026, 5:00${_nb}PM Pakistan time (1:00${_nb}PM London)',
      );
    });

    testWidgets('a zone this build does not know is Pakistan time', (
      tester,
    ) async {
      final unknown = TimeZoneId.fromJson('Europe/Atlantis');
      expect(
        await _say(tester, (c) => dualMomentLabel(c, _morning, unknown)),
        '7 Nov 2026, 10:00${_nb}AM',
      );
    });

    testWidgets('in Urdu, Pakistan time first and the city in Urdu', (
      tester,
    ) async {
      final said = await _say(
        tester,
        (c) => dualMomentLabel(c, _morning, _london),
        locale: const Locale('ur'),
      );
      final pakistan = await _say(
        tester,
        (c) => momentLabel(c, _morning),
        locale: const Locale('ur'),
      );
      expect(said, 'پاکستانی وقت $pakistan (لندن میں 5:00$_nbصبح)');
    });
  });

  group('dualTimeLabel', () {
    testWidgets('the times of day, Pakistan first', (tester) async {
      // 8 AM in Pakistan.
      final at = DateTime.utc(2026, 11, 7, 3);
      expect(
        await _say(tester, (c) => dualTimeLabel(c, at, _london)),
        '8:00${_nb}AM Pakistan time (3:00${_nb}AM London)',
      );
      expect(
        await _say(tester, (c) => dualTimeLabel(c, at, TimeZoneId.pakistan)),
        '8:00${_nb}AM',
      );
    });
  });

  group('pakistanMomentLabel', () {
    testWidgets('says Pakistan time to a reader whose clock differs', (
      tester,
    ) async {
      final at = DateTime.utc(2026, 11, 14, 5, 42);
      expect(
        await _say(tester, (c) => pakistanMomentLabel(c, at, _london)),
        '14 Nov 2026, 10:42${_nb}AM Pakistan time',
      );
      expect(
        await _say(
          tester,
          (c) => pakistanMomentLabel(c, at, TimeZoneId.pakistan),
        ),
        '14 Nov 2026, 10:42${_nb}AM',
      );
      expect(
        await _say(
          tester,
          (c) => pakistanMomentLabel(c, at, _london),
          locale: const Locale('ur'),
        ),
        startsWith('پاکستانی وقت 14 '),
      );
    });
  });

  group('shortDateLabel', () {
    testWidgets('puts the day first in both languages', (tester) async {
      final date = CalendarDate(2026, 11, 6);
      expect(await _say(tester, (c) => shortDateLabel(c, date)), '6 Nov');
      expect(
        await _say(
          tester,
          (c) => shortDateLabel(c, date),
          locale: const Locale('ur'),
        ),
        '6 نومبر',
      );
    });
  });

  group('savedAtLabel', () {
    testWidgets("shows the reader's own time beside Pakistan's", (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 7, 12);
      expect(
        await _say(
          tester,
          (c) => savedAtLabel(
            c,
            DateTime.utc(2026, 11, 7, 5, 42),
            now: now,
            zone: _london,
          ),
        ),
        '10:42${_nb}AM Pakistan time (5:42${_nb}AM London)',
      );
    });
  });

  test('now is the clock in UTC, unless a test fixes it', () {
    final container = ProviderContainer.test();
    final now = container.read(nowProvider)();
    expect(now.isUtc, isTrue);
    expect(DateTime.now().toUtc().difference(now).inMinutes.abs(), 0);
  });
}
