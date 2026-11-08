import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/charge_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Cash in hand (LEDGER-11): how much cash each member collected, handed
/// on and holds, and the handovers, newest first. Members who handle money
/// record handing cash on; the owner confirms receiving it, or voids a
/// handover recorded by mistake.
class CashBookScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) {
      return MmPage(title: l10n.cashBookTitle, body: const SizedBox.shrink());
    }
    final provider = cashBookProvider(portfolio.id);
    final records = portfolio.role.recordsMoney;
    final book = ref.watch(provider).value?.value;
    return MmPage(
      title: l10n.cashBookTitle,
      body: SnapshotView(
        state: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        loadingLabel: l10n.loadingCashBook,
        failedTitle: l10n.cashBookLoadFailedTitle,
        builder: (book) => _Book(book: book, portfolio: portfolio),
      ),
      bottomBar: records && book != null
          ? MmActionBar(
              primary: MmButton(
                label: l10n.recordHandoverAction,
                icon: MmIcons.transfer,
                onPressed: () => showMmSheet<void>(
                  context,
                  title: l10n.recordHandoverAction,
                  builder: (_) =>
                      HandoverSheet(portfolio: portfolio, book: book),
                ),
              ),
            )
          : null,
    );
  }
}

class _Book extends ConsumerWidget {
  const new({required this.book, required this.portfolio});

  final CashBook book;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final holding = [
      for (final p in book.positions)
        if (!p.collected.isZero || !p.handedOver.isZero) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.cashInHandSection,
          subtitle: l10n.cashInHandHelp,
        ),
        const SizedBox(height: MmSpace.s2),
        if (holding.isEmpty)
          Text(l10n.noCashYet, style: Theme.of(context).textTheme.bodyLarge)
        else
          for (final (index, position) in holding.indexed) ...[
            if (index > 0) const SizedBox(height: MmSpace.s3),
            _Position(position: position),
          ],
        const SizedBox(height: MmSpace.s6),
        MmSectionHeader(title: l10n.handoversSection),
        const SizedBox(height: MmSpace.s2),
        if (book.handovers.items.isEmpty)
          Text(
            l10n.noHandoversYet,
            style: Theme.of(context).textTheme.bodyLarge,
          )
        else
          ListCard(
            children: [
              for (final handover in book.handovers.items)
                _HandoverTile(
                  handover: handover,
                  book: book,
                  portfolio: portfolio,
                ),
            ],
          ),
        if (book.handovers.hasMore)
          LoadMoreButton(
            onLoad: () =>
                ref.read(cashBookProvider(portfolio.id).notifier).loadMore(),
          ),
      ],
    );
  }
}

String _name(AppLocalizations l10n, String? name) =>
    name == null || name.isEmpty ? l10n.formerMember : name;

/// One member's cash: who, in which role, and what they collected, handed
/// on and spent, each on its own line, down to what they hold now.
class _Position extends StatelessWidget {
  const new({required this.position});

  final CashPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _name(l10n, position.fullName);
    return MmCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmListTile(
            leading: MmAvatar(name: name),
            title: name,
            subtitle: roleLabel(l10n, position.role),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MmSpace.s4,
              0,
              MmSpace.s4,
              MmSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MmDetailRow.amount(
                  label: l10n.cashCollectedLabel,
                  amount: position.collected,
                ),
                MmDetailRow.amount(
                  label: l10n.cashHandedOverLabel,
                  amount: position.handedOver,
                ),
                if (position.spent.isPositive)
                  MmDetailRow.amount(
                    label: l10n.cashSpentLabel,
                    amount: position.spent,
                  ),
                MmDetailRow.amount(
                  label: l10n.cashInHandLabel,
                  amount: position.inHand,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverTile extends StatelessWidget {
  const new({
    required this.handover,
    required this.book,
    required this.portfolio,
  });

  final CashHandover handover;
  final CashBook book;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final from = _name(l10n, book.nameOf(handover.fromUserId));
    final to = _name(l10n, book.nameOf(handover.toUserId));
    final approves = portfolio.role.approvesMoney && !handover.voided;
    final direction = Directionality.of(context);
    return MmListTile(
      leading: Icon(methodIcon(handover.method)),
      title: l10n.handoverFromTo(
        inSentence(from, direction),
        inSentence(to, direction),
      ),
      subtitle: detailLine([
        money.format(handover.amount),
        dateInLine(context, handover.handedOverOn),
        l10n.paymentMethod(handover.method),
        if (handover.reference case final reference?)
          inSentence(reference, direction),
      ]),
      subtitleMaxLines: 4,
      // The app's sentences, the members' names isolated inside.
      userData: false,
      trailing: BelowText(
        child: handover.voided
            ? MmStatusBadge(
                status: MmStatus.neutral,
                icon: MmIcons.close,
                label: l10n.chargeVoided,
              )
            : handover.confirmed
            ? MmStatusBadge(
                status: MmStatus.paid,
                label: l10n.handoverConfirmed,
              )
            : MmStatusBadge(
                status: MmStatus.dueSoon,
                icon: MmIcons.clock,
                label: l10n.handoverAwaiting,
              ),
      ),
      onTap: approves
          ? () => showMmSheet<void>(
              context,
              title: l10n.handoverTitle,
              builder: (_) => HandoverActions(
                portfolioId: portfolio.id,
                handover: handover,
              ),
            )
          : null,
    );
  }
}

/// The owner's choices for a handover: confirm receiving the cash, or void
/// it with a reason.
class HandoverActions extends ConsumerStatefulWidget {
  const new({required this.portfolioId, required this.handover, super.key});

  final String portfolioId;
  final CashHandover handover;

  @override
  ConsumerState<HandoverActions> createState() => _HandoverActionsState();
}

class _HandoverActionsState extends ConsumerState<HandoverActions>
    with CommandState {
  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final done = await runCommand(
      () => ref
          .read(cashBookProvider(widget.portfolioId).notifier)
          .confirm(widget.handover.id),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.handoverConfirmedDone,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handover = widget.handover;
    final failure = this.failure;
    final controller = ref.read(cashBookProvider(widget.portfolioId).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmDetailRow.amount(label: l10n.amountLabel, amount: handover.amount),
        MmDetailRow(
          label: l10n.handedOverOnLabel,
          value: dateLabel(context, handover.handedOverOn),
          userData: false,
        ),
        if (handover.notes case final notes?)
          MmDetailRow(label: l10n.notesLabel, value: notes),
        const SizedBox(height: MmSpace.s4),
        if (!handover.confirmed) ...[
          MmButton(
            label: l10n.confirmHandoverAction,
            icon: MmIcons.check,
            busy: busy,
            onPressed: _confirm,
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        MmButton(
          label: l10n.voidHandoverAction,
          icon: MmIcons.close,
          // It asks first (or opens the flow that does): the filled red
          // button is at the point of no return.
          variant: MmButtonVariant.destructiveOutlined,
          onPressed: busy
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(
                    showMmSheet<void>(
                      context,
                      title: l10n.voidHandoverAction,
                      builder: (_) => ReasonSheet(
                        explanation: l10n.voidHandoverExplain,
                        confirmLabel: l10n.voidHandoverAction,
                        doneMessage: l10n.handoverVoided,
                        onReason: (reason, _) =>
                            controller.voidHandover(handover.id, reason),
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }
}

/// Recording cash handed from one member to another (by default, from the
/// one recording it to the owner). Only an owner records a handover given
/// by someone else. One id per sheet, kept for retries.
class HandoverSheet extends ConsumerStatefulWidget {
  const new({required this.portfolio, required this.book, super.key});

  final PortfolioMembership portfolio;
  final CashBook book;

  @override
  ConsumerState<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends ConsumerState<HandoverSheet>
    with CommandState {
  final String _attempt = newUuid();
  late String? _from = ref.read(currentUserIdProvider);
  late String? _to = _defaultReceiver();
  Money? _amount;
  late CalendarDate _on = dates.today(context);
  PaymentMethod _method = PaymentMethod.cash;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _defaultReceiver() {
    final me = ref.read(currentUserIdProvider);
    for (final position in widget.book.positions) {
      if (position.role == MemberRole.owner && position.userId != me) {
        return position.userId;
      }
    }
    return null;
  }

  Future<void> _record() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    final from = _from;
    final to = _to;
    if (amount == null || from == null || to == null || from == to) return;
    final done = await runCommand(
      () => ref
          .read(cashBookProvider(widget.portfolio.id).notifier)
          .record(
            _attempt,
            HandoverDraft(
              fromUserId: from,
              toUserId: to,
              amount: amount,
              handedOverOn: _on,
              method: _method,
              reference: _reference.text,
              notes: _notes.text,
            ),
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.handoverRecorded,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final owner = widget.portfolio.role == MemberRole.owner;
    final me = ref.watch(currentUserIdProvider);
    final today = dates.today(context);
    final members = [
      for (final p in widget.book.positions)
        MmOption(value: p.userId, label: _name(l10n, p.fullName)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (owner)
          MmSelectField<String>(
            label: l10n.handoverFromLabel,
            required: true,
            options: members,
            value: _from,
            onChanged: (id) => setState(() => _from = id),
          )
        else
          MmDetailRow(
            label: l10n.handoverFromLabel,
            value: _name(l10n, widget.book.nameOf(me)),
          ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<String>(
          label: l10n.handoverToLabel,
          required: true,
          options: [
            for (final option in members)
              if (option.value != _from) option,
          ],
          value: _to == _from ? null : _to,
          errorText: _tried && (_to == null || _to == _from)
              ? l10n.handoverChooseReceiver
              : null,
          onChanged: (id) => setState(() => _to = id),
        ),
        const SizedBox(height: MmSpace.s4),
        MmMoneyField(
          label: l10n.amountLabel,
          value: _amount,
          required: true,
          allowZero: false,
          invalidText: l10n.validationAmount,
          errorText: _tried && _amount == null ? l10n.validationAmount : null,
          onChanged: (amount) => setState(() => _amount = amount),
        ),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.handedOverOnLabel,
          value: _on,
          required: true,
          firstDate: today.addYears(-2),
          lastDate: today,
          onChanged: (date) {
            if (date != null) setState(() => _on = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<PaymentMethod>(
          label: l10n.methodLabel,
          required: true,
          options: [
            for (final method in PaymentMethod.received)
              MmOption(value: method, label: l10n.paymentMethod(method)),
          ],
          value: _method,
          onChanged: (method) => setState(() => _method = method),
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.paymentReferenceLabel,
          controller: _reference,
          optional: true,
          maxLength: Payment.maxReferenceLength,
          inputFormatters: codePointLimit(Payment.maxReferenceLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.notesLabel,
          controller: _notes,
          optional: true,
          maxLength: Payment.maxNotesLength,
          inputFormatters: codePointLimit(Payment.maxNotesLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.recordHandoverAction,
          busy: busy,
          onPressed: _record,
        ),
      ],
    );
  }
}
