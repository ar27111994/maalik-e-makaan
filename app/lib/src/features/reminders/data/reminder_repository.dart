import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The log of reminders sent (REM-01). Every method throws [AppFailure].
///
/// Members read it; owners, managers and accountants add to it. Reminders
/// leave from the landlord's own WhatsApp; the log records what was sent.
abstract interface class ReminderRepository {
  /// How many reminders [recent] reads.
  static const recentLimit = 10;

  /// A tenancy's latest reminders, newest first.
  Future<List<ReminderLog>> recent(String leaseId);

  /// Logs a reminder sent through [channel], under the id chosen for this
  /// attempt.
  Future<ReminderLog> log({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ReminderTemplate template,
    required ReminderLanguage language,
    required String message,
    ReminderChannel channel = ReminderChannel.whatsapp,
  });
}

/// [ReminderRepository] over `reminder_logs`.
final class SupabaseReminderRepository implements ReminderRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<ReminderLog>> recent(String leaseId) => _guard(() async {
    final rows = await _client
        .from('reminder_logs')
        .select(ReminderLog.columns)
        .eq('lease_id', leaseId)
        .order('sent_at', ascending: false)
        .order('id', ascending: false)
        .limit(ReminderRepository.recentLimit);
    return rows.map(ReminderLog.fromRow).toList();
  });

  @override
  Future<ReminderLog> log({
    required String id,
    required String portfolioId,
    required String leaseId,
    required ReminderTemplate template,
    required ReminderLanguage language,
    required String message,
    ReminderChannel channel = ReminderChannel.whatsapp,
  }) => _guard(() async {
    try {
      final row = await _client
          .from('reminder_logs')
          .insert({
            'id': id,
            'portfolio_id': portfolioId,
            'lease_id': leaseId,
            'channel': channel.db,
            'template': template.db,
            'language': language.db,
            'message_preview': reminderPreview(message),
          })
          .select(ReminderLog.columns)
          .single();
      return ReminderLog.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A retry of an insert that reached the server.
      final row = await _client
          .from('reminder_logs')
          .select(ReminderLog.columns)
          .eq('id', id)
          .single();
      return ReminderLog.fromRow(row);
    }
  });
}

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => SupabaseReminderRepository(ref.watch(supabaseClientProvider)),
);
