import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/core/saved_at.dart';

Future<String> _label(
  WidgetTester tester,
  DateTime savedAt, {
  required DateTime now,
  Locale locale = const Locale('en'),
}) async {
  late String label;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) {
          label = savedAtLabel(context, savedAt, now: now);
          return const SizedBox();
        },
      ),
    ),
  );
  return label;
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  testWidgets('today shows the Pakistan time alone', (tester) async {
    expect(
      await _label(tester, DateTime.utc(2026, 11, 7, 5, 42), now: now),
      '10:42\u202fAM',
    );
  });

  testWidgets('another day shows the date too', (tester) async {
    // 21:00 UTC on the 5th is 02:00 on the 6th in Pakistan.
    expect(
      await _label(tester, DateTime.utc(2026, 11, 5, 21), now: now),
      'Nov 6, 2:00\u202fAM',
    );
  });

  testWidgets('in Urdu', (tester) async {
    final label = await _label(
      tester,
      DateTime.utc(2026, 11, 7, 5, 42),
      now: now,
      locale: const Locale('ur'),
    );
    // Urdu's own pattern would say "10:42 a"; the time reads as in
    // English, kept left to right inside an Urdu sentence.
    expect(label, contains('10:42'));
    expect(label, contains('AM'));
    expect(label, startsWith('\u2066'));
  });
}
