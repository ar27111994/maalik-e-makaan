import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Extra content of the unit screen from later features (its tenancy),
/// given the unit and its occupancy.
typedef UnitExtras = Widget Function(UnitSummary summary);

/// One unit (PROP-02, PROP-03): what it is, its asking rent, whether it is
/// let or vacant (and since when), and for the roles that may, editing,
/// archiving and deleting it.
class UnitDetailScreen extends ConsumerWidget {
  const new({
    required this.propertyId,
    required this.unitId,
    this.extras,
    super.key,
  });

  final String propertyId;
  final String unitId;
  final UnitExtras? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(unitProvider(unitId));
    final summary = state.value?.value;
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final property = ref.watch(propertyProvider(propertyId)).value?.value;
    final editable =
        summary != null &&
        !summary.unit.archived &&
        (role?.runsProperties ?? false);
    final extras = this.extras;
    return MmPage(
      title: summary?.unit.label ?? l10n.unitsSection,
      actions: [
        if (editable)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editUnit(propertyId, unitId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(unitProvider(unitId)),
        loadingLabel: l10n.loadingUnit,
        failedTitle: l10n.unitLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (summary) {
          final unit = summary.unit;
          final rent = unit.askingRent;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unit.archivedAt case final archivedAt?) ...[
                MmBanner(
                  tone: MmBannerTone.info,
                  icon: MmIcons.archive,
                  message: l10n.archivedBanner(
                    dateLabel(context, pakistanDate(archivedAt)),
                  ),
                ),
                const SizedBox(height: MmSpace.s4),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: occupancyBadge(context, summary.occupancy),
              ),
              const SizedBox(height: MmSpace.s4),
              MmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (property != null)
                      MmDetailRow(
                        label: l10n.unitPropertyLabel,
                        value: property.name,
                      ),
                    MmDetailRow(
                      label: l10n.typeLabel,
                      value: l10n.unitType(unit.type),
                      userData: false,
                    ),
                    if (unit.floorLabel case final floor?)
                      MmDetailRow(label: l10n.floorLabel, value: floor),
                    if (unit.bedrooms case final rooms?)
                      MmDetailRow(
                        label: l10n.bedroomsLabel,
                        value: '$rooms',
                        userData: false,
                      ),
                    if (unit.bathrooms case final rooms?)
                      MmDetailRow(
                        label: l10n.bathroomsLabel,
                        value: '$rooms',
                        userData: false,
                      ),
                    if (unit.coveredAreaSqft case final area?)
                      MmDetailRow(
                        label: l10n.coveredAreaLabel,
                        value: l10n.coveredAreaValue('$area'),
                        userData: false,
                      ),
                    MmDetailRow(
                      label: l10n.furnishedLabel,
                      value: unit.furnished
                          ? l10n.furnishedLabel
                          : l10n.unfurnishedValue,
                      userData: false,
                    ),
                    if (rent != null)
                      MmDetailRow.amount(
                        label: l10n.askingRentLabel,
                        amount: rent,
                      ),
                    if (unit.notes case final notes?)
                      MmDetailRow(label: l10n.notesLabel, value: notes),
                  ],
                ),
              ),
              if (extras != null) ...[
                const SizedBox(height: MmSpace.s8),
                extras(summary),
              ],
              if (role != null && role.runsProperties) ...[
                const SizedBox(height: MmSpace.s8),
                _UnitActions(unit: unit, role: role),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UnitActions extends ConsumerStatefulWidget {
  const new({required this.unit, required this.role});

  final Unit unit;
  final MemberRole role;

  @override
  ConsumerState<_UnitActions> createState() => _UnitActionsState();
}

class _UnitActionsState extends ConsumerState<_UnitActions> with CommandState {
  UnitController get _controller =>
      ref.read(unitProvider(widget.unit.id).notifier);

  Future<void> _archive({required bool archived}) async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(widget.unit.label, Directionality.of(context));
    if (archived) {
      final confirmed = await showMmConfirmDialog(
        context,
        title: l10n.archiveUnitTitle(name),
        message: l10n.archiveUnitBody,
        confirmLabel: l10n.archiveAction,
      );
      if (!confirmed || !mounted) return;
    }
    final done = await runCommand(
      () => _controller.archive(archived: archived),
    );
    if (!done || !mounted) return;
    await showMmSnackbar(
      context,
      message: archived ? l10n.unitArchived(name) : l10n.unitRestored(name),
      tone: MmBannerTone.success,
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(widget.unit.label, Directionality.of(context));
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteUnitTitle(name),
      message: l10n.deleteUnitBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => _controller.delete(widget.unit.propertyId),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.unitDeleted(name),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.property(widget.unit.propertyId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final archived = widget.unit.archived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmButton(
          label: archived ? l10n.restoreAction : l10n.archiveAction,
          icon: archived ? MmIcons.restore : MmIcons.archive,
          variant: MmButtonVariant.secondary,
          busy: busy,
          onPressed: () => _archive(archived: !archived),
        ),
        if (widget.role.deletesRecords) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.deleteAction,
            icon: MmIcons.delete,
            // It asks first (or opens the flow that does): the filled red
            // button is at the point of no return.
            variant: MmButtonVariant.destructiveOutlined,
            onPressed: busy ? null : _delete,
          ),
        ],
      ],
    );
  }
}

/// Adding a unit to a property, or editing one ([unitId]).
class UnitFormScreen extends ConsumerWidget {
  const new({required this.propertyId, this.unitId, super.key});

  final String propertyId;

  /// The unit edited; null to add one.
  final String? unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = unitId;
    if (id == null) return _UnitForm(propertyId: propertyId, unit: null);
    final state = ref.watch(unitProvider(id));
    final summary = state.value?.value;
    if (summary != null) {
      return _UnitForm(
        key: ValueKey(summary.unit.id),
        propertyId: propertyId,
        unit: summary.unit,
      );
    }
    return MmPage(
      title: l10n.editUnitTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(unitProvider(id)),
        loadingLabel: l10n.loadingUnit,
        failedTitle: l10n.unitLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _UnitForm extends ConsumerStatefulWidget {
  const new({required this.propertyId, required this.unit, super.key});

  final String propertyId;
  final Unit? unit;

  @override
  ConsumerState<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends ConsumerState<_UnitForm> with CommandState {
  final _form = GlobalKey<FormState>();
  late final Unit? _old = widget.unit;
  final String _attempt = newUuid();
  late final _label = TextEditingController(text: _old?.label);
  late UnitType _type = _old?.type ?? UnitType.portion;
  late final _floor = TextEditingController(text: _old?.floorLabel);
  late final _bedrooms = TextEditingController(
    text: _old?.bedrooms?.toString(),
  );
  late final _bathrooms = TextEditingController(
    text: _old?.bathrooms?.toString(),
  );
  late final _covered = TextEditingController(
    text: _old?.coveredAreaSqft?.toString(),
  );
  late bool _furnished = _old?.furnished ?? false;
  late Money? _rent = _old?.askingRent;
  late bool _available = _old?.isAvailable ?? true;
  late final _notes = TextEditingController(text: _old?.notes);
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final controller in [
      _label,
      _floor,
      _bedrooms,
      _bathrooms,
      _covered,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(normalizeDigits(controller.text).trim());

  Future<void> _save(String portfolioId) async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final unit = Unit(
      id: _old?.id ?? _attempt,
      propertyId: widget.propertyId,
      label: _label.text,
      type: _type,
      floorLabel: _floor.text,
      bedrooms: _int(_bedrooms),
      bathrooms: _int(_bathrooms),
      coveredAreaSqft: _int(_covered),
      furnished: _furnished,
      askingRent: _rent,
      isAvailable: _available,
      notes: _notes.text,
    );
    late Unit saved;
    final done = await runCommand(() async {
      saved = _old == null
          ? await ref
                .read(unitsProvider(widget.propertyId).notifier)
                .create(portfolioId, unit)
          : await ref.read(unitProvider(unit.id).notifier).save(unit);
    });
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: _old == null
            ? l10n.unitAdded(
                inSentence(saved.label, Directionality.of(context)),
              )
            : l10n.unitSaved(
                inSentence(saved.label, Directionality.of(context)),
              ),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.unit(widget.propertyId, saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    // Keeps what this form changes read while it is open.
    ref.listen(unitsProvider(widget.propertyId), (_, _) {});
    if (_old != null) ref.listen(unitProvider(_old.id), (_, _) {});
    final failure = this.failure;
    final labelError = rejectedReason == 'duplicate_unit_label'
        ? failureMessage(l10n, failure!)
        : null;
    String? rooms(String? value) =>
        Validators.wholeNumber(l10n, value, min: 0, max: Unit.maxRooms);
    return MmPage(
      title: _old == null ? l10n.newUnitTitle : l10n.editUnitTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && labelError == null)
              FailureBanner(failure: failure),
            MmTextField(
              label: l10n.unitLabelLabel,
              controller: _label,
              required: true,
              helper: l10n.unitLabelHelper,
              errorText: labelError,
              maxLength: Unit.maxLabelLength,
              inputFormatters: codePointLimit(Unit.maxLabelLength),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  Validators.name(l10n, value, maxLength: Unit.maxLabelLength),
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s4),
            MmSelectField<UnitType>(
              label: l10n.typeLabel,
              required: true,
              options: [
                for (final type in UnitType.values)
                  MmOption(value: type, label: l10n.unitType(type)),
              ],
              value: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: MmSpace.s4),
            MmMoneyField(
              label: l10n.askingRentLabel,
              value: _rent,
              optional: true,
              helper: l10n.askingRentHelper,
              invalidText: l10n.validationAmount,
              onChanged: (amount) => setState(() => _rent = amount),
            ),
            const SizedBox(height: MmSpace.s4),
            MmSwitchTile(
              label: l10n.availableLabel,
              description: l10n.availableHelp,
              value: _available,
              onChanged: (value) => setState(() => _available = value),
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.floorLabel,
              controller: _floor,
              optional: true,
              maxLength: Unit.maxFloorLength,
              inputFormatters: codePointLimit(Unit.maxFloorLength),
              validator: (value) => Validators.name(
                l10n,
                value,
                maxLength: Unit.maxFloorLength,
                required: false,
              ),
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.bedroomsLabel,
              controller: _bedrooms,
              optional: true,
              keyboardType: TextInputType.number,
              validator: rooms,
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.bathroomsLabel,
              controller: _bathrooms,
              optional: true,
              keyboardType: TextInputType.number,
              validator: rooms,
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.coveredAreaLabel,
              controller: _covered,
              optional: true,
              keyboardType: TextInputType.number,
              validator: (value) => Validators.wholeNumber(
                l10n,
                value,
                min: 1,
                max: Property.maxCoveredArea,
              ),
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s4),
            MmSwitchTile(
              label: l10n.furnishedLabel,
              value: _furnished,
              onChanged: (value) => setState(() => _furnished = value),
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.notesLabel,
              controller: _notes,
              optional: true,
              minLines: 3,
              maxLines: 8,
              maxLength: Property.maxNotesLength,
              inputFormatters: codePointLimit(Property.maxNotesLength),
              keyboardType: TextInputType.multiline,
              onChanged: _changed,
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
                      ? Routes.property(widget.propertyId)
                      : Routes.unit(widget.propertyId, _old.id),
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
