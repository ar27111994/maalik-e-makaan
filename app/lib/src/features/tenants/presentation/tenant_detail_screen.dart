import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// One tenant (TEN-01, TEN-03): who they are, their CNIC masked until
/// shown, how to reach them, their emergency contact and references,
/// whether consent was recorded, their tenancies ([extras]) and, for the
/// roles that may, editing, archiving and deleting them.
class TenantDetailScreen extends ConsumerWidget {
  const new({required this.tenantId, this.extras, super.key});

  final String tenantId;

  /// Content from later features (the tenant's tenancies).
  final Widget Function(Tenant tenant)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tenantProvider(tenantId));
    final tenant = state.value?.value;
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final editable =
        tenant != null && !tenant.archived && (role?.runsProperties ?? false);
    final extras = this.extras;
    return MmPage(
      title: tenant?.fullName ?? l10n.navTenants,
      actions: [
        if (editable)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editTenant(tenantId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(tenantProvider(tenantId)),
        loadingLabel: l10n.loadingTenant,
        failedTitle: l10n.tenantLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (tenant) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tenant.archivedAt case final archivedAt?) ...[
              MmBanner(
                tone: MmBannerTone.info,
                icon: MmIcons.archive,
                message: l10n.archivedBanner(
                  dateLabel(context, pakistanDate(archivedAt)),
                ),
              ),
              const SizedBox(height: MmSpace.s4),
            ],
            _TenantDetails(tenant: tenant),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(tenant),
            ],
            if (role != null && role.runsProperties) ...[
              const SizedBox(height: MmSpace.s8),
              _TenantActions(tenant: tenant, role: role),
            ],
          ],
        ),
      ),
    );
  }
}

class _TenantDetails extends StatelessWidget {
  const new({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final guardian = guardianText(l10n, tenant);
    final cnic = tenant.cnic;
    final expiry = tenant.cnicExpiry;
    final today = dates.today(context);
    final consent = tenant.consentRecordedAt;
    Widget phoneRow(String label, PhoneNumber? phone) => phone == null
        ? const SizedBox.shrink()
        : MmDetailRow(label: label, value: phone.national);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.tenantKindLabel,
                value: l10n.tenantKind(tenant.kind),
                userData: false,
              ),
              if (guardian != null)
                MmDetailRow(label: l10n.guardianNameLabel, value: guardian),
              // The CNIC has its own reveal button, so it is not a detail
              // row's value; it is laid out like one that moved under its
              // label, its figures on the end edge with the other values.
              if (cnic != null)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: MmSpace.s2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cnicLabel,
                        style: text.bodyMedium?.copyWith(
                          color: context.mm.colors.inkMuted,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: MmCnicText(cnic: cnic),
                      ),
                    ],
                  ),
                ),
              if (expiry != null)
                MmDetailRow(
                  label: l10n.cnicExpiryLabel,
                  value: dateLabel(context, expiry),
                  userData: false,
                  trailing: expiry.isBefore(today)
                      ? MmStatusBadge(
                          status: MmStatus.overdue,
                          label: l10n.cnicExpired,
                        )
                      : null,
                ),
              if (tenant.ntn case final ntn?)
                MmDetailRow(label: l10n.ntnLabel, value: ntn),
              phoneRow(l10n.phoneLabel, tenant.phone),
              phoneRow(l10n.altPhoneLabel, tenant.altPhone),
              if (tenant.email case final email?)
                MmDetailRow(
                  label: l10n.emailOptionalLabel,
                  value: breakableEmail(email),
                ),
              if (tenant.occupation case final occupation?)
                MmDetailRow(label: l10n.occupationLabel, value: occupation),
              if (tenant.employer case final employer?)
                MmDetailRow(label: l10n.employerLabel, value: employer),
              if (tenant.permanentAddress case final address?)
                MmDetailRow(label: l10n.permanentAddressLabel, value: address),
              if (tenant.previousAddress case final address?)
                MmDetailRow(label: l10n.previousAddressLabel, value: address),
              if (tenant.householdSize case final size?)
                MmDetailRow(
                  label: l10n.householdSizeLabel,
                  value: '$size',
                  userData: false,
                ),
              if (tenant.deductsWithholdingTax)
                MmDetailRow(
                  label: l10n.withholdingTaxLabel,
                  value: l10n.withholdingTaxHelp,
                  userData: false,
                ),
              if (tenant.notes case final notes?)
                MmDetailRow(label: l10n.notesLabel, value: notes),
            ],
          ),
        ),
        if (tenant.emergencyName != null || tenant.emergencyPhone != null) ...[
          const SizedBox(height: MmSpace.s6),
          MmSectionHeader(title: l10n.tenantSectionEmergency),
          const SizedBox(height: MmSpace.s2),
          MmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tenant.emergencyName case final name?)
                  MmDetailRow(label: l10n.contactNameLabel, value: name),
                if (tenant.emergencyRelation case final relation?)
                  MmDetailRow(
                    label: l10n.contactRelationLabel,
                    value: relation,
                  ),
                phoneRow(l10n.phoneLabel, tenant.emergencyPhone),
              ],
            ),
          ),
        ],
        for (final (index, reference) in [
          tenant.reference1,
          tenant.reference2,
        ].indexed)
          if (reference.name != null || reference.phone != null) ...[
            const SizedBox(height: MmSpace.s6),
            MmSectionHeader(title: l10n.referenceLabel(index + 1)),
            const SizedBox(height: MmSpace.s2),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reference.name case final name?)
                    MmDetailRow(label: l10n.contactNameLabel, value: name),
                  phoneRow(l10n.phoneLabel, reference.phone),
                ],
              ),
            ),
          ],
        const SizedBox(height: MmSpace.s6),
        MmBanner(
          tone: consent == null ? MmBannerTone.warning : MmBannerTone.success,
          title: consent == null
              ? l10n.consentMissing
              : l10n.consentRecorded(dateLabel(context, pakistanDate(consent))),
          // The note is the landlord's own words: kept in its direction.
          message: switch (tenant.consentNote) {
            final note? => MmSemantics.isolated(
              note,
              Directionality.of(context),
            ),
            null => l10n.consentLabel,
          },
        ),
      ],
    );
  }
}

class _TenantActions extends ConsumerStatefulWidget {
  const new({required this.tenant, required this.role});

  final Tenant tenant;
  final MemberRole role;

  @override
  ConsumerState<_TenantActions> createState() => _TenantActionsState();
}

class _TenantActionsState extends ConsumerState<_TenantActions>
    with CommandState {
  TenantController get _controller =>
      ref.read(tenantProvider(widget.tenant.id).notifier);

  Future<void> _archive({required bool archived}) async {
    final l10n = AppLocalizations.of(context);
    final name = widget.tenant.fullName;
    if (archived) {
      final confirmed = await showMmConfirmDialog(
        context,
        title: l10n.archiveTenantTitle(name),
        message: l10n.archiveTenantBody,
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
      message: archived ? l10n.tenantArchived(name) : l10n.tenantRestored(name),
      tone: MmBannerTone.success,
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final name = widget.tenant.fullName;
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteTenantTitle(name),
      message: l10n.deleteTenantBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(_controller.delete);
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.tenantDeleted(name),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.tenants);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final archived = widget.tenant.archived;
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
            variant: MmButtonVariant.tertiary,
            onPressed: busy ? null : _delete,
          ),
        ],
      ],
    );
  }
}
