import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Opens the WhatsApp reminder composer for a tenancy, about [payment]
/// (a thank-you) when given.
Future<void> showReminderComposer(
  BuildContext context, {
  required String leaseId,
  Payment? payment,
}) => showMmSheet<void>(
  context,
  title: AppLocalizations.of(context).reminderTitle,
  builder: (_) => ReminderComposer(leaseId: leaseId, payment: payment),
);

/// The WhatsApp reminder composer (REM-01, REM-02): a template, the
/// tenant's language (English, Urdu or Roman Urdu), the message to read
/// and change, and a word of etiquette when now is late at night, the
/// Friday prayer, or soon after the last reminder. Sending opens WhatsApp
/// on the landlord's phone with the message ready for the tenant's
/// number, and logs the reminder.
class ReminderComposer extends ConsumerStatefulWidget {
  const new({required this.leaseId, this.payment, super.key});

  final String leaseId;
  final Payment? payment;

  @override
  ConsumerState<ReminderComposer> createState() => _ReminderComposerState();
}

class _ReminderComposerState extends ConsumerState<ReminderComposer>
    with CommandState {
  /// The id of the log entry, kept for retries.
  final String _attempt = newUuid();
  ReminderTemplate? _template;
  ReminderLanguage? _language;
  final _message = TextEditingController();

  /// The text last written from a template; a message changed by hand is
  /// not replaced.
  String? _written;

  /// Whether WhatsApp opened with the message: a retry after the log
  /// failed only notes the reminder, without opening WhatsApp again.
  bool _opened = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  ReminderFacts _facts(
    TenancyLedger ledger,
    ReminderTemplate template,
    CalendarDate today,
  ) {
    final lease = ledger.lease;
    final portfolio = ref.read(currentPortfolioProvider).value;
    final details = portfolio == null
        ? null
        : ref.read(portfolioDetailsProvider(portfolio.id)).value?.value;
    final open = ledger.openCharges;
    final utilities = [
      for (final c in open)
        if (_utilityKinds.contains(c.kind)) c,
    ];
    final upcoming = [
      for (final c in open)
        if (!c.dueDate.isBefore(today)) c,
    ];
    final dueToday = [
      for (final c in open)
        if (c.dueDate == today) c,
    ];
    final payment = widget.payment;
    final (amount, date, utility) = switch (template) {
      ReminderTemplate.paymentReceived when payment != null => (
        payment.amount,
        payment.paidOn,
        null,
      ),
      ReminderTemplate.utilityBill when utilities.isNotEmpty => (
        utilities.first.outstanding,
        utilities.first.dueDate,
        utilities.first.kind,
      ),
      ReminderTemplate.dueToday when dueToday.isNotEmpty => (
        Money.sum([for (final c in dueToday) c.outstanding]),
        today,
        null,
      ),
      ReminderTemplate.upcoming when upcoming.isNotEmpty => (
        Money.sum([
          for (final c in upcoming)
            if (c.dueDate == upcoming.first.dueDate) c.outstanding,
        ]),
        upcoming.first.dueDate,
        null,
      ),
      ReminderTemplate.overdue || ReminderTemplate.utilityBill => (
        ledger.balance.overdue.isPositive
            ? ledger.balance.overdue
            : ledger.balance.outstanding,
        ledger.balance.oldestOverdueDueDate ?? today,
        null,
      ),
      _ => (
        ledger.balance.outstanding.isPositive
            ? ledger.balance.outstanding
            : lease.terms.monthlyRent,
        open.isEmpty ? today : open.first.dueDate,
        null,
      ),
    };
    return ReminderFacts(
      tenantName: lease.tenantName,
      unitLabel: lease.unitLabel,
      propertyName: lease.propertyName,
      amount: amount,
      date: date,
      utility: utility,
      receiptNumber: payment?.receiptNumber,
      landlordName: details?.landlordName ?? portfolio?.name ?? '',
      raastId: details?.raastId,
      bankAccountTitle: details?.bankAccountTitle,
      bankIban: details?.bankIban,
    );
  }

  static const Set<ChargeKind> _utilityKinds = {
    ChargeKind.electricity,
    ChargeKind.gas,
    ChargeKind.water,
    ChargeKind.internet,
  };

  ReminderTemplate _suggested(TenancyLedger ledger, CalendarDate today) {
    final open = ledger.openCharges;
    return suggestedTemplate(
      today: today,
      dueDate: open.isEmpty ? null : open.first.dueDate,
      justPaid: widget.payment != null,
      utilityOnly:
          open.isNotEmpty && open.every((c) => _utilityKinds.contains(c.kind)),
    );
  }

  void _write(TenancyLedger ledger, ReminderTemplate template) {
    final language = _language!;
    final today = dates.today(context);
    final text = reminderMessage(
      template: template,
      language: language,
      facts: _facts(ledger, template, today),
      grouping: MmFormats.moneyOf(context).grouping,
    );
    if (_written == null || _message.text == _written) {
      _message.text = text;
    }
    _written = text;
  }

  Future<void> _send(TenancyLedger ledger, PhoneNumber? phone) async {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.read(currentPortfolioProvider).value;
    final message = _message.text.trim();
    if (portfolio == null || message.isEmpty) return;
    if (!_opened) {
      final opened = await ref.read(linkOpenerProvider)(
        whatsAppLink(message, phoneDigits: phone?.digits),
      );
      if (!mounted) return;
      if (!opened) {
        await showMmSnackbar(
          context,
          message: l10n.linkNotOpened,
          tone: MmBannerTone.error,
        );
        return;
      }
      setState(() => _opened = true);
    }
    final done = await runCommand(
      () => ref
          .read(remindersProvider(widget.leaseId).notifier)
          .log(
            id: _attempt,
            portfolioId: portfolio.id,
            template: _template!,
            language: _language!,
            message: message,
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.reminderLogged,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerState = ref.watch(tenancyLedgerProvider(widget.leaseId));
    final ledger = ledgerState.value?.value;
    final reminders = ref.watch(remindersProvider(widget.leaseId));
    if (ledger == null) {
      return Semantics(
        label: l10n.loadingLedger,
        child: const MmSkeleton.text(lines: 6),
      );
    }
    final tenant = ref
        .watch(tenantProvider(ledger.lease.tenantId))
        .value
        ?.value;
    final today = dates.today(context);
    final template = _template ??= _suggested(ledger, today);
    final language = _language ??=
        Localizations.localeOf(context).languageCode == 'ur'
        ? ReminderLanguage.urdu
        : ReminderLanguage.english;
    if (_written == null) _write(ledger, template);
    final logs = reminders.value?.value ?? const <ReminderLog>[];
    final concerns = Etiquette.concerns(
      now: ref.read(nowProvider)(),
      lastSentAt: logs.isEmpty ? null : logs.first.sentAt,
    );
    final phone = tenant?.phone;
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        for (final concern in concerns) ...[
          MmBanner(
            tone: MmBannerTone.warning,
            icon: MmIcons.clock,
            message: _concern(context, concern),
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        MmSelectField<ReminderTemplate>(
          label: l10n.reminderTemplateLabel,
          required: true,
          options: [
            for (final value in ReminderTemplate.values)
              if (value != ReminderTemplate.paymentReceived ||
                  widget.payment != null)
                MmOption(value: value, label: templateLabel(l10n, value)),
          ],
          value: template,
          onChanged: (value) => setState(() {
            _template = value;
            _write(ledger, value);
          }),
        ),
        const SizedBox(height: MmSpace.s4),
        MmRadioGroup<ReminderLanguage>(
          label: l10n.reminderLanguageLabel,
          options: [
            for (final value in ReminderLanguage.values)
              MmOption(value: value, label: reminderLanguageLabel(l10n, value)),
          ],
          value: language,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _language = value;
              _write(ledger, template);
            });
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.reminderMessageLabel,
          controller: _message,
          minLines: 6,
          maxLines: 14,
          maxLength: ReminderLog.maxPreviewLength,
          inputFormatters: codePointLimit(ReminderLog.maxPreviewLength),
        ),
        const SizedBox(height: MmSpace.s3),
        Text(
          phone == null
              ? l10n.reminderNoPhone
              : l10n.reminderTo(
                  inSentence(
                    ledger.lease.tenantName,
                    Directionality.of(context),
                  ),
                  phoneLabel(phone, Directionality.of(context)),
                ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: _opened
              ? l10n.noteReminderAction
              : concerns.isEmpty
              ? l10n.sendOnWhatsAppAction
              : l10n.sendAnywayAction,
          icon: _opened ? MmIcons.check : MmIcons.send,
          busy: busy,
          onPressed: () => _send(ledger, phone),
        ),
        const SizedBox(height: MmSpace.s3),
        MmButton(
          label: l10n.copyMessageAction,
          icon: MmIcons.copy,
          variant: MmButtonVariant.tertiary,
          onPressed: () async {
            await copyText(_message.text);
            if (context.mounted) {
              await showMmSnackbar(context, message: l10n.messageCopied);
            }
          },
        ),
      ],
    );
  }

  String _concern(BuildContext context, EtiquetteConcern concern) {
    final l10n = AppLocalizations.of(context);
    return switch (concern) {
      LateNight(:final until) => l10n.etiquetteLateNight(
        timeLabel(context, until),
      ),
      FridayPrayers(:final until) => l10n.etiquetteFridayPrayer(
        timeLabel(context, until),
      ),
      RecentlyReminded(:final at) => l10n.etiquetteRecent(
        momentLabel(context, at),
      ),
    };
  }
}

/// The name of a reminder template.
String templateLabel(AppLocalizations l10n, ReminderTemplate template) =>
    switch (template) {
      ReminderTemplate.upcoming => l10n.templateUpcoming,
      ReminderTemplate.dueToday => l10n.templateDueToday,
      ReminderTemplate.overdue => l10n.templateOverdue,
      ReminderTemplate.paymentReceived => l10n.templatePaymentReceived,
      ReminderTemplate.utilityBill => l10n.templateUtilityBill,
    };

/// The name of a reminder's language, in that language.
String reminderLanguageLabel(
  AppLocalizations l10n,
  ReminderLanguage language,
) => switch (language) {
  ReminderLanguage.english => l10n.languageEnglish,
  ReminderLanguage.urdu => l10n.languageUrdu,
  ReminderLanguage.romanUrdu => l10n.languageRomanUrdu,
};

/// A tenancy's latest reminders: which, in which language and when.
class ReminderHistory extends ConsumerWidget {
  const new({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = remindersProvider(leaseId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.remindersSection),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingReminders,
          failedTitle: l10n.remindersLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 2),
          builder: (logs) => logs.isEmpty
              ? Text(
                  l10n.noRemindersYet,
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              : ListCard(
                  children: [
                    for (final log in logs)
                      MmListTile(
                        leading: const Icon(MmIcons.reminder),
                        title: templateLabel(l10n, log.template),
                        subtitle: detailLine([
                          momentLabel(context, log.sentAt),
                          reminderLanguageLabel(l10n, log.language),
                        ]),
                        subtitleMaxLines: 4,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
