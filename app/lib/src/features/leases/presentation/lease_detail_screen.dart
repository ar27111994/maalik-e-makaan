import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// One tenancy: who rents what, its terms and agreement, its police
/// registration and deadline (the law's, or the app's reminder where no
/// law sets one), the people living there, the rent history, content from
/// later features ([LeaseDetailScreen.extras]: its documents), and for the
/// roles that may, changing the rent, ending the tenancy and deleting it.
class LeaseDetailScreen extends ConsumerWidget {
  const new({required this.leaseId, this.extras, super.key});

  final String leaseId;

  /// Content from later features (the tenancy's documents).
  final Widget Function(LeaseDetail detail)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(leaseProvider(leaseId));
    final detail = state.value?.value;
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final runs = role?.runsProperties ?? false;
    final active = detail?.lease.active ?? false;
    final extras = this.extras;
    return MmPage(
      title: detail?.lease.tenantName ?? l10n.tenancyTitle,
      actions: [
        if (runs && active)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editLease(leaseId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(leaseProvider(leaseId)),
        loadingLabel: l10n.loadingTenancy,
        failedTitle: l10n.tenancyLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 10),
        builder: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Summary(lease: detail.lease),
            const SizedBox(height: MmSpace.s6),
            _Police(lease: detail.lease),
            const SizedBox(height: MmSpace.s6),
            _Terms(lease: detail.lease),
            const SizedBox(height: MmSpace.s6),
            _RentHistory(detail: detail, editable: runs && active),
            const SizedBox(height: MmSpace.s6),
            _Occupants(detail: detail, editable: runs && active),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(detail),
            ],
            if (role != null && runs) ...[
              const SizedBox(height: MmSpace.s8),
              _LeaseActions(lease: detail.lease, role: role),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const new({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: leaseBadge(context, lease),
              ),
              const SizedBox(height: MmSpace.s3),
              MmDetailRow.amount(
                label: l10n.monthlyRentLabel,
                amount: lease.terms.monthlyRent,
                emphasized: true,
              ),
              if (lease.movedOutOn case final movedOut?) ...[
                MmDetailRow(
                  label: l10n.endedOnLabel,
                  value: dateLabel(context, movedOut),
                  userData: false,
                ),
                if (lease.endReason case final reason?)
                  MmDetailRow(
                    label: l10n.changeReasonLabel,
                    value: l10n.endReason(reason),
                    userData: false,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: MmSpace.s3),
        // Rows that open the tenant and the unit: list rows, whose chevron
        // stays beside the name, not detail rows, whose button would move
        // under a long value.
        ListCard(
          children: [
            MmListTile(
              leading: const Icon(MmIcons.person),
              title: lease.tenantName,
              subtitle: l10n.tenantLabel,
              chevron: true,
              onTap: () => context.go(Routes.tenant(lease.tenantId)),
            ),
            MmListTile(
              leading: const Icon(MmIcons.unit),
              title: lease.unitLabel,
              subtitle: l10n.listDetail(
                l10n.unitLabel,
                inSentence(lease.propertyName, Directionality.of(context)),
              ),
              chevron: true,
              onTap: () =>
                  context.go(Routes.unit(lease.propertyId, lease.unitId)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Police extends ConsumerWidget {
  const new({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final terms = lease.terms;
    final rule = lease.province.policeRule;
    final deadline = dateLabel(context, lease.policeDeadline);
    final open =
        lease.active &&
        (terms.policeStatus == PoliceStatus.pending ||
            terms.policeStatus == PoliceStatus.submitted);
    final late =
        open &&
        terms.policeStatus == PoliceStatus.pending &&
        lease.policeDeadline.isBefore(dates.today(context));
    final portal = policePortal(lease.province);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.leaseSectionPolice),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.policeStatusLabel,
                value: l10n.policeStatus(terms.policeStatus),
                userData: false,
              ),
              if (terms.policeChannel case final channel?)
                MmDetailRow(
                  label: l10n.policeChannelLabel,
                  value: l10n.policeChannel(channel),
                  userData: false,
                ),
              if (terms.policeStation case final station?)
                MmDetailRow(label: l10n.policeStationLabel, value: station),
              if (terms.policeReference case final reference?)
                MmDetailRow(label: l10n.policeReferenceLabel, value: reference),
              if (terms.policeRegisteredOn case final date?)
                MmDetailRow(
                  label: l10n.registeredOnLabel,
                  value: dateLabel(context, date),
                  userData: false,
                ),
              if (terms.policeFee case final fee?)
                MmDetailRow.amount(label: l10n.policeFeeLabel, amount: fee),
            ],
          ),
        ),
        if (open) ...[
          const SizedBox(height: MmSpace.s3),
          MmBanner(
            tone: late
                ? MmBannerTone.error
                : rule.statutory
                ? MmBannerTone.warning
                : MmBannerTone.info,
            icon: MmIcons.police,
            title: rule.statutory
                ? l10n.policeLegalDeadline(deadline)
                : l10n.policeReminderDate(deadline),
            message: [
              l10n.policeHint(lease.province),
              if (!rule.statutory) l10n.policeReminderNote,
              if (late) l10n.policeLate,
            ].join(' '),
            actionLabel: portal == null ? null : l10n.openPortalAction,
            onAction: portal == null
                ? null
                : () async {
                    final opened = await ref.read(linkOpenerProvider)(portal);
                    if (!opened && context.mounted) {
                      await showMmSnackbar(
                        context,
                        message: l10n.linkNotOpened,
                        tone: MmBannerTone.error,
                      );
                    }
                  },
          ),
        ],
      ],
    );
  }
}

class _Terms extends StatelessWidget {
  const new({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final terms = lease.terms;
    final money = MmFormats.moneyOf(context);
    String date(CalendarDate value) => dateLabel(context, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.tenancyTermsSection),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.moveInLabel,
                value: date(terms.startDate),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.endsOnLabel,
                value: terms.endDate == null
                    ? l10n.periodicValue
                    : date(terms.endDate!),
                userData: false,
              ),
              if (terms.billingStartsOn != terms.startDate)
                MmDetailRow(
                  label: l10n.billingStartsLabel,
                  value: date(terms.billingStartsOn),
                  userData: false,
                ),
              MmDetailRow(
                label: l10n.dueDayLabel,
                value: l10n.dueDayValue(terms.rentDueDay),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.graceDaysLabel,
                value: l10n.dayCount(terms.graceDays),
                userData: false,
              ),
              MmDetailRow.amount(
                label: l10n.depositLabel,
                amount: terms.securityDeposit,
              ),
              MmDetailRow(
                label: l10n.incrementLabel,
                value: l10n.everyMonths(
                  percentFromBasisPoints(terms.incrementBasisPoints),
                  terms.incrementIntervalMonths,
                ),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.lateFeeLabel,
                value: l10n.lateFee(terms.lateFee, money),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.noticeDaysLabel,
                value: l10n.dayCount(terms.noticePeriodDays),
                userData: false,
              ),
              if (terms.agreementSignedOn case final signed?)
                MmDetailRow(
                  label: l10n.agreementSignedLabel,
                  value: date(signed),
                  userData: false,
                ),
              if (terms.eStampNumber case final stamp?)
                MmDetailRow(label: l10n.eStampNumberLabel, value: stamp),
              if (terms.eStampAmount case final amount?)
                MmDetailRow.amount(
                  label: l10n.eStampAmountLabel,
                  amount: amount,
                ),
              MmDetailRow(
                label: l10n.registrarStatusLabel,
                value: l10n.registrarStatus(terms.registrarStatus),
                userData: false,
              ),
              if (terms.registrationNumber case final number?)
                MmDetailRow(label: l10n.registrationNumberLabel, value: number),
              if (terms.permittedUse case final use?)
                MmDetailRow(label: l10n.permittedUseLabel, value: use),
              if (terms.sublettingAllowed)
                MmDetailRow(
                  label: l10n.sublettingLabel,
                  value: l10n.sublettingLabel,
                  userData: false,
                ),
              if (terms.utilitiesNote case final note?)
                MmDetailRow(label: l10n.utilitiesNoteLabel, value: note),
              if (terms.notes case final notes?)
                MmDetailRow(label: l10n.notesLabel, value: notes),
            ],
          ),
        ),
      ],
    );
  }
}

class _RentHistory extends StatelessWidget {
  const new({required this.detail, required this.editable});

  final LeaseDetail detail;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.rentHistorySection,
          actionLabel: editable ? l10n.changeRentAction : null,
          onAction: editable
              ? () => showMmSheet<void>(
                  context,
                  title: l10n.changeRentAction,
                  builder: (_) => ChangeRentSheet(lease: detail.lease),
                )
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        ListCard(
          children: [
            for (final change in detail.rentChanges)
              MmListTile(
                leading: const Icon(MmIcons.history),
                title: money.format(change.monthlyRent),
                subtitle: l10n.listDetail(
                  l10n.rentFrom(monthLabel(context, change.effectiveFrom)),
                  l10n.rentReason(change.reason),
                ),
                subtitleMaxLines: 4,
              ),
          ],
        ),
      ],
    );
  }
}

class _Occupants extends StatelessWidget {
  const new({required this.detail, required this.editable});

  final LeaseDetail detail;
  final bool editable;

  Future<void> _open(BuildContext context, Occupant? occupant) =>
      showMmSheet<void>(
        context,
        title: AppLocalizations.of(context).occupantTitle,
        builder: (_) =>
            OccupantSheet(leaseId: detail.lease.id, occupant: occupant),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.occupantsSection,
          subtitle: l10n.occupantsHelp,
          actionLabel: editable ? l10n.addOccupantAction : null,
          onAction: editable ? () => _open(context, null) : null,
        ),
        const SizedBox(height: MmSpace.s2),
        if (detail.occupants.isEmpty)
          Text(l10n.noOccupants, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final occupant in detail.occupants)
                MmListTile(
                  leading: MmAvatar(name: occupant.fullName),
                  title: occupant.fullName,
                  subtitle: detailLine([
                    ?occupant.relation,
                    if (occupant.phone case final phone?)
                      phoneLabel(phone, Directionality.of(context)),
                  ]),
                  chevron: editable,
                  onTap: editable ? () => _open(context, occupant) : null,
                ),
            ],
          ),
      ],
    );
  }
}

/// Changing the rent from a month (LEASE-06): the agreed increase is
/// suggested, rounded to Rs 100.
class ChangeRentSheet extends ConsumerStatefulWidget {
  const new({required this.lease, super.key});

  final Lease lease;

  @override
  ConsumerState<ChangeRentSheet> createState() => _ChangeRentSheetState();
}

class _ChangeRentSheetState extends ConsumerState<ChangeRentSheet>
    with CommandState {
  late MonthPeriod _from = MonthPeriod.of(dates.today(context)).next;
  Money? _rent;
  RentChangeReason _reason = RentChangeReason.annualIncrement;
  final _note = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Money get _suggestion => RentMath.incrementedRent(
    widget.lease.terms.monthlyRent,
    basisPoints: widget.lease.terms.incrementBasisPoints,
  );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final rent = _rent;
    if (rent == null || !rent.isPositive) return;
    final done = await runCommand(
      () => ref
          .read(leaseProvider(widget.lease.id).notifier)
          .changeRent(
            from: _from,
            rent: rent,
            reason: _reason,
            note: _note.text,
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.rentChanged(
          MmFormats.moneyOf(context).format(rent),
          monthLabel(context, _from),
        ),
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final failure = this.failure;
    final first = MonthPeriod.of(widget.lease.terms.billingStartsOn);
    final today = MonthPeriod.of(dates.today(context));
    final months = [
      for (
        var month = first.compareTo(today.addMonths(-12)) > 0
            ? first
            : today.addMonths(-12);
        month.compareTo(today.addMonths(12)) <= 0;
        month = month.next
      )
        month,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        Text(l10n.changeRentHelp, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<MonthPeriod>(
          label: l10n.changeRentFromLabel,
          required: true,
          options: [
            for (final month in months)
              MmOption(value: month, label: monthLabel(context, month)),
          ],
          value: months.contains(_from) ? _from : months.last,
          onChanged: (month) => setState(() => _from = month),
        ),
        const SizedBox(height: MmSpace.s4),
        MmMoneyField(
          key: ValueKey(_rent == _suggestion),
          label: l10n.newRentLabel,
          value: _rent,
          required: true,
          allowZero: false,
          invalidText: l10n.validationAmount,
          errorText: _tried && _rent == null ? l10n.validationRent : null,
          helper: l10n.suggestedIncrement(
            percentFromBasisPoints(widget.lease.terms.incrementBasisPoints),
            money.format(_suggestion),
          ),
          onChanged: (amount) => setState(() => _rent = amount),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MmButton(
            label: l10n.useSuggestionAction,
            variant: MmButtonVariant.tertiary,
            onPressed: () => setState(() => _rent = _suggestion),
          ),
        ),
        const SizedBox(height: MmSpace.s2),
        MmRadioGroup<RentChangeReason>(
          label: l10n.changeReasonLabel,
          options: [
            for (final reason in RentChangeReason.values.skip(1))
              MmOption(value: reason, label: l10n.rentReason(reason)),
          ],
          value: _reason,
          onChanged: (reason) {
            if (reason != null) setState(() => _reason = reason);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.rentNoteLabel,
          controller: _note,
          optional: true,
          maxLength: RentChange.maxNoteLength,
          inputFormatters: codePointLimit(RentChange.maxNoteLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(label: l10n.changeRentAction, busy: busy, onPressed: _save),
      ],
    );
  }
}

/// Adding, editing or removing a person living with the tenant (LEASE-05).
class OccupantSheet extends ConsumerStatefulWidget {
  const new({required this.leaseId, this.occupant, super.key});

  final String leaseId;
  final Occupant? occupant;

  @override
  ConsumerState<OccupantSheet> createState() => _OccupantSheetState();
}

class _OccupantSheetState extends ConsumerState<OccupantSheet>
    with CommandState {
  final _form = GlobalKey<FormState>();
  final String _attempt = newUuid();
  late final _name = TextEditingController(text: widget.occupant?.fullName);
  late final _relation = TextEditingController(text: widget.occupant?.relation);
  late Cnic? _cnic = widget.occupant?.cnic;
  late PhoneNumber? _phone = widget.occupant?.phone;

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    super.dispose();
  }

  LeaseController get _lease =>
      ref.read(leaseProvider(widget.leaseId).notifier);

  Future<void> _save(String portfolioId) async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final occupant = Occupant(
      id: widget.occupant?.id ?? _attempt,
      fullName: _name.text,
      relation: _relation.text,
      cnic: _cnic,
      phone: _phone,
    );
    final done = await runCommand(
      () => widget.occupant == null
          ? _lease.addOccupant(portfolioId, occupant)
          : _lease.saveOccupant(occupant),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.occupantSaved(
          inSentence(
            sanitizeSingleLine(occupant.fullName),
            Directionality.of(context),
          ),
        ),
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _remove(Occupant occupant) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.removeOccupantTitle(
        inSentence(occupant.fullName, Directionality.of(context)),
      ),
      message: l10n.removeOccupantBody,
      confirmLabel: l10n.removeAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(() => _lease.removeOccupant(occupant.id));
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final failure = this.failure;
    final occupant = widget.occupant;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          MmTextField(
            label: l10n.fullNameTenantLabel,
            controller: _name,
            required: true,
            maxLength: Occupant.maxNameLength,
            inputFormatters: codePointLimit(Occupant.maxNameLength),
            validator: (value) =>
                Validators.name(l10n, value, maxLength: Occupant.maxNameLength),
          ),
          const SizedBox(height: MmSpace.s4),
          MmTextField(
            label: l10n.contactRelationLabel,
            controller: _relation,
            optional: true,
            maxLength: Occupant.maxRelationLength,
            inputFormatters: codePointLimit(Occupant.maxRelationLength),
          ),
          const SizedBox(height: MmSpace.s4),
          MmCnicField(
            label: l10n.cnicLabel,
            value: _cnic,
            optional: true,
            invalidText: l10n.validationCnic,
            onChanged: (cnic) => setState(() => _cnic = cnic),
          ),
          const SizedBox(height: MmSpace.s4),
          MmPhoneField(
            label: l10n.phoneLabel,
            value: _phone,
            optional: true,
            invalidText: l10n.validationPhone,
            onChanged: (phone) => setState(() => _phone = phone),
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.saveAction,
            busy: busy,
            onPressed: portfolio == null ? null : () => _save(portfolio.id),
          ),
          if (occupant != null) ...[
            const SizedBox(height: MmSpace.s3),
            MmButton(
              label: l10n.removeAction,
              icon: MmIcons.delete,
              // It asks first: the dialog's button is the filled one.
              variant: MmButtonVariant.destructiveOutlined,
              onPressed: busy ? null : () => _remove(occupant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ending a tenancy (LEASE-07): the move-out date and why, after saying
/// what happens to the rent of later months and the money that paid it.
class EndLeaseSheet extends ConsumerStatefulWidget {
  const new({required this.lease, super.key});

  final Lease lease;

  @override
  ConsumerState<EndLeaseSheet> createState() => _EndLeaseSheetState();
}

class _EndLeaseSheetState extends ConsumerState<EndLeaseSheet>
    with CommandState {
  late CalendarDate _movedOut = dates.today(context);
  EndReason _reason = EndReason.tenantMovedOut;

  Future<void> _end() async {
    final l10n = AppLocalizations.of(context);
    final done = await runCommand(
      () => ref
          .read(leaseProvider(widget.lease.id).notifier)
          .end(movedOutOn: _movedOut, reason: _reason),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.tenancyEnded,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmBanner(tone: MmBannerTone.warning, message: l10n.endTenancyExplain),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.movedOutLabel,
          value: _movedOut,
          required: true,
          firstDate: widget.lease.terms.startDate,
          lastDate: today,
          onChanged: (date) {
            if (date != null) setState(() => _movedOut = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmRadioGroup<EndReason>(
          label: l10n.changeReasonLabel,
          options: [
            for (final reason in EndReason.values)
              MmOption(value: reason, label: l10n.endReason(reason)),
          ],
          value: _reason,
          onChanged: (reason) {
            if (reason != null) setState(() => _reason = reason);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        // The sheet is built only for ending the tenancy, and this is its
        // point of no return: the one filled red button (DESIGN.md).
        MmButton(
          label: l10n.endTenancyAction,
          variant: MmButtonVariant.destructive,
          busy: busy,
          onPressed: _end,
        ),
      ],
    );
  }
}

class _LeaseActions extends ConsumerStatefulWidget {
  const new({required this.lease, required this.role});

  final Lease lease;
  final MemberRole role;

  @override
  ConsumerState<_LeaseActions> createState() => _LeaseActionsState();
}

class _LeaseActionsState extends ConsumerState<_LeaseActions>
    with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteTenancyTitle,
      message: l10n.deleteTenancyBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final lease = widget.lease;
    final done = await runCommand(
      () => ref.read(leaseProvider(lease.id).notifier).delete(),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.tenancyDeleted,
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.unit(lease.propertyId, lease.unitId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final lease = widget.lease;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (lease.active)
          MmButton(
            label: l10n.endTenancyAction,
            icon: MmIcons.signOut,
            // It starts ending the tenancy: the sheet it opens ends on the
            // filled red button.
            variant: MmButtonVariant.destructiveOutlined,
            onPressed: busy
                ? null
                : () => showMmSheet<void>(
                    context,
                    title: l10n.endTenancyAction,
                    builder: (_) => EndLeaseSheet(lease: lease),
                  ),
          ),
        if (widget.role.deletesRecords) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.deleteAction,
            icon: MmIcons.delete,
            // It asks first (or opens the flow that does): the filled red
            // button is at the point of no return.
            variant: MmButtonVariant.destructiveOutlined,
            busy: busy,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
