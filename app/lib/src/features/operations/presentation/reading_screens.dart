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
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/bill_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Adding a meter reading to a connection, or editing one ([reading])
/// (UTIL-03): the figure, the day, why it was read (move-in, move-out…),
/// and for a new one, the tenancy it was read for.
///
/// The figure is measured against the connection's other readings around
/// the day chosen: below the reading before that day it is kept, with a
/// word that the meter may have been replaced; above a reading after that
/// day (a late move-in reading, say) it is kept, with a word to check the
/// figure and the day.
class ReadingFormSheet extends ConsumerStatefulWidget {
  const new({
    required this.portfolioId,
    required this.connection,
    this.reading,
    super.key,
  });

  final String portfolioId;
  final UtilityConnection connection;
  final MeterReading? reading;

  @override
  ConsumerState<ReadingFormSheet> createState() => _ReadingFormSheetState();
}

class _ReadingFormSheetState extends ConsumerState<ReadingFormSheet>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final MeterReading? _old = widget.reading;

  /// The id of this reading, kept for every retry.
  final String _attempt = newUuid();
  late final _value = TextEditingController(text: _old?.reading.toString());
  late CalendarDate _readOn = _old?.readOn ?? dates.today(context);
  late ReadingContext _context = _old?.context ?? ReadingContext.monthly;
  late String? _leaseId = _old?.leaseId;
  late final _notes = TextEditingController(text: _old?.notes);

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    final value = parseUnits(_value.text);
    if (value == null) return;
    final draft = ReadingDraft(
      reading: value,
      readOn: _readOn,
      context: _context,
      leaseId: _leaseId,
      notes: _notes.text,
    );
    final old = _old;
    late MeterReading saved;
    final done = await runCommand(() async {
      saved = old == null
          ? await ref
                .read(utilityAccountProvider(widget.connection.id).notifier)
                .addReading(
                  id: _attempt,
                  portfolioId: widget.portfolioId,
                  draft: draft,
                )
          : await ref.read(meterReadingProvider(old.id).notifier).save(draft);
    });
    if (!done || !mounted) return;
    // A retry finds the reading its first try stored, which the connection
    // lost: fields changed since then were not saved.
    final earlier = old == null && ReadingDraft.of(saved) != draft;
    unawaited(
      showMmSnackbar(
        context,
        message: earlier
            ? l10n.savedEarlierUnchanged
            : old == null
            ? l10n.readingAdded
            : l10n.readingSaved,
        tone: earlier ? MmBannerTone.warning : MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final today = dates.today(context);
    final connection = widget.connection;
    final others = [
      for (final reading
          in ref
                  .watch(utilityAccountProvider(connection.id))
                  .value
                  ?.value
                  .readings
                  .items ??
              const <MeterReading>[])
        if (reading.id != _old?.id) reading,
    ];
    final (before, after) = readingsAround(others, _readOn);
    final value = parseUnits(_value.text);
    final lower =
        before != null && value != null && value.compareTo(before.reading) < 0;
    final higher =
        after != null && value != null && value.compareTo(after.reading) > 0;
    final leases = _old == null
        ? ref
              .watch(
                tenanciesProvider((
                  propertyId: connection.propertyId,
                  unitId: connection.unitId,
                )),
              )
              .value
              ?.value
        : null;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          MmTextField(
            label: l10n.readingLabel,
            controller: _value,
            required: true,
            helper: before == null
                ? null
                : l10n.lastReadingWas(
                    '${before.reading}',
                    dateInLine(context, before.readOn),
                  ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            leftToRight: true,
            validator: (value) => unitsError(l10n, value, required: true),
            onChanged: (_) => setState(() {}),
          ),
          if (lower) ...[
            const SizedBox(height: MmSpace.s3),
            MmBanner(tone: MmBannerTone.warning, message: l10n.readingLower),
          ],
          if (after != null && higher) ...[
            const SizedBox(height: MmSpace.s3),
            MmBanner(
              tone: MmBannerTone.warning,
              message: l10n.readingHigher(
                '${after.reading}',
                dateInLine(context, after.readOn),
              ),
            ),
          ],
          const SizedBox(height: MmSpace.s4),
          MmDateField(
            label: l10n.readOnLabel,
            value: _readOn,
            required: true,
            firstDate: today.addYears(-5),
            lastDate: today,
            onChanged: (date) {
              if (date != null) setState(() => _readOn = date);
            },
          ),
          const SizedBox(height: MmSpace.s4),
          MmSelectField<ReadingContext>(
            label: l10n.readingContextLabel,
            required: true,
            options: [
              for (final context in ReadingContext.values)
                MmOption(value: context, label: l10n.readingContext(context)),
            ],
            value: _context,
            onChanged: (context) => setState(() => _context = context),
          ),
          if (_old == null) ...[
            const SizedBox(height: MmSpace.s4),
            MmSelectField<String?>(
              label: l10n.tenancyTitle,
              optional: true,
              helper: l10n.readingTenancyHelp,
              options: tenancyOptions(
                l10n,
                leases,
                noneLabel: l10n.noTenancyOption,
              ),
              value: _leaseId,
              onChanged: (id) => setState(() => _leaseId = id),
            ),
          ],
          const SizedBox(height: MmSpace.s4),
          MmTextField(
            label: l10n.notesLabel,
            controller: _notes,
            optional: true,
            maxLength: MeterReading.maxNotesLength,
            inputFormatters: codePointLimit(MeterReading.maxNotesLength),
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: _old == null ? l10n.addReadingAction : l10n.saveAction,
            busy: busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// One meter reading (UTIL-03): the figure, when and why it was read and
/// for which tenancy, what was used since the reading before it (measured
/// against the protected tariff), its photos ([extras]), and last, for the
/// roles that may, deleting it. Editing is the app bar's pencil.
class ReadingScreen extends ConsumerWidget {
  const new({required this.readingId, this.extras, super.key});

  final String readingId;

  /// Content from other features (the meter's photos).
  final Widget Function(ReadingDetail detail)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(meterReadingProvider(readingId));
    final detail = state.value?.value;
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final role = portfolio?.role;
    final extras = this.extras;
    return MmPage(
      title: l10n.readingTitle,
      actions: [
        if (detail != null &&
            portfolio != null &&
            (role?.recordsOperations ?? false))
          IconButton(
            tooltip: l10n.editReadingAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => showMmSheet<void>(
              context,
              title: l10n.editReadingAction,
              builder: (_) => ReadingFormSheet(
                portfolioId: portfolio.id,
                connection: detail.connection,
                reading: detail.reading,
              ),
            ),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(meterReadingProvider(readingId)),
        loadingLabel: l10n.loadingReading,
        failedTitle: l10n.readingLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReadingDetails(detail: detail),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(detail),
            ],
            if (role != null && role.deletesOperations) ...[
              const SizedBox(height: MmSpace.s8),
              _DeleteReading(detail: detail),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadingDetails extends StatelessWidget {
  const new({required this.detail});

  final ReadingDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reading = detail.reading;
    final connection = detail.connection;
    final used = detail.consumption;
    final use = used == null || !connection.watchesProtectedTariff
        ? null
        : ProtectedTariff.useOf(used.perMonth);
    final lease = reading.leaseId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.readingLabel,
                value: '${reading.reading}',
                emphasized: true,
                userData: false,
              ),
              MmDetailRow(
                label: l10n.readOnLabel,
                value: dateLabel(context, reading.readOn),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.readingContextLabel,
                value: l10n.readingContext(reading.context),
                userData: false,
              ),
              if (detail.previous case final previous?)
                MmDetailRow(
                  label: l10n.previousReadingLabel,
                  value: l10n.readingOn(
                    '${previous.reading}',
                    dateInLine(context, previous.readOn),
                  ),
                  userData: false,
                ),
              if (used != null) ...[
                MmDetailRow(
                  label: l10n.unitsUsedLabel,
                  value: l10n.usedSince('${used.units}', used.days),
                  userData: false,
                ),
                MmDetailRow(
                  label: l10n.monthlyPaceLabel,
                  value: l10n.unitsAMonth('${used.perMonth}'),
                  userData: false,
                  trailing: protectedBadge(context, use),
                ),
              ],
              if (reading.notes case final notes?)
                MmDetailRow.prose(label: l10n.notesLabel, value: notes),
            ],
          ),
        ),
        if (use == ProtectedUse.over || use == ProtectedUse.near) ...[
          const SizedBox(height: MmSpace.s3),
          ProtectedBanner(use: use!, paced: true),
        ],
        const SizedBox(height: MmSpace.s3),
        ListCard(
          children: [
            MmListTile(
              leading: Icon(utilityIcon(connection.type)),
              title: connectionNameOf(context, connection),
              subtitle: placeLabel(
                context,
                connection.propertyName,
                connection.unitLabel,
              ),
              subtitleMaxLines: 4,
              chevron: true,
              onTap: () => context.go(Routes.utility(connection.id)),
            ),
            if (lease != null)
              MmListTile(
                leading: const Icon(MmIcons.lease),
                title: l10n.openTenancyAction,
                subtitle: reading.tenantName,
                chevron: true,
                onTap: () => context.go(Routes.lease(lease)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Deleting a reading entered by mistake (owners and managers), after its
/// photos: the last thing on the screen.
class _DeleteReading extends ConsumerStatefulWidget {
  const new({required this.detail});

  final ReadingDetail detail;

  @override
  ConsumerState<_DeleteReading> createState() => _DeleteReadingState();
}

class _DeleteReadingState extends ConsumerState<_DeleteReading>
    with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final detail = widget.detail;
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteReadingTitle,
      message: l10n.deleteReadingBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref.read(meterReadingProvider(detail.reading.id).notifier).delete(),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.readingDeleted,
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.utility(detail.connection.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
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
    );
  }
}
