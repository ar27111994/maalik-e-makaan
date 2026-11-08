import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// The Properties section: the current portfolio's properties in use (or
/// archived), 50 at a time, each leading to its units. Owners and managers
/// add properties here.
class PropertiesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final list = portfolio == null
        ? null
        : (portfolioId: portfolio.id, archived: _archived);
    return MmPage(
      title: l10n.navProperties,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              label: l10n.loadingProperties,
              child: const MmSkeletonList(itemCount: 4),
            )
          else
            _PropertyList(list: list),
        ],
      ),
      bottomBar: portfolio != null && portfolio.role.runsProperties
          ? MmActionBar(
              primary: MmButton(
                label: l10n.addPropertyAction,
                icon: MmIcons.add,
                onPressed: () => context.go(Routes.newProperty),
              ),
            )
          : null,
    );
  }
}

class _PropertyList extends ConsumerWidget {
  const new({required this.list});

  final PropertyList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SnapshotView(
      state: ref.watch(propertiesProvider(list)),
      onRetry: () => ref.invalidate(propertiesProvider(list)),
      loadingLabel: l10n.loadingProperties,
      failedTitle: l10n.propertiesLoadFailedTitle,
      builder: (page) {
        if (page.items.isEmpty) {
          return list.archived
              ? MmEmptyState(
                  icon: MmIcons.archive,
                  title: l10n.archivedPropertiesEmpty,
                  message: l10n.archivedPropertiesEmptyBody,
                )
              : MmEmptyState(
                  icon: MmIcons.property,
                  title: l10n.propertiesEmptyTitle,
                  message: l10n.propertiesEmptyBody,
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCard(
              children: [
                for (final property in page.items)
                  PropertyTile(property: property),
              ],
            ),
            if (page.hasMore)
              LoadMoreButton(
                onLoad: () =>
                    ref.read(propertiesProvider(list).notifier).loadMore(),
              ),
          ],
        );
      },
    );
  }
}

/// A property in a list: its name, type and place.
class PropertyTile extends StatelessWidget {
  const new({required this.property, super.key});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MmListTile(
      leading: const Icon(MmIcons.property),
      title: property.name,
      subtitle: l10n.listDetail(
        l10n.propertyType(property.type),
        propertyPlace(property),
      ),
      subtitleMaxLines: 4,
      trailing: const Icon(MmIcons.chevronEnd),
      onTap: () => context.go(Routes.property(property.id)),
    );
  }
}
