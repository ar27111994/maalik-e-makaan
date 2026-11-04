import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

void main() {
  group('MmWindowSize', () {
    test('changes class exactly at the breakpoints', () {
      expect(MmWindowSize.forWidth(0), MmWindowSize.compact);
      expect(MmWindowSize.forWidth(320), MmWindowSize.compact);
      expect(MmWindowSize.forWidth(599.9), MmWindowSize.compact);
      expect(MmWindowSize.forWidth(600), MmWindowSize.medium);
      expect(MmWindowSize.forWidth(839.9), MmWindowSize.medium);
      expect(MmWindowSize.forWidth(840), MmWindowSize.expanded);
      expect(MmWindowSize.forWidth(1199.9), MmWindowSize.expanded);
      expect(MmWindowSize.forWidth(1200), MmWindowSize.large);
      expect(MmWindowSize.forWidth(2560), MmWindowSize.large);
    });

    test('atLeast compares classes in order', () {
      expect(MmWindowSize.medium.atLeast(MmWindowSize.compact), isTrue);
      expect(MmWindowSize.medium.atLeast(MmWindowSize.medium), isTrue);
      expect(MmWindowSize.medium.atLeast(MmWindowSize.expanded), isFalse);
    });

    testWidgets('of reads the window width', (tester) async {
      late MmWindowSize size;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            size = MmWindowSize.of(context);
            return const SizedBox();
          },
        ),
        size: const Size(900, 600),
      );
      expect(size, MmWindowSize.expanded);
    });
  });

  group('MmFormats', () {
    test('defaults follow the language, with Western grouping', () {
      final english = MmFormats.defaultFor(const Locale('en'));
      final urdu = MmFormats.defaultFor(const Locale('ur', 'PK'));
      expect(english, const MoneyFormat());
      expect(urdu, const MoneyFormat(language: MoneyLanguage.urdu));
      expect(urdu.grouping, DigitGrouping.western);
      expect(urdu.nativeDigits, isFalse);
    });

    testWidgets('moneyOf falls back to the locale default', (tester) async {
      late MoneyFormat format;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            format = MmFormats.moneyOf(context);
            return const SizedBox();
          },
        ),
        variant: MmVariant.urdu,
      );
      expect(format, const MoneyFormat(language: MoneyLanguage.urdu));
    });

    testWidgets('moneyOf without any Localizations uses English', (
      tester,
    ) async {
      late MoneyFormat format;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            format = MmFormats.moneyOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(format, const MoneyFormat());
    });

    testWidgets('moneyOf reads the nearest scope and rebuilds on change', (
      tester,
    ) async {
      final seen = <MoneyFormat>[];
      final reader = Builder(
        builder: (context) {
          seen.add(MmFormats.moneyOf(context));
          return const SizedBox();
        },
      );
      const lakh = MoneyFormat(grouping: DigitGrouping.southAsian);
      await tester.pumpWidget(MmFormats(money: lakh, child: reader));
      // An equal format does not notify dependants.
      await tester.pumpWidget(MmFormats(money: lakh.copyWith(), child: reader));
      await tester.pumpWidget(
        MmFormats(money: const MoneyFormat(), child: reader),
      );
      expect(seen, [lakh, const MoneyFormat()]);
    });
  });

  group('MmLocalizations', () {
    test('every string exists in both languages and differs', () {
      List<String> strings(MmLocalizations l) => [
        l.retry,
        l.close,
        l.cancel,
        l.dismiss,
        l.showPassword,
        l.hidePassword,
        l.showFullCnic,
        l.hideFullCnic,
        l.clearText,
        l.search,
        l.loading,
        l.requiredField,
        l.optionalField,
        l.moreOptions,
        l.chooseDate,
        l.openNavigation,
        l.showAsTable,
        l.showAsChart,
        l.copied,
        l.rupees,
      ];
      final english = strings(MmLocalizations.english);
      final urdu = strings(MmLocalizations.urdu);
      for (var i = 0; i < english.length; i++) {
        expect(english[i].trim(), isNotEmpty);
        expect(urdu[i].trim(), isNotEmpty);
        expect(urdu[i], isNot(english[i]));
        expect(
          MmSemantics.hasArabicScript(urdu[i]),
          isTrue,
          reason: 'Urdu string $i is not in Urdu: ${urdu[i]}',
        );
      }
      expect(english.toSet(), hasLength(english.length));
      expect(urdu.toSet(), hasLength(urdu.length));
    });

    test('forLocale picks Urdu only for ur', () {
      expect(
        MmLocalizations.forLocale(const Locale('ur', 'PK')),
        MmLocalizations.urdu,
      );
      expect(
        MmLocalizations.forLocale(const Locale('en')),
        MmLocalizations.english,
      );
      expect(
        MmLocalizations.forLocale(const Locale('fr')),
        MmLocalizations.english,
      );
    });

    test('the delegate supports English and Urdu and loads synchronously', () {
      const delegate = MmLocalizations.delegate;
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ur')), isTrue);
      expect(delegate.isSupported(const Locale('pa')), isFalse);
      final loaded = delegate.load(const Locale('ur'));
      expect(loaded, isA<SynchronousFuture<MmLocalizations>>());
      expect(delegate.shouldReload(delegate), isFalse);
    });

    testEveryVariant('of reads the app language', (tester, variant) async {
      late MmLocalizations strings;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            strings = MmLocalizations.of(context);
            return const SizedBox();
          },
        ),
        variant: variant,
      );
      expect(
        strings,
        variant == MmVariant.urdu
            ? MmLocalizations.urdu
            : MmLocalizations.english,
      );
    });

    testWidgets('of falls back to English without the delegate', (
      tester,
    ) async {
      late MmLocalizations strings;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('ur'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              strings = MmLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(strings, MmLocalizations.english);
    });
  });
}
