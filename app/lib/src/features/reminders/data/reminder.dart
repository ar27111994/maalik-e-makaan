import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';

/// Which reminder a message is (REM-01), as `reminder_logs.template`
/// stores it.
enum ReminderTemplate with DbEnum {
  /// Rent falls due in a few days.
  upcoming('upcoming'),

  /// Rent falls due today.
  dueToday('due_today'),

  /// Rent is past its due date.
  overdue('overdue'),

  /// Thanks for a payment, with its receipt number.
  paymentReceived('payment_received'),

  /// A utility bill to pay.
  utilityBill('utility_bill');

  new(this.db);

  @override
  final String db;

  static ReminderTemplate parse(String name) => parseDbEnum(values, name);
}

/// The language of a reminder's message (`reminder_logs.language`): the
/// tenant's, whatever the app's.
enum ReminderLanguage with DbEnum {
  english('en'),
  urdu('ur'),

  /// Urdu in Latin letters, as many tenants type on WhatsApp.
  romanUrdu('roman_ur');

  new(this.db);

  @override
  final String db;

  static ReminderLanguage parse(String name) => parseDbEnum(values, name);
}

/// How a reminder went out (`public.reminder_channel`).
enum ReminderChannel with DbEnum {
  whatsapp('whatsapp'),
  sms('sms'),
  call('call'),
  inPerson('in_person'),
  other('other');

  new(this.db);

  @override
  final String db;

  static ReminderChannel parse(String name) => parseDbEnum(values, name);
}

/// A reminder that was sent (`reminder_logs`).
@immutable
final class ReminderLog {
  const new({
    required this.id,
    required this.leaseId,
    required this.channel,
    required this.template,
    required this.language,
    required this.sentAt,
    this.messagePreview,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'reminder');
    return ReminderLog(
      id: row.string('id'),
      leaseId: row.string('lease_id'),
      channel: row.choice('channel', ReminderChannel.parse),
      template: row.choice('template', ReminderTemplate.parse),
      language: row.choice('language', ReminderLanguage.parse),
      messagePreview: row.optionalString('message_preview'),
      sentAt: row.timestamp('sent_at'),
    );
  }

  static const columns =
      'id,lease_id,channel,template,language,message_preview,sent_at';

  /// The longest message the log keeps.
  static const maxPreviewLength = 1000;

  final String id;
  final String leaseId;
  final ReminderChannel channel;
  final ReminderTemplate template;
  final ReminderLanguage language;
  final String? messagePreview;
  final DateTime sentAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'lease_id': leaseId,
    'channel': channel.db,
    'template': template.db,
    'language': language.db,
    'message_preview': messagePreview,
    'sent_at': sentAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is ReminderLog && mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// The copy of [message] a log keeps: as written, without unsafe
/// characters, cut to [ReminderLog.maxPreviewLength] code points (the
/// database's `char_length`), in whole characters.
String reminderPreview(String message) => fitCodePoints(
  linesWithin(message, ReminderLog.maxPreviewLength),
  ReminderLog.maxPreviewLength,
).trimRight();
