import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

final _facts = ReminderFacts(
  tenantName: 'Ali Raza',
  unitLabel: 'Ground floor',
  propertyName: 'Gulberg House',
  amount: const Money.fromRupees(125000),
  date: CalendarDate(2026, 11, 5),
  landlordName: 'Ayesha Khan',
  receiptNumber: 'MM-2026-00042',
  utility: ChargeKind.gas,
  raastId: PhoneNumber.fromE164('+923001234567'),
  bankAccountTitle: 'Ayesha Khan',
  bankIban: Iban.parse('PK36SCBL0000001123456702'),
);

String _message(ReminderTemplate template, ReminderLanguage language) =>
    reminderMessage(
      template: template,
      language: language,
      facts: _facts,
      grouping: DigitGrouping.southAsian,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en_IN');
    await initializeDateFormatting('ur');
  });

  test('every template reads in each language, signed and with how to pay', () {
    for (final template in ReminderTemplate.values) {
      for (final language in ReminderLanguage.values) {
        final message = _message(template, language);
        expect(message, contains('Ali Raza'), reason: '$template $language');
        expect(
          message.contains('PK36 SCBL'),
          template != ReminderTemplate.paymentReceived,
          reason: '$template $language',
        );
      }
    }
    final english = _message(
      ReminderTemplate.overdue,
      ReminderLanguage.english,
    );
    expect(english, contains('Rs 1,25,000'));
    expect(english, contains('5 Nov 2026'));
    expect(english, endsWith('Regards, Ayesha Khan'));
    final urdu = _message(ReminderTemplate.upcoming, ReminderLanguage.urdu);
    expect(urdu, startsWith('السلام علیکم'));
    expect(urdu, contains('1,25,000 روپے'));
    final roman = _message(
      ReminderTemplate.utilityBill,
      ReminderLanguage.romanUrdu,
    );
    expect(roman, contains('gas ka bill'));
    expect(
      _message(ReminderTemplate.paymentReceived, ReminderLanguage.english),
      contains('MM-2026-00042'),
    );
    expect(
      _message(ReminderTemplate.dueToday, ReminderLanguage.urdu),
      contains('آج'),
    );
    for (final (kind, word) in [
      (ChargeKind.electricity, 'electricity'),
      (ChargeKind.water, 'water'),
      (ChargeKind.internet, 'internet'),
      (null, 'utility'),
    ]) {
      final facts = ReminderFacts(
        tenantName: 'A',
        unitLabel: 'U',
        propertyName: 'P',
        amount: Money.zero,
        date: CalendarDate(2026, 1, 1),
        landlordName: 'L',
        utility: kind,
      );
      expect(
        reminderMessage(
          template: ReminderTemplate.utilityBill,
          language: ReminderLanguage.english,
          facts: facts,
        ),
        contains('$word bill'),
      );
      expect(
        reminderMessage(
          template: ReminderTemplate.utilityBill,
          language: ReminderLanguage.romanUrdu,
          facts: facts,
        ),
        contains('ka bill'),
      );
    }
  });

  test('an overdue reminder says what is overdue, not that it is rent', () {
    expect(
      _message(ReminderTemplate.overdue, ReminderLanguage.english),
      startsWith(
        'Assalam-o-Alaikum Ali Raza. Rs\u00A01,25,000 is overdue for Ground '
        'floor, Gulberg House; the oldest of it was due on 5 Nov 2026.',
      ),
    );
    expect(
      _message(ReminderTemplate.overdue, ReminderLanguage.romanUrdu),
      contains('sab se purani raqam 5 Nov 2026 ko deni thi'),
    );
    expect(
      _message(ReminderTemplate.overdue, ReminderLanguage.urdu),
      allOf(contains('ان میں سب سے پرانی رقم'), contains('کو دینی تھی')),
    );
    for (final language in ReminderLanguage.values) {
      for (final template in [
        ReminderTemplate.upcoming,
        ReminderTemplate.dueToday,
        ReminderTemplate.overdue,
      ]) {
        final message = _message(template, language);
        expect(message, isNot(contains('rent')), reason: '$template');
        expect(message, isNot(contains('kiraya')), reason: '$template');
        expect(message, isNot(contains('کرایہ')), reason: '$template');
      }
    }
  });

  test('numbers in an Urdu reminder are kept left to right', () {
    const mark = '\u200E';
    final urdu = _message(ReminderTemplate.overdue, ReminderLanguage.urdu);
    expect(
      urdu.split('\n\n')[1],
      'آپ راست کے ذریعے ${mark}0300 1234567$mark پر ادائیگی کر سکتے ہیں۔\n'
      // The IBAN on a line of its own, so it is never split by the words
      // before it, and no full stop is left beside its last group.
      'بینک ٹرانسفر: Ayesha Khan، آئی بی اے این:\n'
      '${mark}PK36 SCBL 0000 0011 2345 6702$mark',
    );
    expect(
      _message(ReminderTemplate.paymentReceived, ReminderLanguage.urdu),
      contains('رسید نمبر: ${mark}MM-2026-00042$mark۔'),
    );
    // English and Roman Urdu run left to right: no marks.
    for (final language in [
      ReminderLanguage.english,
      ReminderLanguage.romanUrdu,
    ]) {
      expect(
        _message(ReminderTemplate.overdue, language),
        isNot(contains(mark)),
      );
    }
    // The marks survive what the log keeps, which the database accepts.
    expect(reminderPreview(urdu), contains('${mark}0300 1234567$mark'));
  });

  testWidgets('the Raast number reads in order in an Urdu paragraph', (
    tester,
  ) async {
    final line = _message(
      ReminderTemplate.overdue,
      ReminderLanguage.urdu,
    ).split('\n\n')[1].split('\n').first;
    final painter = TextPainter(
      text: TextSpan(text: line, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 2000);
    addTearDown(painter.dispose);
    double leftOf(String part) {
      final start = line.indexOf(part);
      return painter
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + part.length),
          )
          .first
          .left;
    }

    // Left to right on the line: "0300" before "1234567".
    expect(leftOf('0300'), lessThan(leftOf('1234567')));
    // Without the marks, the groups come out reversed.
    final bare = line.replaceAll('\u200E', '');
    final reversed = TextPainter(
      text: TextSpan(text: bare, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 2000);
    addTearDown(reversed.dispose);
    double bareLeftOf(String part) {
      final start = bare.indexOf(part);
      return reversed
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + part.length),
          )
          .first
          .left;
    }

    expect(bareLeftOf('0300'), greaterThan(bareLeftOf('1234567')));
  });

  test('the suggested reminder follows the due date', () {
    final today = CalendarDate(2026, 11, 7);
    expect(suggestedTemplate(today: today), ReminderTemplate.upcoming);
    expect(
      suggestedTemplate(today: today, dueDate: today.addDays(3)),
      ReminderTemplate.upcoming,
    );
    expect(
      suggestedTemplate(today: today, dueDate: today),
      ReminderTemplate.dueToday,
    );
    expect(
      suggestedTemplate(today: today, dueDate: today.addDays(-1)),
      ReminderTemplate.overdue,
    );
    expect(
      suggestedTemplate(today: today, utilityOnly: true),
      ReminderTemplate.utilityBill,
    );
    expect(
      suggestedTemplate(today: today, justPaid: true),
      ReminderTemplate.paymentReceived,
    );
  });

  test('etiquette: late night, Friday prayers and a recent reminder', () {
    // 11 PM and 6 AM in Pakistan: quiet hours until 8 AM.
    final night = Etiquette.concerns(now: DateTime.utc(2026, 11, 7, 18));
    expect((night.single as QuietHours).until, DateTime.utc(2026, 11, 8, 8));
    final dawn = Etiquette.concerns(now: DateTime.utc(2026, 11, 7, 1));
    expect((dawn.single as QuietHours).until, DateTime.utc(2026, 11, 7, 8));
    // Friday 1 PM: the prayer until 2:30 PM.
    final friday = Etiquette.concerns(now: DateTime.utc(2026, 11, 13, 8));
    expect(
      (friday.single as FridayPrayers).until,
      DateTime.utc(2026, 11, 13, 14, 30),
    );
    // Friday 3 PM, a reminder two days ago.
    final sent = DateTime.utc(2026, 11, 11, 6);
    final recent = Etiquette.concerns(
      now: DateTime.utc(2026, 11, 13, 10),
      lastSentAt: sent,
    );
    expect((recent.single as RecentlyReminded).at, sent);
    expect(
      Etiquette.concerns(
        now: DateTime.utc(2026, 11, 14, 10),
        lastSentAt: DateTime.utc(2026, 11, 10, 6),
      ),
      isEmpty,
    );
  });

  test('logging a reminder shows it in the history', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = remindersProvider(aliLease.id);
    listen(container, provider);
    await pumpEventQueue();
    expect(container.read(provider).value!.value, hasLength(1));
    await container
        .read(provider.notifier)
        .log(
          id: 'rem-2',
          portfolioId: gulberg.id,
          template: ReminderTemplate.upcoming,
          language: ReminderLanguage.english,
          message: 'Hello',
        );
    expect(container.read(provider).value!.value.first.id, 'rem-2');
    expect(container.read(nowProvider)(), app.now);
  });
}
