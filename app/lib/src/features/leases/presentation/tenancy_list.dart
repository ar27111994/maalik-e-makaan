import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// The tenancies of a unit ([unitId]) or of a tenant ([tenantId]), newest
/// first, each leading to its screen, with "Start tenancy" for the roles
/// that may (when [canStart]).
class TenancyList extends ConsumerWidget {
  const new({this.unitId, this.tenantId, this.canStart = false, super.key});

  final String? unitId;
  final String? tenantId;

  /// Offers starting a tenancy (a unit in use, with no tenancy now).
  final bool canStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = (unitId: unitId, tenantId: tenantId);
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final start = canStart && (role?.runsProperties ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.tenantTenanciesSection,
          actionLabel: start ? l10n.startTenancyAction : null,
          onAction: start
              ? () => context.go(Routes.newLease(unitId: unitId))
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(leasesProvider(list)),
          onRetry: () => ref.invalidate(leasesProvider(list)),
          loadingLabel: l10n.loadingTenancy,
          failedTitle: l10n.tenanciesLoadFailedTitle,
          builder: (leases) => leases.isEmpty
              ? Text(
                  l10n.tenanciesEmpty,
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              : ListCard(
                  children: [
                    for (final lease in leases)
                      _TenancyTile(lease: lease, byUnit: unitId != null),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TenancyTile extends StatelessWidget {
  const new({required this.lease, required this.byUnit});

  final Lease lease;

  /// Listed under its unit, so named by its tenant (else by its unit).
  final bool byUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final terms = lease.terms;
    final end = lease.movedOutOn ?? terms.endDate;
    final period = end == null
        ? dateLabel(context, terms.startDate)
        : '${dateLabel(context, terms.startDate)} – ${dateLabel(context, end)}';
    return MmListTile(
      leading: const Icon(MmIcons.lease),
      title: byUnit
          ? lease.tenantName
          : l10n.unitAtProperty(lease.unitLabel, lease.propertyName),
      subtitle: l10n.listDetail(
        MmFormats.moneyOf(context).format(terms.monthlyRent),
        period,
      ),
      subtitleMaxLines: 4,
      trailing: leaseBadge(context, lease),
      onTap: () => context.go(Routes.lease(lease.id)),
    );
  }
}
