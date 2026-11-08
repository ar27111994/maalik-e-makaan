import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder_repository.dart';
import 'package:mm_core/mm_core.dart';

/// A tenancy's latest reminders, the saved copy first.
final StreamNotifierProviderFamily<
  RemindersController,
  Snapshot<List<ReminderLog>>,
  String
>
remindersProvider = StreamNotifierProvider.autoDispose
    .family<RemindersController, Snapshot<List<ReminderLog>>, String>(
      RemindersController.new,
    );

/// Reads a tenancy's reminders and logs new ones. Commands throw
/// [AppFailure].
final class RemindersController extends SwrNotifier<List<ReminderLog>> {
  new(this.leaseId);

  final String leaseId;

  ReminderRepository get _repository => ref.read(reminderRepositoryProvider);

  @override
  String get query => 'reminders.$leaseId';

  @override
  Stream<Snapshot<List<ReminderLog>>> build() {
    ref.watch(reminderRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<ReminderLog>> fetch() => _repository.recent(leaseId);

  @override
  List<ReminderLog> decode(Object? json) {
    final rows = JsonRow.of({'rows': json}).list('rows');
    return [for (final row in rows) ReminderLog.fromRow(row)];
  }

  @override
  Object? encode(List<ReminderLog> value) => [for (final r in value) r.toRow()];

  /// Logs a reminder sent from the landlord's WhatsApp ([id] names this
  /// attempt: keep it for retries).
  Future<ReminderLog> log({
    required String id,
    required String portfolioId,
    required ReminderTemplate template,
    required ReminderLanguage language,
    required String message,
  }) async {
    final logged = await _repository.log(
      id: id,
      portfolioId: portfolioId,
      leaseId: leaseId,
      template: template,
      language: language,
      message: message,
    );
    // The who-owes-what list shows when a tenant was last reminded.
    ref.invalidate(receivablesProvider);
    await reload();
    return logged;
  }
}

/// What a reminder message says about the tenancy and the landlord.
@immutable
final class ReminderFacts {
  const new({
    required this.tenantName,
    required this.unitLabel,
    required this.propertyName,
    required this.amount,
    required this.date,
    required this.landlordName,
    this.receiptNumber,
    this.utility,
    this.raastId,
    this.bankAccountTitle,
    this.bankIban,
  });

  final String tenantName;
  final String unitLabel;
  final String propertyName;

  /// The amount due, or the amount received (for a thank-you).
  final Money amount;

  /// When it falls (or fell) due, or the day the payment was received.
  final CalendarDate date;

  /// Who signs the message: the portfolio's landlord name.
  final String landlordName;
  final String? receiptNumber;

  /// The kind of utility a bill is for.
  final ChargeKind? utility;
  final PhoneNumber? raastId;
  final String? bankAccountTitle;
  final Iban? bankIban;
}

/// The reminder that suits a tenancy on [today]: thanks after a payment,
/// a bill when only a utility is owed, else by the oldest due.
ReminderTemplate suggestedTemplate({
  required CalendarDate today,
  CalendarDate? dueDate,
  bool justPaid = false,
  bool utilityOnly = false,
}) {
  if (justPaid) return ReminderTemplate.paymentReceived;
  if (utilityOnly) return ReminderTemplate.utilityBill;
  if (dueDate == null || dueDate.isAfter(today)) {
    return ReminderTemplate.upcoming;
  }
  return dueDate == today
      ? ReminderTemplate.dueToday
      : ReminderTemplate.overdue;
}

/// The message of [template] in [language] about [facts], amounts in
/// [grouping]. English and Urdu come from the app's own translations;
/// Roman Urdu has its own strings.
String reminderMessage({
  required ReminderTemplate template,
  required ReminderLanguage language,
  required ReminderFacts facts,
  DigitGrouping grouping = DigitGrouping.western,
}) {
  final l10n = lookupAppLocalizations(
    Locale(language == ReminderLanguage.urdu ? 'ur' : 'en'),
  );
  final roman = language == ReminderLanguage.romanUrdu;
  final money = MoneyFormat(
    grouping: grouping,
    language: language == ReminderLanguage.urdu
        ? MoneyLanguage.urdu
        : MoneyLanguage.english,
  ).format(facts.amount);
  final date = DateFormat.yMMMd(
    language == ReminderLanguage.urdu ? 'ur' : 'en_IN',
  ).format(facts.date.toDateTimeUtc());
  final unit = roman
      ? l10n.reminderRomanUnit(facts.unitLabel, facts.propertyName)
      : l10n.reminderUnit(facts.unitLabel, facts.propertyName);
  final tenant = facts.tenantName;
  final urdu = language == ReminderLanguage.urdu;
  final pay = _paymentDetails(l10n, facts, roman: roman, urdu: urdu);
  final receipt = _identifier(facts.receiptNumber ?? '', urdu: urdu);
  final body = switch ((template, roman)) {
    (ReminderTemplate.upcoming, false) => l10n.reminderUpcoming(
      tenant,
      money,
      unit,
      date,
    ),
    (ReminderTemplate.upcoming, true) => l10n.reminderRomanUpcoming(
      tenant,
      money,
      unit,
      date,
    ),
    (ReminderTemplate.dueToday, false) => l10n.reminderDueToday(
      tenant,
      money,
      unit,
    ),
    (ReminderTemplate.dueToday, true) => l10n.reminderRomanDueToday(
      tenant,
      money,
      unit,
    ),
    (ReminderTemplate.overdue, false) => l10n.reminderOverdue(
      tenant,
      money,
      unit,
      date,
    ),
    (ReminderTemplate.overdue, true) => l10n.reminderRomanOverdue(
      tenant,
      money,
      unit,
      date,
    ),
    (ReminderTemplate.paymentReceived, false) => l10n.reminderReceived(
      tenant,
      money,
      date,
      receipt,
    ),
    (ReminderTemplate.paymentReceived, true) => l10n.reminderRomanReceived(
      tenant,
      money,
      date,
      receipt,
    ),
    (ReminderTemplate.utilityBill, false) => l10n.reminderUtility(
      tenant,
      _utility(l10n, facts.utility, roman: false),
      money,
      unit,
      date,
    ),
    (ReminderTemplate.utilityBill, true) => l10n.reminderRomanUtility(
      tenant,
      _utility(l10n, facts.utility, roman: true),
      money,
      unit,
      date,
    ),
  };
  final thanks = roman
      ? l10n.reminderRomanThanks(facts.landlordName)
      : l10n.reminderThanks(facts.landlordName);
  return [
    body,
    if (template != ReminderTemplate.paymentReceived && pay.isNotEmpty) pay,
    thanks,
  ].join('\n\n');
}

String _paymentDetails(
  AppLocalizations l10n,
  ReminderFacts facts, {
  required bool roman,
  required bool urdu,
}) {
  final raast = facts.raastId;
  final iban = facts.bankIban;
  final title = facts.bankAccountTitle ?? '';
  final raastId = raast == null ? '' : _identifier(raast.national, urdu: urdu);
  final ibanText = iban == null ? '' : _identifier(iban.formatted, urdu: urdu);
  return [
    if (raast != null && roman) l10n.reminderRomanPayRaast(raastId),
    if (raast != null && !roman) l10n.reminderPayRaast(raastId),
    if (iban != null && roman) l10n.reminderRomanPayBank(title, ibanText),
    if (iban != null && !roman) l10n.reminderPayBank(title, ibanText),
  ].join('\n');
}

/// The left-to-right mark (U+200E).
const _leftToRightMark = '\u200E';

/// [text], a number the tenant pays to or quotes (a Raast ID, an IBAN, a
/// receipt number), as an Urdu message holds it: between left-to-right
/// marks, so its groups keep their order inside the right-to-left
/// sentence ("0300 1234567", not "1234567 0300") here and in WhatsApp,
/// which lays text out by the same Unicode rules. Marks rather than an
/// isolate: the message is text the landlord edits, and text fields and
/// the database refuse bidi isolates but keep these marks. Unchanged in
/// English and Roman Urdu, which run left to right.
String _identifier(String text, {required bool urdu}) =>
    urdu && text.isNotEmpty ? '$_leftToRightMark$text$_leftToRightMark' : text;

String _utility(
  AppLocalizations l10n,
  ChargeKind? kind, {
  required bool roman,
}) {
  if (roman) {
    return switch (kind) {
      ChargeKind.electricity => l10n.reminderRomanElectricity,
      ChargeKind.gas => l10n.reminderRomanGas,
      ChargeKind.water => l10n.reminderRomanWater,
      ChargeKind.internet => l10n.reminderRomanInternet,
      _ => l10n.reminderRomanUtilityGeneric,
    };
  }
  return switch (kind) {
    ChargeKind.electricity => l10n.reminderElectricity,
    ChargeKind.gas => l10n.reminderGas,
    ChargeKind.water => l10n.reminderWater,
    ChargeKind.internet => l10n.reminderInternet,
    _ => l10n.reminderUtilityGeneric,
  };
}

/// Why now may be a poor moment to send a reminder (REM-02).
sealed class EtiquetteConcern {
  const new();
}

/// Late at night in Pakistan, until [until] (Pakistan time).
final class QuietHours extends EtiquetteConcern {
  const new(this.until);

  final DateTime until;
}

/// The Friday (Jumu'ah) prayer, until [until] (Pakistan time).
final class FridayPrayers extends EtiquetteConcern {
  const new(this.until);

  final DateTime until;
}

/// A reminder already went out at [at] (UTC).
final class RecentlyReminded extends EtiquetteConcern {
  const new(this.at);

  final DateTime at;
}

/// When reminders should wait: from [quietFrom] at night until [quietUntil]
/// in the morning, on Friday from [prayerFrom] until [prayerUntil] (hours
/// and minutes, Pakistan time), and for [minimumGap] after the last one.
abstract final class Etiquette {
  static const ({int hour, int minute}) quietFrom = (hour: 22, minute: 0);
  static const ({int hour, int minute}) quietUntil = (hour: 8, minute: 0);
  static const ({int hour, int minute}) prayerFrom = (hour: 12, minute: 30);
  static const ({int hour, int minute}) prayerUntil = (hour: 14, minute: 30);
  static const minimumGap = Duration(days: 3);

  /// The concerns about sending a reminder at [now] (UTC), when the last
  /// one went out at [lastSentAt].
  static List<EtiquetteConcern> concerns({
    required DateTime now,
    DateTime? lastSentAt,
  }) {
    final local = now.toUtc().add(pakistanUtcOffset);
    DateTime at(({int hour, int minute}) time, {int days = 0}) => DateTime.utc(
      local.year,
      local.month,
      local.day + days,
      time.hour,
      time.minute,
    );
    final minutes = local.hour * 60 + local.minute;
    int of(({int hour, int minute}) time) => time.hour * 60 + time.minute;
    return [
      if (minutes >= of(quietFrom))
        QuietHours(at(quietUntil, days: 1))
      else if (minutes < of(quietUntil))
        QuietHours(at(quietUntil)),
      if (local.weekday == DateTime.friday &&
          minutes >= of(prayerFrom) &&
          minutes < of(prayerUntil))
        FridayPrayers(at(prayerUntil)),
      if (lastSentAt != null && now.difference(lastSentAt) < minimumGap)
        RecentlyReminded(lastSentAt),
    ];
  }
}

/// Now, for the etiquette guard; tests fix it.
final Provider<DateTime Function()> nowProvider = Provider(
  (ref) =>
      () => clock.now().toUtc(),
);
