import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_date_locale.dart';
import 'package:mm_ui/src/foundation/mm_urdu_material_localizations.dart';

import '../support/testing.dart';

/// Pumps [MmDateLocale] over a date formatted with the Material
/// localizations it gives, in [locale], and returns those localizations.
Future<MaterialLocalizations> _pump(WidgetTester tester, Locale locale) async {
  late MaterialLocalizations dates;
  await tester.pumpWidget(
    themedApp(
      Scaffold(
        body: MmDateLocale(
          child: Builder(
            builder: (context) {
              dates = MaterialLocalizations.of(context);
              return Text(dates.formatShortDate(DateTime(2026, 11, 5)));
            },
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return dates;
}

void main() {
  group('MmDateLocale', () {
    test('English takes Indian English formats; Urdu stays Urdu', () {
      expect(
        MmDateLocale.forLocale(const Locale('en')),
        const Locale('en', 'IN'),
      );
      expect(
        MmDateLocale.forLocale(const Locale('en', 'US')),
        const Locale('en', 'IN'),
      );
      expect(MmDateLocale.forLocale(const Locale('ur')), const Locale('ur'));
      expect(
        MmDateLocale.forLocale(const Locale('ur', 'PK')),
        const Locale('ur', 'PK'),
      );
    });

    testWidgets('English dates put the day first, weeks from Sunday', (
      tester,
    ) async {
      final dates = await _pump(tester, const Locale('en'));
      expect(find.text('5 Nov 2026'), findsOneWidget);
      expect(
        dates.formatFullDate(DateTime(2026, 11, 5)),
        'Thursday, 5 November 2026',
      );
      // Typed day first: 03/11/2026 is 3 November.
      expect(dates.parseCompactDate('03/11/2026'), DateTime(2026, 11, 3));
      expect(dates.dateHelpText, 'dd/mm/yyyy');
      expect(dates.firstDayOfWeekIndex, 0);
      // The subtree keeps the app's direction and its own words.
      expect(
        Directionality.of(tester.element(find.text('5 Nov 2026'))),
        TextDirection.ltr,
      );
    });

    testWidgets('Urdu keeps its own formats, also day first', (tester) async {
      final dates = await _pump(tester, const Locale('ur'));
      expect(find.text('5 نومبر، 2026'), findsOneWidget);
      // The picker's day names are Urdu, not the English initials.
      expect(dates, isA<MmUrduMaterialLocalizations>());
      expect(dates.narrowWeekdays, MmUrduMaterialLocalizations.dayNames);
      expect(dates.parseCompactDate('3/11/2026'), DateTime(2026, 11, 3));
      expect(dates.firstDayOfWeekIndex, 0);
      expect(
        Directionality.of(tester.element(find.text('5 نومبر، 2026'))),
        TextDirection.rtl,
      );
    });

    testWidgets('a nested Urdu subtree forwards to the same words', (
      tester,
    ) async {
      late MaterialLocalizations outer;
      late MaterialLocalizations inner;
      await tester.pumpWidget(
        themedApp(
          MmDateLocale(
            child: Builder(
              builder: (context) {
                outer = MaterialLocalizations.of(context);
                return MmDateLocale(
                  child: Builder(
                    builder: (context) {
                      inner = MaterialLocalizations.of(context);
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();
      final innerBase = (inner as MmUrduMaterialLocalizations).base;
      expect(innerBase, (outer as MmUrduMaterialLocalizations).base);
      expect(innerBase, isNot(isA<MmUrduMaterialLocalizations>()));
    });
  });
}
