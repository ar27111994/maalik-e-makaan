import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

final Map<String, Object?> _row = {
  'id': 'rem-1',
  'lease_id': aliLease.id,
  'channel': 'whatsapp',
  'template': 'overdue',
  'language': 'roman_ur',
  'message_preview': 'Assalam-o-Alaikum',
  'sent_at': '2026-10-15T06:00:00+00:00',
};

void main() {
  late MockSupabase supabase;
  late SupabaseReminderRepository repository;

  setUp(() {
    supabase = MockSupabase(
      (request) async => jsonResponse(
        request.headers['accept'] == 'application/vnd.pgrst.object+json'
            ? _row
            : [_row],
      ),
    );
    repository = SupabaseReminderRepository(supabase.client);
  });

  test('a log entry reads every value, and refuses unknown ones', () {
    final log = ReminderLog.fromRow(_row);
    expect(log.language, ReminderLanguage.romanUrdu);
    expect(ReminderLog.fromRow(log.toRow()), log);
    expect(ReminderLog.fromRow(log.toRow()).hashCode, log.hashCode);
    for (final value in ReminderTemplate.values) {
      expect(ReminderTemplate.parse(value.db), value);
    }
    for (final value in ReminderLanguage.values) {
      expect(ReminderLanguage.parse(value.db), value);
    }
    for (final value in ReminderChannel.values) {
      expect(ReminderChannel.parse(value.db), value);
    }
    expect(
      () => ReminderLog.fromRow({..._row, 'template': 'threat'}),
      throwsFormatException,
    );
    // The database keeps templates as `^[a-z_]{1,40}$`.
    for (final value in ReminderTemplate.values) {
      expect(RegExp(r'^[a-z_]{1,40}$').hasMatch(value.db), isTrue);
    }
  });

  test('the preview keeps the message, cleaned and cut', () {
    expect(
      reminderPreview('Line one\n\nLine two\u202E'),
      'Line one\n\nLine two',
    );
    expect(reminderPreview('x' * 1200).length, ReminderLog.maxPreviewLength);
  });

  test('the latest reminders of a tenancy, newest first', () async {
    final logs = await repository.recent(aliLease.id);
    expect(logs.single.id, 'rem-1');
    expect(supabase.request.url.queryParameters, {
      'select': ReminderLog.columns,
      'lease_id': 'eq.${aliLease.id}',
      'order': 'sent_at.desc.nullslast,id.desc.nullslast',
      'limit': '10',
    });
  });

  test('logging inserts the granted columns; a retry reads it back', () async {
    final log = await repository.log(
      id: 'rem-1',
      portfolioId: gulberg.id,
      leaseId: aliLease.id,
      template: ReminderTemplate.overdue,
      language: ReminderLanguage.romanUrdu,
      message: 'Assalam-o-Alaikum',
    );
    expect(log.id, 'rem-1');
    expect(bodyOf(supabase.request), {
      'id': 'rem-1',
      'portfolio_id': gulberg.id,
      'lease_id': aliLease.id,
      'channel': 'whatsapp',
      'template': 'overdue',
      'language': 'roman_ur',
      'message_preview': 'Assalam-o-Alaikum',
    });
    supabase.respond = (request) async => request.method == 'POST'
        ? postgrestError('23505', status: 409)
        : jsonResponse(_row);
    expect(
      (await repository.log(
        id: 'rem-1',
        portfolioId: gulberg.id,
        leaseId: aliLease.id,
        template: ReminderTemplate.overdue,
        language: ReminderLanguage.romanUrdu,
        message: 'x',
      )).id,
      'rem-1',
    );
    supabase.respond = (_) async => postgrestError('42501', status: 403);
    await expectLater(
      repository.recent(aliLease.id),
      throwsA(isA<Forbidden>()),
    );
  });
}
