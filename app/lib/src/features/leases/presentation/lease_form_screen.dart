import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// How long a tenancy runs.
enum _Term { months11, months12, custom, periodic }

/// Starting a tenancy of a unit ([unitId], LEASE-01, LEASE-03, LEASE-04),
/// or editing a tenancy's terms ([leaseId]). A new tenancy starts from the
/// portfolio's defaults (due day, grace days, yearly increase). Editing
/// leaves the start, the rent and billing alone: the rent changes through
/// "Change rent", which re-prices the dues.
class LeaseFormScreen extends ConsumerWidget {
  const new({this.unitId, this.tenantId, this.leaseId, super.key});

  final String? unitId;
  final String? tenantId;
  final String? leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final leaseId = this.leaseId;
    if (leaseId != null) {
      final state = ref.watch(leaseProvider(leaseId));
      final detail = state.value?.value;
      if (detail != null) {
        return _LeaseForm(key: ValueKey(leaseId), lease: detail.lease);
      }
      return MmPage(
        title: l10n.editTenancyTitle,
        body: SnapshotView(
          state: state,
          onRetry: () => ref.invalidate(leaseProvider(leaseId)),
          loadingLabel: l10n.loadingTenancy,
          failedTitle: l10n.tenancyLoadFailedTitle,
          builder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    final unitId = this.unitId;
    if (unitId == null || portfolio == null) {
      return MmPage(
        title: l10n.newTenancyTitle,
        body: Semantics(
          container: true,
          label: l10n.loadingTenancy,
          child: const MmSkeleton.text(lines: 6),
        ),
      );
    }
    final unit = ref.watch(unitProvider(unitId));
    final tenants = ref.watch(
      tenantsProvider((portfolioId: portfolio.id, archived: false, search: '')),
    );
    final defaults = ref.watch(portfolioDetailsProvider(portfolio.id)).value;
    final summary = unit.value?.value;
    final list = tenants.value?.value;
    if (summary == null || list == null) {
      final failed = unit.hasError ? unit : null;
      return MmPage(
        title: l10n.newTenancyTitle,
        body: SnapshotView(
          state: failed ?? (tenants.hasError ? tenants : unit),
          onRetry: () {
            ref
              ..invalidate(unitProvider(unitId))
              ..invalidate(tenantsProvider);
          },
          loadingLabel: l10n.loadingTenancy,
          failedTitle: l10n.tenancyLoadFailedTitle,
          builder: (_) => Semantics(
            container: true,
            label: l10n.loadingTenancy,
            child: const MmSkeleton.text(lines: 6),
          ),
        ),
      );
    }
    return _LeaseForm(
      key: ValueKey(unitId),
      unitId: unitId,
      unitLabel: summary.unit.label,
      propertyId: summary.unit.propertyId,
      tenants: list.items,
      tenantId: tenantId,
      defaults: defaults?.value,
    );
  }
}

class _LeaseForm extends ConsumerStatefulWidget {
  const new({
    this.lease,
    this.unitId,
    this.unitLabel,
    this.propertyId,
    this.tenants = const [],
    this.tenantId,
    this.defaults,
    super.key,
  });

  /// The tenancy edited; null to start one.
  final Lease? lease;
  final String? unitId;
  final String? unitLabel;
  final String? propertyId;
  final List<Tenant> tenants;
  final String? tenantId;
  final PortfolioDetails? defaults;

  @override
  ConsumerState<_LeaseForm> createState() => _LeaseFormState();
}

class _LeaseFormState extends ConsumerState<_LeaseForm> with CommandState {
  final _form = GlobalKey<FormState>();
  final String _attempt = newUuid();
  late final LeaseTerms? _old = widget.lease?.terms;
  late final CalendarDate _today = dates.today(context);

  late String? _tenantId = widget.tenantId;
  late CalendarDate _start = _old?.startDate ?? _today;
  late _Term _term = _old == null
      ? _Term.months11
      : _old.endDate == null
      ? _Term.periodic
      : _Term.custom;
  late CalendarDate? _end = _old?.endDate;
  late Money? _rent = _old?.monthlyRent;
  late int _dueDay = _old?.rentDueDay ?? widget.defaults?.defaultDueDay ?? 5;
  late int _grace = _old?.graceDays ?? widget.defaults?.defaultGraceDays ?? 5;
  late Money? _deposit = _old?.securityDeposit;
  late final _increment = TextEditingController(
    text: percentFromBasisPoints(
      _old?.incrementBasisPoints ??
          widget.defaults?.defaultIncrementBasisPoints ??
          1000,
    ),
  );
  late int _incrementMonths = _old?.incrementIntervalMonths ?? 12;
  late String _feeType = _old?.lateFee.type ?? 'none';
  late Money? _feeAmount = switch (_old?.lateFee) {
    FlatLateFee(:final amount) => amount,
    DailyLateFee(:final perDay) => perDay,
    _ => null,
  };
  late final _feePercent = TextEditingController(
    text: switch (_old?.lateFee) {
      PercentLateFee(:final basisPoints) => percentFromBasisPoints(basisPoints),
      _ => '',
    },
  );
  late Money? _feeCap = switch (_old?.lateFee) {
    DailyLateFee(:final cap) => cap,
    _ => null,
  };
  late final _notice = TextEditingController(
    text: '${_old?.noticePeriodDays ?? 30}',
  );
  late bool _prorate = _old?.prorateFirstMonth ?? true;
  late CalendarDate? _billingStart = _old?.billingStartsOn;
  late CalendarDate? _signedOn = _old?.agreementSignedOn;
  late final _stampNumber = TextEditingController(text: _old?.eStampNumber);
  late Money? _stampAmount = _old?.eStampAmount;
  late final _use = TextEditingController(text: _old?.permittedUse);
  late bool _subletting = _old?.sublettingAllowed ?? false;
  late RegistrarStatus _registrar =
      _old?.registrarStatus ?? RegistrarStatus.notPresented;
  late final _office = TextEditingController(text: _old?.registrarOffice);
  late final _registration = TextEditingController(
    text: _old?.registrationNumber,
  );
  late CalendarDate? _registeredOn = _old?.registeredOn;
  late PoliceStatus _police = _old?.policeStatus ?? PoliceStatus.pending;
  late PoliceChannel? _channel = _old?.policeChannel;
  late final _station = TextEditingController(text: _old?.policeStation);
  late final _reference = TextEditingController(text: _old?.policeReference);
  late CalendarDate? _policeOn = _old?.policeRegisteredOn;
  late Money? _policeFee = _old?.policeFee;
  late final _utilities = TextEditingController(text: _old?.utilitiesNote);
  late final _notes = TextEditingController(text: _old?.notes);
  AutovalidateMode _validation = AutovalidateMode.disabled;
  bool _tried = false;

  bool get _editing => widget.lease != null;

  @override
  void dispose() {
    for (final controller in [
      _increment,
      _feePercent,
      _notice,
      _stampNumber,
      _use,
      _office,
      _registration,
      _station,
      _reference,
      _utilities,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  CalendarDate? get _endDate => switch (_term) {
    _Term.months11 => _start.addMonths(11).addDays(-1),
    _Term.months12 => _start.addMonths(12).addDays(-1),
    _Term.custom => _end,
    _Term.periodic => null,
  };

  LateFeePolicy? get _lateFee => switch (_feeType) {
    'flat' => _feeAmount == null ? null : FlatLateFee(_feeAmount!),
    'percent' => switch (parsePercent(_feePercent.text)) {
      final points? => PercentLateFee(points),
      null => null,
    },
    'daily' =>
      _feeAmount == null ? null : DailyLateFee(_feeAmount!, cap: _feeCap),
    _ => const NoLateFee(),
  };

  /// Problems the fields cannot say themselves.
  List<String> _problems(AppLocalizations l10n) => [
    if (!_editing && _tenantId == null) l10n.validationChooseTenant,
    if (!_editing && (_rent == null || !_rent!.isPositive)) l10n.validationRent,
    if (_endDate case final end? when end.isBefore(_start))
      l10n.validationEndAfterStart,
    if (_billingStart case final billing? when billing.isBefore(_start))
      l10n.validationEndAfterStart,
  ];

  Future<void> _save(String portfolioId) async {
    final l10n = AppLocalizations.of(context);
    final valid = _form.currentState!.validate();
    setState(() => _tried = true);
    final fee = _lateFee;
    if (!valid || _problems(l10n).isNotEmpty || fee == null) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final terms = LeaseTerms(
      startDate: _start,
      endDate: _endDate,
      monthlyRent: _rent ?? Money.zero,
      billingStartsOn: _billingStart ?? _start,
      rentDueDay: _dueDay,
      graceDays: _grace,
      securityDeposit: _deposit ?? Money.zero,
      incrementBasisPoints: parsePercent(_increment.text)!,
      incrementIntervalMonths: _incrementMonths,
      lateFee: fee,
      prorateFirstMonth: _prorate,
      noticePeriodDays: int.parse(normalizeDigits(_notice.text).trim()),
      permittedUse: _use.text,
      sublettingAllowed: _subletting,
      agreementSignedOn: _signedOn,
      eStampNumber: _stampNumber.text,
      eStampAmount: _stampAmount,
      registrarStatus: _registrar,
      registrarOffice: _office.text,
      registrationNumber: _registration.text,
      registeredOn: _registeredOn,
      policeStatus: _police,
      policeChannel: _channel,
      policeStation: _station.text,
      policeReference: _reference.text,
      policeRegisteredOn: _policeOn,
      policeFee: _policeFee,
      utilitiesNote: _utilities.text,
      notes: _notes.text,
    );
    late Lease saved;
    final done = await runCommand(() async {
      final lease = widget.lease;
      saved = lease != null
          ? await ref.read(leaseProvider(lease.id).notifier).save(terms)
          : await ref
                .read(
                  leasesProvider((unitId: widget.unitId, tenantId: null))
                      .notifier,
                )
                .start(
                  id: _attempt,
                  portfolioId: portfolioId,
                  unitId: widget.unitId!,
                  tenantId: _tenantId!,
                  terms: terms,
                );
    });
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: _editing
            ? l10n.tenancySaved
            : l10n.tenancyStarted(saved.tenantName),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.lease(saved.id));
  }

  Widget _gap() => const SizedBox(height: MmSpace.s4);

  MmTextField _line(
    AppLocalizations l10n,
    String label,
    TextEditingController controller,
    int max,
  ) => MmTextField(
    label: label,
    controller: controller,
    optional: true,
    maxLength: max,
    validator: (value) =>
        Validators.name(l10n, value, maxLength: max, required: false),
    onChanged: _changed,
  );

  MmDateField _date(
    String label,
    CalendarDate? value,
    ValueChanged<CalendarDate?> onChanged, {
    bool required = false,
  }) => MmDateField(
    label: label,
    value: value,
    required: required,
    optional: !required,
    firstDate: CalendarDate(2000, 1, 1),
    lastDate: _today.addYears(10),
    onChanged: (date) => setState(() => onChanged(date)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final lease = widget.lease;
    if (lease != null) ref.listen(leaseProvider(lease.id), (_, _) {});
    if (!_editing) {
      ref.listen(
        leasesProvider((unitId: widget.unitId, tenantId: null)),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final problems = _tried ? _problems(l10n) : const <String>[];
    final money = MmFormats.moneyOf(context);
    final suggestion = _rent;
    return MmPage(
      title: _editing ? l10n.editTenancyTitle : l10n.newTenancyTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null) FailureBanner(failure: failure),
            for (final problem in problems) ...[
              MmBanner(tone: MmBannerTone.error, message: problem),
              _gap(),
            ],
            MmFormSection(
              title: l10n.leaseSectionWho,
              children: [
                MmDetailRow(
                  label: l10n.unitLabel,
                  value: lease == null
                      ? widget.unitLabel ?? ''
                      : l10n.unitAtProperty(
                          lease.unitLabel,
                          lease.propertyName,
                        ),
                ),
                if (lease != null)
                  MmDetailRow(label: l10n.tenantLabel, value: lease.tenantName)
                else if (widget.tenants.isEmpty)
                  MmBanner(
                    tone: MmBannerTone.warning,
                    message: l10n.noTenantsToChoose,
                    actionLabel: l10n.addTenantAction,
                    onAction: () => context.go(Routes.newTenant),
                  )
                else
                  MmSelectField<String>(
                    label: l10n.tenantLabel,
                    required: true,
                    errorText: _tried && _tenantId == null
                        ? l10n.validationChooseTenant
                        : null,
                    options: [
                      for (final tenant in widget.tenants)
                        MmOption(value: tenant.id, label: tenant.fullName),
                    ],
                    value: _tenantId,
                    onChanged: (id) => setState(() => _tenantId = id),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionTerm,
              children: [
                if (!_editing)
                  _date(l10n.moveInLabel, _start, (date) {
                    if (date != null) _start = date;
                  }, required: true),
                MmSelectField<_Term>(
                  label: l10n.termLabel,
                  required: true,
                  options: [
                    MmOption(value: _Term.months11, label: l10n.term11),
                    MmOption(value: _Term.months12, label: l10n.term12),
                    MmOption(value: _Term.custom, label: l10n.termCustom),
                    MmOption(value: _Term.periodic, label: l10n.termPeriodic),
                  ],
                  value: _term,
                  onChanged: (term) => setState(() {
                    // A custom end starts from the end of the term before.
                    if (term == _Term.custom) _end ??= _endDate;
                    _term = term;
                  }),
                ),
                if (_term == _Term.custom)
                  _date(l10n.endsOnLabel, _end, (date) => _end = date)
                else if (_endDate case final end?)
                  MmDetailRow(
                    label: l10n.endsOnLabel,
                    value: dateLabel(context, end),
                    userData: false,
                  ),
                MmTextField(
                  label: l10n.noticeDaysLabel,
                  controller: _notice,
                  required: true,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.wholeNumber(
                    l10n,
                    value,
                    min: 0,
                    max: LeaseTerms.maxNoticeDays,
                    required: true,
                  ),
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionRent,
              children: [
                if (!_editing) ...[
                  MmMoneyField(
                    label: l10n.monthlyRentLabel,
                    value: _rent,
                    required: true,
                    allowZero: false,
                    invalidText: l10n.validationAmount,
                    onChanged: (amount) => setState(() => _rent = amount),
                  ),
                  _date(
                    l10n.billingStartsLabel,
                    _billingStart ?? _start,
                    (date) => _billingStart = date,
                  ),
                  Text(
                    l10n.billingStartsHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  MmSwitchTile(
                    label: l10n.prorateLabel,
                    description: l10n.prorateHelp,
                    value: _prorate,
                    onChanged: (value) => setState(() => _prorate = value),
                  ),
                ] else
                  MmDetailRow.amount(
                    label: l10n.monthlyRentLabel,
                    amount: lease!.terms.monthlyRent,
                  ),
                MmSelectField<int>(
                  label: l10n.dueDayLabel,
                  helper: l10n.dueDayHelper,
                  options: [
                    for (
                      var day = PortfolioDetails.firstDueDay;
                      day <= PortfolioDetails.lastDueDay;
                      day++
                    )
                      MmOption(value: day, label: '$day'),
                  ],
                  value: _dueDay,
                  onChanged: (day) => setState(() => _dueDay = day),
                ),
                MmStepperField(
                  label: l10n.graceDaysLabel,
                  helper: l10n.graceDaysHelper,
                  value: _grace,
                  min: 0,
                  max: PortfolioDetails.maxGraceDays,
                  decreaseLabel: l10n.fewerDaysAction,
                  increaseLabel: l10n.moreDaysAction,
                  format: l10n.dayCount,
                  onChanged: (days) => setState(() => _grace = days),
                ),
                MmMoneyField(
                  label: l10n.depositLabel,
                  value: _deposit,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  onChanged: (amount) => setState(() => _deposit = amount),
                ),
                MmTextField(
                  label: l10n.incrementLabel,
                  controller: _increment,
                  required: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: suggestion == null || !suggestion.isPositive
                      ? null
                      : switch (parsePercent(_increment.text)) {
                          final points? => l10n.suggestedIncrement(
                            percentFromBasisPoints(points),
                            money.format(
                              RentMath.incrementedRent(
                                suggestion,
                                basisPoints: points,
                              ),
                            ),
                          ),
                          null => null,
                        },
                  validator: (value) => Validators.percent(l10n, value),
                  onChanged: (_) => setState(_changed),
                ),
                MmStepperField(
                  label: l10n.incrementEveryLabel,
                  value: _incrementMonths,
                  min: 1,
                  max: LeaseTerms.maxIncrementMonths,
                  decreaseLabel: l10n.fewerMonthsAction,
                  increaseLabel: l10n.moreMonthsAction,
                  format: l10n.monthCount,
                  onChanged: (months) =>
                      setState(() => _incrementMonths = months),
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionLateFee,
              description: l10n.lateFeeHelp,
              children: [
                MmRadioGroup<String>(
                  label: l10n.lateFeeLabel,
                  options: [
                    MmOption(value: 'none', label: l10n.lateFeeNone),
                    MmOption(value: 'flat', label: l10n.lateFeeFlat),
                    MmOption(value: 'percent', label: l10n.lateFeePercent),
                    MmOption(value: 'daily', label: l10n.lateFeeDaily),
                  ],
                  value: _feeType,
                  onChanged: (type) {
                    if (type != null) setState(() => _feeType = type);
                  },
                ),
                if (_feeType == 'flat' || _feeType == 'daily')
                  MmMoneyField(
                    label: l10n.lateFeeAmountLabel,
                    value: _feeAmount,
                    required: true,
                    allowZero: false,
                    invalidText: l10n.validationAmount,
                    validator: (amount) =>
                        amount == null ? l10n.validationRequired : null,
                    onChanged: (amount) => setState(() => _feeAmount = amount),
                  ),
                if (_feeType == 'percent')
                  MmTextField(
                    label: l10n.lateFeePercentLabel,
                    controller: _feePercent,
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => Validators.percent(l10n, value),
                    onChanged: _changed,
                  ),
                if (_feeType == 'daily')
                  MmMoneyField(
                    label: l10n.lateFeeCapLabel,
                    value: _feeCap,
                    optional: true,
                    allowZero: false,
                    invalidText: l10n.validationAmount,
                    onChanged: (amount) => setState(() => _feeCap = amount),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionAgreement,
              children: [
                _date(
                  l10n.agreementSignedLabel,
                  _signedOn,
                  (date) => _signedOn = date,
                ),
                _line(
                  l10n,
                  l10n.eStampNumberLabel,
                  _stampNumber,
                  LeaseTerms.maxStampLength,
                ),
                MmMoneyField(
                  label: l10n.eStampAmountLabel,
                  value: _stampAmount,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  onChanged: (amount) => setState(() => _stampAmount = amount),
                ),
                _line(
                  l10n,
                  l10n.permittedUseLabel,
                  _use,
                  LeaseTerms.maxUseLength,
                ),
                MmSwitchTile(
                  label: l10n.sublettingLabel,
                  value: _subletting,
                  onChanged: (value) => setState(() => _subletting = value),
                ),
                MmSelectField<RegistrarStatus>(
                  label: l10n.registrarStatusLabel,
                  options: [
                    for (final status in RegistrarStatus.values)
                      MmOption(
                        value: status,
                        label: l10n.registrarStatus(status),
                      ),
                  ],
                  value: _registrar,
                  onChanged: (status) => setState(() => _registrar = status),
                ),
                if (_registrar == RegistrarStatus.presented ||
                    _registrar == RegistrarStatus.registered) ...[
                  _line(
                    l10n,
                    l10n.registrarOfficeLabel,
                    _office,
                    LeaseTerms.maxOfficeLength,
                  ),
                  _line(
                    l10n,
                    l10n.registrationNumberLabel,
                    _registration,
                    LeaseTerms.maxRegistrationLength,
                  ),
                  _date(
                    l10n.registeredOnLabel,
                    _registeredOn,
                    (date) => _registeredOn = date,
                  ),
                ],
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionPolice,
              children: [
                MmSelectField<PoliceStatus>(
                  label: l10n.policeStatusLabel,
                  options: [
                    for (final status in PoliceStatus.values)
                      MmOption(value: status, label: l10n.policeStatus(status)),
                  ],
                  value: _police,
                  onChanged: (status) => setState(() => _police = status),
                ),
                if (_police == PoliceStatus.submitted ||
                    _police == PoliceStatus.registered) ...[
                  MmSelectField<PoliceChannel>(
                    label: l10n.policeChannelLabel,
                    optional: true,
                    options: [
                      for (final channel in PoliceChannel.values)
                        MmOption(
                          value: channel,
                          label: l10n.policeChannel(channel),
                        ),
                    ],
                    value: _channel,
                    onChanged: (channel) => setState(() => _channel = channel),
                  ),
                  _line(
                    l10n,
                    l10n.policeStationLabel,
                    _station,
                    LeaseTerms.maxOfficeLength,
                  ),
                  _line(
                    l10n,
                    l10n.policeReferenceLabel,
                    _reference,
                    LeaseTerms.maxRegistrationLength,
                  ),
                  _date(
                    l10n.registeredOnLabel,
                    _policeOn,
                    (date) => _policeOn = date,
                  ),
                  MmMoneyField(
                    label: l10n.policeFeeLabel,
                    value: _policeFee,
                    optional: true,
                    invalidText: l10n.validationAmount,
                    onChanged: (amount) => setState(() => _policeFee = amount),
                  ),
                ],
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.leaseSectionOther,
              children: [
                MmTextField(
                  label: l10n.utilitiesNoteLabel,
                  controller: _utilities,
                  optional: true,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: LeaseTerms.maxUtilitiesLength,
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.notesLabel,
                  controller: _notes,
                  optional: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: LeaseTerms.maxNotesLength,
                  onChanged: _changed,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: l10n.cancelAction,
          variant: MmButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => context.go(
                  lease != null
                      ? Routes.lease(lease.id)
                      : Routes.unit(widget.propertyId!, widget.unitId!),
                ),
        ),
        primary: MmButton(
          label: _editing ? l10n.saveAction : l10n.startTenancyAction,
          busy: busy,
          onPressed: portfolio == null || (!_editing && widget.tenants.isEmpty)
              ? null
              : () => _save(portfolio.id),
        ),
      ),
    );
  }
}
