import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The notification centre (REM-03): the member's notifications in this
/// portfolio, newest first, unread ones marked; opening one marks it read
/// and leads to what it is about; marking all read; deleting one.
class NotificationsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) {
      return MmPage(
        title: l10n.notificationsTitle,
        body: const SizedBox.shrink(),
      );
    }
    final provider = notificationsProvider(portfolio.id);
    final page = ref.watch(provider).value?.value;
    final unread = page?.items.any((n) => n.unread) ?? false;
    return MmPage(
      title: l10n.notificationsTitle,
      actions: [
        if (unread)
          IconButton(
            tooltip: l10n.markAllReadAction,
            icon: const Icon(MmIcons.check),
            onPressed: () async {
              try {
                await ref.read(provider.notifier).markAllRead();
              } on AppFailure catch (failure) {
                if (!context.mounted) return;
                await showMmSnackbar(
                  context,
                  message: failureMessage(l10n, failure),
                  tone: MmBannerTone.error,
                );
              }
            },
          ),
      ],
      body: SnapshotView(
        state: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        loadingLabel: l10n.loadingNotifications,
        failedTitle: l10n.notificationsLoadFailedTitle,
        builder: (page) => page.items.isEmpty
            ? MmEmptyState(
                icon: MmIcons.notificationsOff,
                title: l10n.notificationsEmptyTitle,
                message: l10n.notificationsEmptyBody,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListCard(
                    children: [
                      for (final notification in page.items)
                        _NotificationTile(
                          notification: notification,
                          portfolioId: portfolio.id,
                        ),
                    ],
                  ),
                  if (page.hasMore)
                    LoadMoreButton(
                      onLoad: () => ref.read(provider.notifier).loadMore(),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const new({required this.notification, required this.portfolioId});

  final AppNotification notification;
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final words = notificationWords(context, notification);
    return MmListTile(
      leading: Icon(notificationIcon(notification.kind)),
      title: words.title,
      subtitle: appText(
        detailLine([words.body, momentLabel(context, notification.created)]),
        Directionality.of(context),
      ),
      subtitleMaxLines: 6,
      trailing: notification.unread
          ? BelowText(
              child: MmStatusBadge(
                status: MmStatus.credit,
                icon: MmIcons.notifications,
                label: l10n.unreadLabel,
              ),
            )
          : null,
      onTap: () {
        final controller = ref.read(
          notificationsProvider(portfolioId).notifier,
        );
        unawaited(
          controller.markRead(notification).catchError((Object _) {
            // Opening it still works; it stays unread until the next try.
          }),
        );
        unawaited(
          showMmSheet<void>(
            context,
            title: words.title,
            builder: (_) => NotificationSheet(
              notification: notification,
              portfolioId: portfolioId,
            ),
          ),
        );
      },
    );
  }
}

/// One notification in full, with the way to what it is about and
/// deleting it.
class NotificationSheet extends ConsumerStatefulWidget {
  const new({required this.notification, required this.portfolioId, super.key});

  final AppNotification notification;
  final String portfolioId;

  @override
  ConsumerState<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<NotificationSheet>
    with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final done = await runCommand(
      () => ref
          .read(notificationsProvider(widget.portfolioId).notifier)
          .delete(widget.notification),
    );
    if (!done || !mounted) return;
    unawaited(showMmSnackbar(context, message: l10n.notificationDeleted));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notification = widget.notification;
    final words = notificationWords(context, notification);
    final route = notificationRoute(notification);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        Text(words.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: MmSpace.s2),
        Text(
          momentLabel(context, notification.created),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MmSpace.s4),
        if (route != null) ...[
          MmButton(
            label: l10n.openNotificationAction,
            icon: MmIcons.forward,
            onPressed: busy
                ? null
                : () {
                    Navigator.of(context).pop();
                    context.go(route);
                  },
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        MmButton(
          label: l10n.deleteAction,
          icon: MmIcons.delete,
          variant: MmButtonVariant.tertiary,
          busy: busy,
          onPressed: _delete,
        ),
      ],
    );
  }
}

/// Where a notification leads: the ledger for rent, the tenancy for its
/// agreement, increase and police registration, the tenant for a CNIC,
/// the team for an invitation, the bill for a utility bill; nowhere for
/// what the app cannot show yet.
String? notificationRoute(AppNotification notification) {
  final lease = notification.text('lease_id');
  final tenant = notification.text('tenant_id');
  final bill = notification.text('bill_id');
  return switch (notification.kind) {
    NotificationKind.rentDueSoon ||
    NotificationKind.rentOverdue when lease != null => Routes.ledger(lease),
    NotificationKind.leaseExpiring ||
    NotificationKind.incrementDue ||
    NotificationKind.policePending ||
    NotificationKind.policeOverdue when lease != null => Routes.lease(lease),
    NotificationKind.cnicExpiring when tenant != null => Routes.tenant(tenant),
    NotificationKind.invitationAccepted => Routes.team,
    NotificationKind.utilityBillDue when bill != null => Routes.utilityBill(
      bill,
    ),
    _ => null,
  };
}

/// The icon of a kind of notification.
IconData notificationIcon(NotificationKind kind) => switch (kind) {
  NotificationKind.rentDueSoon => MmIcons.dueDate,
  NotificationKind.rentOverdue => MmIcons.warning,
  NotificationKind.leaseExpiring => MmIcons.lease,
  NotificationKind.incrementDue => MmIcons.trendUp,
  NotificationKind.policePending ||
  NotificationKind.policeOverdue => MmIcons.police,
  NotificationKind.cnicExpiring => MmIcons.cnic,
  NotificationKind.utilityBillDue => MmIcons.utility,
  NotificationKind.invitationAccepted => MmIcons.invite,
  NotificationKind.unknown => MmIcons.notifications,
};

/// A notification's title and sentence in the app's language, from its
/// kind and the details the daily job stored with it. A detail that is
/// missing or malformed leaves the sentence general rather than failing.
({String title, String body}) notificationWords(
  BuildContext context,
  AppNotification notification,
) {
  final l10n = AppLocalizations.of(context);
  final money = MmFormats.moneyOf(context);
  final direction = Directionality.of(context);
  String name(String field) =>
      inSentence(notification.text(field) ?? '', direction);
  String date(String field) {
    final value = _date(notification.params[field]);
    return value == null ? '' : dateInLine(context, value);
  }

  String amount(String field) {
    final value = _money(notification.params[field]);
    return value == null ? '' : money.format(value);
  }

  final tenantUnit = l10n.unitAtProperty(
    name('tenant_name'),
    name('unit_label'),
  );
  final statutory = notification.params['statutory'] != false;
  return switch (notification.kind) {
    NotificationKind.rentDueSoon => (
      title: l10n.notificationRentDueSoon,
      body: l10n.notificationRentDueSoonBody(
        tenantUnit,
        amount('amount'),
        date('due_date'),
      ),
    ),
    NotificationKind.rentOverdue => (
      title: l10n.notificationRentOverdue,
      body: l10n.notificationRentOverdueBody(
        tenantUnit,
        amount('amount'),
        date('due_date'),
      ),
    ),
    NotificationKind.leaseExpiring => (
      title: l10n.notificationLeaseExpiring,
      body: l10n.notificationLeaseExpiringBody(tenantUnit, date('end_date')),
    ),
    NotificationKind.incrementDue => (
      title: l10n.notificationIncrementDue,
      body: l10n.notificationIncrementDueBody(
        tenantUnit,
        date('anniversary'),
        amount('current_rent'),
      ),
    ),
    NotificationKind.policePending => (
      title: l10n.notificationPolicePending,
      body: statutory
          ? l10n.notificationPolicePendingBody(tenantUnit, date('deadline'))
          : l10n.notificationPoliceReminderBody(tenantUnit, date('deadline')),
    ),
    NotificationKind.policeOverdue => (
      title: l10n.notificationPoliceOverdue,
      body: statutory
          ? l10n.notificationPoliceOverdueBody(tenantUnit, date('deadline'))
          : l10n.notificationPoliceReminderBody(tenantUnit, date('deadline')),
    ),
    NotificationKind.cnicExpiring => (
      title: l10n.notificationCnicExpiring,
      body: l10n.notificationCnicExpiringBody(
        name('tenant_name'),
        date('cnic_expiry'),
      ),
    ),
    NotificationKind.utilityBillDue => (
      title: l10n.notificationUtilityDue,
      body: l10n.notificationUtilityDueBody(
        name('property_name'),
        amount('amount'),
        date('due_date'),
      ),
    ),
    NotificationKind.invitationAccepted => (
      title: l10n.notificationInvitationAccepted,
      body: l10n.notificationInvitationAcceptedBody(
        breakableEmail(notification.text('email') ?? ''),
        _role(l10n, notification.text('role')),
      ),
    ),
    NotificationKind.unknown => (
      title: l10n.notificationUnknown,
      body: l10n.notificationUnknownBody,
    ),
  };
}

String _role(AppLocalizations l10n, String? role) {
  final known = MemberRole.values.asNameMap()[role];
  return known == null ? '' : roleLabel(l10n, known);
}

CalendarDate? _date(Object? value) =>
    value is String ? CalendarDate.tryParse(value) : null;

Money? _money(Object? value) {
  try {
    return Money.fromJson(value);
  } on FormatException {
    return null;
  }
}
