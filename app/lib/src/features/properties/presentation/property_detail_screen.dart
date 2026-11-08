import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// One property: its nameplate, details and the police-registration rule
/// of its province, its units with their occupancy, and (for the roles
/// that may) editing, archiving and deleting it.
class PropertyDetailScreen extends ConsumerWidget {
  const new({required this.propertyId, this.extras, super.key});

  final String propertyId;

  /// Content from later features (the property's documents).
  final Widget Function(Property property)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(propertyProvider(propertyId));
    final property = state.value?.value;
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final editable =
        property != null &&
        !property.archived &&
        (role?.runsProperties ?? false);
    final extras = this.extras;
    return MmPage(
      title: property?.name ?? l10n.navProperties,
      actions: [
        if (editable)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editProperty(propertyId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(propertyProvider(propertyId)),
        loadingLabel: l10n.loadingProperty,
        failedTitle: l10n.propertyLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (property) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (property.archivedAt case final archivedAt?) ...[
              MmBanner(
                tone: MmBannerTone.info,
                icon: MmIcons.archive,
                message: l10n.archivedBanner(
                  dateLabel(context, pakistanDate(archivedAt)),
                ),
              ),
              const SizedBox(height: MmSpace.s4),
            ],
            MmNameplate(
              name: property.name,
              subtitle: l10n.propertyType(property.type),
              icon: MmIcons.property,
            ),
            const SizedBox(height: MmSpace.s6),
            _Details(property: property),
            const SizedBox(height: MmSpace.s8),
            _Units(property: property, role: role),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(property),
            ],
            if (role != null && role.runsProperties) ...[
              const SizedBox(height: MmSpace.s8),
              _Actions(property: property, role: role),
            ],
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const new({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = property.plotSize;
    final unit = property.plotSizeUnit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.propertyDetailsSection),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (property.addressLine case final address?)
                MmDetailRow(label: l10n.addressLabel, value: address),
              MmDetailRow(
                label: l10n.cityLabel,
                value: propertyPlace(property),
              ),
              MmDetailRow(
                label: l10n.provinceLabel,
                value: l10n.province(property.province),
                userData: false,
              ),
              if (size != null && unit != null)
                MmDetailRow(
                  label: l10n.plotSizeLabel,
                  value: l10n.areaValue('$size', l10n.areaUnit(unit)),
                  userData: false,
                ),
              if (property.coveredAreaSqft case final area?)
                MmDetailRow(
                  label: l10n.coveredAreaLabel,
                  value: l10n.coveredAreaValue('$area'),
                  userData: false,
                ),
              if (property.yearBuilt case final year?)
                MmDetailRow(
                  label: l10n.yearBuiltLabel,
                  value: '$year',
                  userData: false,
                ),
              if (property.purchasePrice case final price?)
                MmDetailRow.amount(
                  label: l10n.purchasePriceLabel,
                  amount: price,
                ),
              if (property.purchasedOn case final date?)
                MmDetailRow(
                  label: l10n.purchasedOnLabel,
                  value: dateLabel(context, date),
                  userData: false,
                ),
              if (property.estimatedValue case final value?)
                MmDetailRow.amount(
                  label: l10n.estimatedValueLabel,
                  amount: value,
                ),
              if (property.valueEstimatedOn case final date?)
                MmDetailRow(
                  label: l10n.valueEstimatedOnLabel,
                  value: dateLabel(context, date),
                  userData: false,
                ),
              if (property.propertyTaxRef case final ref?)
                MmDetailRow(label: l10n.propertyTaxRefLabel, value: ref),
              if (property.notes case final notes?)
                MmDetailRow(label: l10n.notesLabel, value: notes),
            ],
          ),
        ),
        const SizedBox(height: MmSpace.s3),
        MmBanner(
          tone: MmBannerTone.info,
          icon: MmIcons.police,
          message: l10n.policeHint(property.province),
        ),
      ],
    );
  }
}

class _Units extends ConsumerWidget {
  const new({required this.property, required this.role});

  final Property property;
  final MemberRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canAdd = !property.archived && (role?.runsProperties ?? false);
    final provider = unitsProvider(property.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.unitsSection,
          subtitle: l10n.unitsSectionHelp,
          actionLabel: canAdd ? l10n.addUnitAction : null,
          onAction: canAdd
              ? () => context.go(Routes.newUnit(property.id))
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingProperty,
          failedTitle: l10n.unitsLoadFailedTitle,
          builder: (page) => page.items.isEmpty
              ? Text(
                  l10n.unitsEmpty,
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListCard(
                      children: [
                        for (final summary in page.items)
                          UnitTile(summary: summary),
                      ],
                    ),
                    if (page.hasMore)
                      LoadMoreButton(
                        onLoad: () => ref.read(provider.notifier).loadMore(),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A unit in a list: its name, type, asking rent and whether it is let.
class UnitTile extends StatelessWidget {
  const new({required this.summary, super.key});

  final UnitSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = summary.unit;
    final rent = unit.askingRent;
    final type = l10n.unitType(unit.type);
    return MmListTile(
      leading: const Icon(MmIcons.unit),
      title: unit.label,
      subtitle: rent == null
          ? type
          : l10n.listDetail(
              type,
              l10n.askingRentValue(MmFormats.moneyOf(context).format(rent)),
            ),
      subtitleMaxLines: 4,
      trailing: occupancyBadge(context, summary.occupancy),
      onTap: () => context.go(Routes.unit(unit.propertyId, unit.id)),
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const new({required this.property, required this.role});

  final Property property;
  final MemberRole role;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> with CommandState {
  PropertyController get _controller =>
      ref.read(propertyProvider(widget.property.id).notifier);

  Future<void> _archive({required bool archived}) async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(widget.property.name, Directionality.of(context));
    if (archived) {
      final confirmed = await showMmConfirmDialog(
        context,
        title: l10n.archivePropertyTitle(name),
        message: l10n.archivePropertyBody,
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
      message: archived
          ? l10n.propertyArchived(name)
          : l10n.propertyRestored(name),
      tone: MmBannerTone.success,
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(widget.property.name, Directionality.of(context));
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deletePropertyTitle(name),
      message: l10n.deletePropertyBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      typedConfirmation: widget.property.name,
      typedConfirmationLabel: l10n.typeToConfirm(name),
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(_controller.delete);
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.propertyDeleted(name),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.properties);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final archived = widget.property.archived;
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
