import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';

/// The member's notifications in a portfolio, newest first, the saved copy
/// first, 50 at a time.
final StreamNotifierProviderFamily<
  NotificationsController,
  Snapshot<Paged<AppNotification>>,
  String
>
notificationsProvider = StreamNotifierProvider.autoDispose
    .family<NotificationsController, Snapshot<Paged<AppNotification>>, String>(
      NotificationsController.new,
    );

/// How often the unread count is read again while it shows: the daily job
/// adds notifications whenever it runs.
const unreadRefreshInterval = Duration(minutes: 15);

/// How soon a failed read of the unread count is tried again.
const unreadRetryDelay = Duration(minutes: 1);

/// How many notifications of the current portfolio are unread, for the
/// badge on More; null while unknown (loading, failed, signed out).
///
/// It is read again every [unreadRefreshInterval] while shown, after
/// [unreadRetryDelay] when a read fails, whenever the inbox is read from
/// the server, and when the app comes back to the foreground (the shell).
final FutureProvider<int?> unreadCountProvider =
    FutureProvider.autoDispose<int?>((ref) async {
      if (ref.watch(currentUserIdProvider) == null) return null;
      final portfolio = ref.watch(currentPortfolioProvider).value;
      if (portfolio == null) return null;
      int? count;
      try {
        count = await ref
            .watch(notificationRepositoryProvider)
            .unreadCount(portfolio.id);
      } on AppFailure {
        count = null;
      }
      if (ref.mounted) {
        final timer = Timer(
          count == null ? unreadRetryDelay : unreadRefreshInterval,
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return count;
    });

/// Reads the inbox and changes it. Commands throw [AppFailure].
final class NotificationsController
    extends SwrNotifier<Paged<AppNotification>> {
  new(this.portfolioId);

  final String portfolioId;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  String get query => 'notifications.$portfolioId';

  @override
  Stream<Snapshot<Paged<AppNotification>>> build() {
    ref.watch(notificationRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<AppNotification>> fetch() async {
    final page = await _repository.notifications(portfolioId);
    // The inbox as the server holds it now: the badge follows it.
    if (ref.mounted) ref.invalidate(unreadCountProvider);
    return page;
  }

  @override
  Paged<AppNotification> decode(Object? json) =>
      Paged.fromJson(json, AppNotification.fromRow);

  @override
  Object? encode(Paged<AppNotification> value) =>
      value.toJson((n) => n.toRow());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.notifications(portfolioId, before: next);
    await show(current.followedBy(more));
  }

  /// Marks [notification] read. The list shows it read at once: this
  /// changes nothing but the member's own inbox.
  Future<void> markRead(AppNotification notification) async {
    if (!notification.unread) return;
    await _repository.markRead([notification.id]);
    final current = state.value?.value;
    if (current != null) {
      final now = ref.read(nowProvider)();
      await show(
        Paged([
          for (final n in current.items)
            if (n.id == notification.id) n.read(now) else n,
        ], next: current.next),
      );
    }
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead(portfolioId);
    ref.invalidate(unreadCountProvider);
    await reload();
  }

  Future<void> delete(AppNotification notification) async {
    await _repository.delete(notification.id);
    ref.invalidate(unreadCountProvider);
    await reload();
  }
}
