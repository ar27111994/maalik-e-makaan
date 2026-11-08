import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/place_fields.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The label of [lease] among choices: its tenant and unit, and whether
/// it has ended.
String tenancyChoice(AppLocalizations l10n, Lease lease) {
  final named = l10n.listDetail(lease.tenantName, lease.unitLabel);
  return lease.active ? named : l10n.listDetail(named, l10n.leaseEnded);
}

/// The tenancies of a place to choose from: none (when [noneLabel] names
/// it), the one chosen now (even if it is no longer listed), then those
/// listed, the active first.
List<MmOption<String?>> tenancyOptions(
  AppLocalizations l10n,
  List<Lease>? leases, {
  String? noneLabel,
  String? current,
  String? currentLabel,
}) {
  final sorted = [...?leases]
    ..sort((a, b) => (a.active == b.active ? 0 : (a.active ? -1 : 1)));
  return [
    if (noneLabel != null) MmOption(value: null, label: noneLabel),
    if (current != null &&
        currentLabel != null &&
        !sorted.any((lease) => lease.id == current))
      MmOption(value: current, label: currentLabel),
    for (final lease in sorted)
      MmOption(value: lease.id, label: tenancyChoice(l10n, lease)),
  ];
}

/// Adding a maintenance request, or editing one ([requestId]) (MAINT-01):
/// what needs doing and how urgently, where (and in whose tenancy), who
/// reported it, who does it and for how much, and where it stands. A new
/// request may start at a property and unit ([propertyId], [unitId]).
class MaintenanceFormScreen extends ConsumerWidget {
  const new({this.requestId, this.propertyId, this.unitId, super.key});

  final String? requestId;
  final String? propertyId;
  final String? unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = requestId;
    if (id == null) {
      return _MaintenanceForm(
        start: (
          propertyId: propertyId,
          unitId: propertyId == null ? null : unitId,
        ),
      );
    }
    final state = ref.watch(maintenanceRequestProvider(id));
    if (state.value?.value case final request?) {
      return _MaintenanceForm(key: ValueKey(request.id), request: request);
    }
    return MmPage(
      title: l10n.editRequestTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(maintenanceRequestProvider(id)),
        loadingLabel: l10n.loadingMaintenanceRequest,
        failedTitle: l10n.maintenanceRequestLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _MaintenanceForm extends ConsumerStatefulWidget {
  const new({
    this.request,
    this.start = (propertyId: null, unitId: null),
    super.key,
  });

  final MaintenanceRequest? request;
  final PlaceChoice start;

  @override
  ConsumerState<_MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends ConsumerState<_MaintenanceForm>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final MaintenanceRequest? _old = widget.request;

  /// Names this attempt to add: a retry adds nothing more.
  final String _attempt = newUuid();

  late final _title = TextEditingController(text: _old?.title);
  late final _description = TextEditingController(text: _old?.description);
  late MaintenanceCategory _category =
      _old?.category ?? MaintenanceCategory.other;
  late MaintenancePriority _priority =
      _old?.priority ?? MaintenancePriority.medium;
  late PlaceChoice _place = _old == null
      ? widget.start
      : (propertyId: _old.propertyId, unitId: _old.unitId);
  late String? _leaseId = _old?.leaseId;
  late final _reportedBy = TextEditingController(text: _old?.reportedBy);
  late CalendarDate _reportedOn = _old?.reportedOn ?? dates.today(context);
  late final _assignedTo = TextEditingController(text: _old?.assignedTo);
  late PhoneNumber? _phone = _old?.vendorPhone;
  late Money? _estimate = _old?.estimatedCost;
  late MaintenanceStatus _status = _old?.status ?? MaintenanceStatus.open;
  late CalendarDate? _resolvedOn = _old?.resolvedOn;
  late final _resolution = TextEditingController(text: _old?.resolutionNote);
  AutovalidateMode _validation = AutovalidateMode.disabled;
  bool _tried = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _reportedBy,
      _assignedTo,
      _resolution,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String portfolioId) async {
    final l10n = AppLocalizations.of(context);
    final valid = _form.currentState!.validate();
    setState(() => _tried = true);
    final propertyId = _place.propertyId;
    final resolved = _status == MaintenanceStatus.resolved;
    if (!valid || propertyId == null || (resolved && _resolvedOn == null)) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final draft = MaintenanceDraft(
      propertyId: propertyId,
      unitId: _place.unitId,
      leaseId: _leaseId,
      title: _title.text,
      description: _description.text,
      category: _category,
      priority: _priority,
      status: _status,
      reportedBy: _reportedBy.text,
      reportedOn: _reportedOn,
      assignedTo: _assignedTo.text,
      vendorPhone: _phone,
      estimatedCost: _estimate,
      resolvedOn: _resolvedOn,
      resolutionNote: _resolution.text,
    );
    late MaintenanceRequest saved;
    final old = _old;
    final done = await runCommand(() async {
      saved = old == null
          ? await ref
                .read(
                  maintenanceListProvider((
                    portfolioId: portfolioId,
                    pending: true,
                  )).notifier,
                )
                .create(_attempt, draft)
          : await ref
                .read(maintenanceRequestProvider(old.id).notifier)
                .save(draft);
    });
    if (!done || !mounted) return;
    // A retry finds the request its first try stored, which the connection
    // lost: fields changed since then were not saved.
    final earlier = old == null && MaintenanceDraft.of(saved) != draft;
    unawaited(
      showMmSnackbar(
        context,
        message: earlier
            ? l10n.savedEarlierUnchanged
            : old == null
            ? l10n.requestAdded
            : l10n.requestSaved,
        tone: earlier ? MmBannerTone.warning : MmBannerTone.success,
      ),
    );
    context.go(Routes.maintenanceRequest(saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (_old case final old?) {
      // Keeps what this form changes read while it is open.
      ref.listen(maintenanceRequestProvider(old.id), (_, _) {});
    } else if (portfolio != null) {
      ref.listen(
        maintenanceListProvider((portfolioId: portfolio.id, pending: true)),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final today = dates.today(context);
    final propertyId = _place.propertyId;
    final leases = propertyId == null
        ? null
        : ref
              .watch(
                tenanciesProvider((
                  propertyId: propertyId,
                  unitId: _place.unitId,
                )),
              )
              .value
              ?.value;
    final resolved = _status == MaintenanceStatus.resolved;
    return MmPage(
      title: _old == null ? l10n.newRequestTitle : l10n.editRequestTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null) FailureBanner(failure: failure),
            MmFormSection(
              title: l10n.requestSectionWhat,
              children: [
                MmTextField(
                  label: l10n.requestTitleLabel,
                  controller: _title,
                  required: true,
                  helper: l10n.requestTitleHelp,
                  maxLength: MaintenanceRequest.maxTitleLength,
                  // One line of text that wraps, so a long title stays
                  // readable at large text sizes instead of scrolling
                  // out of sight.
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter,
                    ...codePointLimit(MaintenanceRequest.maxTitleLength),
                  ],
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: MaintenanceRequest.maxTitleLength,
                  ),
                ),
                MmSelectField<MaintenanceCategory>(
                  label: l10n.maintenanceCategoryLabel,
                  required: true,
                  options: [
                    for (final category in MaintenanceCategory.values)
                      MmOption(
                        value: category,
                        label: l10n.maintenanceCategory(category),
                      ),
                  ],
                  value: _category,
                  onChanged: (category) => setState(() => _category = category),
                ),
                MmSelectField<MaintenancePriority>(
                  label: l10n.priorityLabel,
                  required: true,
                  options: [
                    for (final priority in MaintenancePriority.values)
                      MmOption(
                        value: priority,
                        label: l10n.maintenancePriority(priority),
                      ),
                  ],
                  value: _priority,
                  onChanged: (priority) => setState(() => _priority = priority),
                ),
                MmTextField(
                  label: l10n.descriptionLabel,
                  controller: _description,
                  optional: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: MaintenanceRequest.maxDescriptionLength,
                  inputFormatters: codePointLimit(
                    MaintenanceRequest.maxDescriptionLength,
                  ),
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.requestSectionWhere,
              children: [
                if (portfolio != null)
                  PlaceFields(
                    portfolioId: portfolio.id,
                    value: _place,
                    propertyRequired: true,
                    propertyFixed: _old != null,
                    propertyName: _old?.propertyName,
                    unitLabel: _old?.unitLabel,
                    propertyError: _tried && propertyId == null
                        ? l10n.validationRequired
                        : null,
                    onChanged: (place) => setState(() {
                      _place = place;
                      _leaseId = null;
                    }),
                  ),
                if (propertyId != null)
                  MmSelectField<String?>(
                    label: l10n.tenancyTitle,
                    optional: true,
                    helper: l10n.requestTenancyHelp,
                    options: tenancyOptions(
                      l10n,
                      leases,
                      noneLabel: l10n.noTenancyOption,
                      current: _leaseId,
                      currentLabel: _old?.tenantName,
                    ),
                    value: _leaseId,
                    onChanged: (id) => setState(() => _leaseId = id),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.requestSectionWho,
              children: [
                MmTextField(
                  label: l10n.reportedByLabel,
                  controller: _reportedBy,
                  optional: true,
                  maxLength: MaintenanceRequest.maxNameLength,
                  inputFormatters: codePointLimit(
                    MaintenanceRequest.maxNameLength,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                MmDateField(
                  label: l10n.reportedOnLabel,
                  value: _reportedOn,
                  required: true,
                  firstDate: today.addYears(-5),
                  lastDate: today,
                  onChanged: (date) {
                    if (date != null) setState(() => _reportedOn = date);
                  },
                ),
                MmTextField(
                  label: l10n.assignedToLabel,
                  controller: _assignedTo,
                  optional: true,
                  helper: l10n.assignedToHelp,
                  maxLength: MaintenanceRequest.maxNameLength,
                  inputFormatters: codePointLimit(
                    MaintenanceRequest.maxNameLength,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                MmPhoneField(
                  label: l10n.vendorPhoneLabel,
                  value: _phone,
                  optional: true,
                  invalidText: l10n.validationPhone,
                  onChanged: (phone) => setState(() => _phone = phone),
                ),
                MmMoneyField(
                  label: l10n.estimateLabel,
                  value: _estimate,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  onChanged: (amount) => setState(() => _estimate = amount),
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.requestSectionStatus,
              children: [
                MmSelectField<MaintenanceStatus>(
                  label: l10n.statusLabel,
                  required: true,
                  options: [
                    for (final status in MaintenanceStatus.values)
                      MmOption(
                        value: status,
                        label: l10n.maintenanceStatus(status),
                      ),
                  ],
                  value: _status,
                  onChanged: (status) => setState(() {
                    _status = status;
                    if (status == MaintenanceStatus.resolved) {
                      _resolvedOn ??= today;
                    }
                  }),
                ),
                if (resolved) ...[
                  MmDateField(
                    label: l10n.resolvedOnLabel,
                    value: _resolvedOn,
                    required: true,
                    errorText: _tried && _resolvedOn == null
                        ? l10n.validationRequired
                        : null,
                    firstDate: today.addYears(-5),
                    lastDate: today,
                    onChanged: (date) => setState(() => _resolvedOn = date),
                  ),
                  MmTextField(
                    label: l10n.resolutionLabel,
                    controller: _resolution,
                    optional: true,
                    helper: l10n.resolutionHelp,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: MaintenanceRequest.maxResolutionLength,
                    inputFormatters: codePointLimit(
                      MaintenanceRequest.maxResolutionLength,
                    ),
                    keyboardType: TextInputType.multiline,
                  ),
                ],
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
                  _old == null
                      ? Routes.maintenance
                      : Routes.maintenanceRequest(_old.id),
                ),
        ),
        primary: MmButton(
          label: l10n.saveAction,
          busy: busy,
          onPressed: portfolio == null ? null : () => _save(portfolio.id),
        ),
      ),
    );
  }
}
