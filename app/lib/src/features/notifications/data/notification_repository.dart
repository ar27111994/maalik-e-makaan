import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in member's own notifications (REM-03), in one portfolio.
/// Every method throws [AppFailure].
abstract interface class NotificationRepository {
  /// The most unread notifications "mark all read" marks at once.
  static const markAllLimit = 1000;

  /// The page of notifications before [before], newest first.
  Future<Paged<AppNotification>> notifications(
    String portfolioId, {
    PageCursor? before,
  });

  /// How many are unread.
  Future<int> unreadCount(String portfolioId);

  /// Marks [ids] read (`mark_notifications_read`).
  Future<void> markRead(List<String> ids);

  /// Marks every unread notification of [portfolioId] read.
  Future<void> markAllRead(String portfolioId);

  Future<void> delete(String notificationId);
}

/// [NotificationRepository] over `notifications`.
final class SupabaseNotificationRepository implements NotificationRepository {
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
  Future<Paged<AppNotification>> notifications(
    String portfolioId, {
    PageCursor? before,
  }) => _guard(() async {
    final rows = await _client
        .from('notifications')
        .select(AppNotification.columns)
        .eq('portfolio_id', portfolioId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(
      rows.map(AppNotification.fromRow).toList(),
      (n) => n.cursor,
    );
  });

  @override
  Future<int> unreadCount(String portfolioId) => _guard(() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('portfolio_id', portfolioId)
        .isFilter('read_at', null)
        .limit(1)
        .count(CountOption.exact);
    return response.count;
  });

  @override
  Future<void> markRead(List<String> ids) => _guard(() async {
    if (ids.isEmpty) return;
    await _client.rpc<Object?>(
      'mark_notifications_read',
      params: {'p_ids': ids},
    );
  });

  @override
  Future<void> markAllRead(String portfolioId) => _guard(() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('portfolio_id', portfolioId)
        .isFilter('read_at', null)
        .limit(NotificationRepository.markAllLimit);
    await markRead([for (final row in rows) row['id']! as String]);
  });

  @override
  Future<void> delete(String notificationId) => _guard(() async {
    await _client.from('notifications').delete().eq('id', notificationId);
  });
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => SupabaseNotificationRepository(ref.watch(supabaseClientProvider)),
);
