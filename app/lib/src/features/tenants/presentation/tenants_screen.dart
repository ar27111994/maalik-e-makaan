import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// The Tenants section: the current portfolio's tenants in use (or
/// archived), searched by name, phone or CNIC, 50 at a time. Owners and
/// managers add tenants here.
class TenantsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// How long typing pauses before the search runs (a typing pause, not
  /// motion, so not an MmDuration).
  // design-lint: allow-next-line typing pause, not motion
  static const searchDelay = Duration(milliseconds: 300);

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  bool _archived = false;
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _searchFor(String text) {
    _debounce?.cancel();
    _debounce = Timer(TenantsScreen.searchDelay, () {
      if (mounted) setState(() => _search = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final list = portfolio == null
        ? null
        : (portfolioId: portfolio.id, archived: _archived, search: _search);
    return MmPage(
      title: l10n.navTenants,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmSearchField(hint: l10n.searchTenantsHint, onChanged: _searchFor),
          const SizedBox(height: MmSpace.s3),
          MmFilterChips<bool>(
            multiSelect: false,
            options: [
              MmFilterOption(value: false, label: l10n.filterInUse),
              MmFilterOption(value: true, label: l10n.filterArchived),
            ],
            selected: {_archived},
            onChanged: (selected) {
              if (selected.isNotEmpty) {
                setState(() => _archived = selected.single);
              }
            },
          ),
          const SizedBox(height: MmSpace.s4),
          if (list == null)
            Semantics(
              container: true,
              label: l10n.loadingTenants,
              child: const MmSkeletonList(itemCount: 4),
            )
          else
            _TenantList(list: list),
        ],
      ),
      bottomBar: portfolio != null && portfolio.role.runsProperties
          ? MmActionBar(
              primary: MmButton(
                label: l10n.addTenantAction,
                icon: MmIcons.add,
                onPressed: () => context.go(Routes.newTenant),
              ),
            )
          : null,
    );
  }
}

class _TenantList extends ConsumerWidget {
  const new({required this.list});

  final TenantList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SnapshotView(
      state: ref.watch(tenantsProvider(list)),
      onRetry: () => ref.invalidate(tenantsProvider(list)),
      loadingLabel: l10n.loadingTenants,
      failedTitle: l10n.tenantsLoadFailedTitle,
      builder: (page) {
        if (page.items.isEmpty) {
          if (list.search.isNotEmpty) {
            return MmEmptyState(
              icon: MmIcons.search,
              title: l10n.noTenantMatches(list.search),
              message: l10n.searchTenantsHint,
            );
          }
          return list.archived
              ? MmEmptyState(
                  icon: MmIcons.archive,
                  title: l10n.archivedTenantsEmpty,
                  message: l10n.archivedTenantsEmptyBody,
                )
              : MmEmptyState(
                  icon: MmIcons.tenants,
                  title: l10n.tenantsEmptyTitle,
                  message: l10n.tenantsEmptyBody,
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCard(
              children: [
                for (final tenant in page.items) TenantTile(tenant: tenant),
              ],
            ),
            if (page.hasMore)
              LoadMoreButton(
                onLoad: () =>
                    ref.read(tenantsProvider(list).notifier).loadMore(),
              ),
          ],
        );
      },
    );
  }
}

/// A tenant in a list: their name, and their phone or guardian.
class TenantTile extends StatelessWidget {
  const new({required this.tenant, super.key});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = tenant.phone;
    final details = [
      if (phone != null) phoneLabel(phone, Directionality.of(context)),
      ?guardianText(l10n, tenant),
    ];
    return MmListTile(
      leading: MmAvatar(name: tenant.fullName),
      title: tenant.fullName,
      subtitle: details.isEmpty
          ? l10n.tenantKind(tenant.kind)
          : detailLine(details),
      subtitleMaxLines: 4,
      trailing: const Icon(MmIcons.chevronEnd),
      onTap: () => context.go(Routes.tenant(tenant.id)),
    );
  }
}
