import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// An Urdu word of 3 characters written with 6 code points (letters and
/// their diacritics).
const _urdu = 'کِتَابُ';

void main() {
  group('code point limits', () {
    test('cut in whole characters to the code points the database counts', () {
      expect(_urdu.characters.length, lessThan(_urdu.runes.length));
      expect(fitCodePoints('abc', 3), 'abc');
      expect(fitCodePoints('abcd', 3), 'abc');
      // Never a letter without its diacritic.
      final cut = fitCodePoints(_urdu, 3);
      expect(cut.runes.length, lessThanOrEqualTo(3));
      expect(_urdu.startsWith(cut), isTrue);
      expect(cut.characters.every(_urdu.characters.contains), isTrue);
      // An emoji family is several code points and never cut in half.
      const family = '👨‍👩‍👧';
      expect(fitCodePoints('a$family', 3), 'a');
    });

    test('a field keeps within the limit as it is typed and pasted', () {
      const limit = CodePointLimit(6);
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      expect(limit.formatEditUpdate(value('ab'), value('abc')).text, 'abc');
      // A paste is cut in whole characters.
      final pasted = limit.formatEditUpdate(value(''), value('$_urdu$_urdu'));
      expect(pasted.text.runes.length, lessThanOrEqualTo(6));
      expect(
        pasted.selection.baseOffset,
        lessThanOrEqualTo(pasted.text.length),
      );
      // Typing more at the limit is refused, not cut from the end.
      final full = value('abcdef');
      expect(limit.formatEditUpdate(full, value('abXcdef')), full);
      expect(codePointLimit(6).single, isA<CodePointLimit>());
    });

    test('a reminder preview fits the log in code points', () {
      final long = List.filled(400, _urdu).join(' ');
      final preview = reminderPreview(long);
      expect(preview.runes.length, lessThanOrEqualTo(1000));
      expect(long.startsWith(preview), isTrue);
    });
  });

  group('app sentences', () {
    test('are kept in the UI direction whatever their first letter', () {
      const rli = '\u2067';
      const lri = '\u2066';
      const pdi = '\u2069';
      expect(
        appText('Ali Raza، Ground floor', TextDirection.rtl),
        '${rli}Ali Raza، Ground floor$pdi',
      );
      expect(
        appText('علی رضا, Flat 3', TextDirection.ltr),
        '$lri'
        'علی رضا, Flat 3$pdi',
      );
      // Unchanged when they already run that way, or have no letter.
      expect(appText('Ali Raza', TextDirection.ltr), 'Ali Raza');
      expect(appText('کرایہ', TextDirection.rtl), 'کرایہ');
      expect(appText('2026', TextDirection.rtl), '2026');
    });

    testWidgets(
      'an Urdu subtitle starting with a Latin name reads right to left',
      (tester) async {
        final sentence = appText(
          '${inSentence('Ali Raza', TextDirection.rtl)}، '
          '${inSentence('Ground floor', TextDirection.rtl)}: کرایہ واجب',
          TextDirection.rtl,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: MmVariant.urdu.theme,
            locale: const Locale('ur'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: const [Locale('en'), Locale('ur')],
            home: Scaffold(
              body: MmListTile(title: 'x', subtitle: sentence),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.textContaining('Ground floor', findRichText: true).first,
        );
        final text = paragraph.text.toPlainText();
        double leftOf(String part) {
          final start = text.indexOf(part);
          return paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: start,
                  extentOffset: start + part.length,
                ),
              )
              .first
              .left;
        }

        // Right to left: the name first (rightmost), then the unit, then the
        // Urdu words, at the left end.
        expect(leftOf('Ali Raza'), greaterThan(leftOf('Ground floor')));
        expect(leftOf('Ground floor'), greaterThan(leftOf('کرایہ')));
        // Without it, the tile lays the whole sentence out left to right.
        final bare = sentence.substring(1, sentence.length - 1);
        await tester.pumpWidget(
          MaterialApp(
            theme: MmVariant.urdu.theme,
            locale: const Locale('ur'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: const [Locale('en'), Locale('ur')],
            home: Scaffold(
              body: MmListTile(title: 'x', subtitle: bare),
            ),
          ),
        );
        final wrong = tester.renderObject<RenderParagraph>(
          find.textContaining('Ground floor', findRichText: true).first,
        );
        final wrongText = wrong.text.toPlainText();
        double wrongLeftOf(String part) {
          final start = wrongText.indexOf(part);
          return wrong
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: start,
                  extentOffset: start + part.length,
                ),
              )
              .first
              .left;
        }

        expect(wrongLeftOf('Ali Raza'), lessThan(wrongLeftOf('Ground floor')));
      },
    );
  });

  testWidgets('dates in a line keep the day with the month and year', (
    tester,
  ) async {
    late String english;
    late String urdu;
    for (final locale in const [Locale('en'), Locale('ur')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('ur')],
          home: Builder(
            builder: (context) {
              final line = dateInLine(context, CalendarDate(2026, 11, 5));
              if (locale.languageCode == 'en') {
                english = line;
              } else {
                urdu = line;
              }
              return const SizedBox();
            },
          ),
        ),
      );
    }
    // The day stays with the month; the year may wrap.
    expect(english, '5\u00A0Nov 2026');
    expect(urdu, startsWith('5\u00A0'));
  });

  testWidgets('a badge below the text leaves the subtitle the whole row', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget tile({required bool below}) {
      const badge = MmStatusBadge(status: MmStatus.neutral, label: 'Voided');
      return MaterialApp(
        theme: MmVariant.largeText.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: const [Locale('en'), Locale('ur')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: MmListTile(
            title: 'Other',
            subtitle: 'Rs 1,500 · Gate key',
            trailing: below ? const BelowText(child: badge) : badge,
          ),
        ),
      );
    }

    double subtitleWidth() => tester
        .renderObject<RenderBox>(
          find.textContaining('Gate key', findRichText: true),
        )
        .size
        .width;

    await tester.pumpWidget(tile(below: false));
    final beside = subtitleWidth();
    await tester.pumpWidget(tile(below: true));
    final under = subtitleWidth();
    expect(under, greaterThan(beside));
    // The badge sits under the subtitle.
    expect(
      tester.getTopLeft(find.textContaining('Voided', findRichText: true)).dy,
      greaterThan(
        tester
            .getBottomLeft(find.textContaining('Gate key', findRichText: true))
            .dy,
      ),
    );
  });
}
