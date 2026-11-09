import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:mm_ui/mm_ui.dart';

/// A tenant chosen for a new tenancy.
typedef TenantChoice = ({String id, String name});

/// A unit chosen for a new tenancy, and the property it is in.
typedef UnitChoice = ({
  String unitId,
  String unitLabel,
  String propertyId,
  String propertyName,
});

/// A choice made in a sheet of its own (the tenant or the unit of a new
/// tenancy, from lists too long to load whole): its [label] above, the
/// chosen [value] (the landlord's words) or [placeholder], and a button
/// that opens the sheet ([onChoose]); [errorText] under it when the form
/// was sent without a choice.
class ChoiceField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.chooseLabel,
    required this.changeLabel,
    required this.onChoose,
    this.errorText,
    super.key,
  });

  final String label;
  final String? value;
  final String placeholder;

  /// The button's label while nothing is chosen ("Choose the tenant").
  final String chooseLabel;

  /// The button's label once something is ("Change the tenant").
  final String changeLabel;
  final VoidCallback? onChoose;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final value = this.value;
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value == null)
          MmDetailRow(label: label, value: placeholder, userData: false)
        else
          MmDetailRow(label: label, value: value),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
            child: Semantics(
              liveRegion: true,
              child: Row(
                spacing: MmSpace.s2,
                children: [
                  Icon(
                    MmIcons.error,
                    color: colors.overdue,
                    size: MmIconSize.withText(context, MmSize.iconSm),
                  ),
                  Expanded(
                    child: Text(
                      error,
                      style: text.bodyMedium!.copyWith(color: colors.overdue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MmButton(
            label: value == null ? chooseLabel : changeLabel,
            icon: MmIcons.search,
            variant: MmButtonVariant.secondary,
            onPressed: onChoose,
          ),
        ),
      ],
    );
  }
}

/// Lets the landlord pick one of the tenants of [portfolioId] still in use,
/// searched on the server by name, phone or CNIC (a portfolio can hold
/// more tenants than one page). Completes with null when the sheet closes
/// without a choice.
Future<TenantChoice?> chooseTenant(
  BuildContext context, {
  required String portfolioId,
}) => showMmSheet<TenantChoice>(
  context,
  title: AppLocalizations.of(context).chooseTenantTitle,
  builder: (_) => TenantChooser(portfolioId: portfolioId),
);

/// The inside of [chooseTenant]'s sheet: a search field and the tenants
/// that match, 50 at a time.
class TenantChooser extends ConsumerStatefulWidget {
  const new({required this.portfolioId, super.key});

  /// How long typing pauses before the search runs (a typing pause, not
  /// motion, so not an MmDuration), as on the tenants screen.
  // design-lint: allow-next-line typing pause, not motion
  static const searchDelay = Duration(milliseconds: 300);

  final String portfolioId;

  @override
  ConsumerState<TenantChooser> createState() => _TenantChooserState();
}

class _TenantChooserState extends ConsumerState<TenantChooser> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _searchFor(String text) {
    _debounce?.cancel();
    _debounce = Timer(TenantChooser.searchDelay, () {
      if (mounted) setState(() => _search = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = (
      portfolioId: widget.portfolioId,
      archived: false,
      search: _search,
    );
    final provider = tenantsProvider(list);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSearchField(
          hint: l10n.searchTenantsHint,
          autofocus: true,
          onChanged: _searchFor,
        ),
        const SizedBox(height: MmSpace.s3),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingTenants,
          failedTitle: l10n.tenantsLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 3),
          builder: (page) => page.items.isEmpty
              ? Text(
                  _search.isEmpty
                      ? l10n.noTenantsToChoose
                      : l10n.noTenantMatches(
                          inSentence(_search, Directionality.of(context)),
                        ),
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListCard(
                      children: [
                        for (final tenant in page.items)
                          _TenantRow(tenant: tenant),
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

class _TenantRow extends StatelessWidget {
  const new({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final phone = tenant.phone;
    return MmListTile(
      leading: MmAvatar(name: tenant.fullName),
      title: tenant.fullName,
      subtitle: phone == null
          ? null
          : phoneLabel(phone, Directionality.of(context)),
      onTap: () =>
          Navigator.of(context)
              .pop<TenantChoice>((id: tenant.id, name: tenant.fullName)),
    );
  }
}

/// Lets the landlord pick a unit of [portfolioId] in use: a property
/// first, then one of its units. Completes with null when the sheet closes
/// without a choice.
Future<UnitChoice?> chooseUnit(
  BuildContext context, {
  required String portfolioId,
}) => showMmSheet<UnitChoice>(
  context,
  title: AppLocalizations.of(context).chooseUnitTitle,
  builder: (_) => UnitChooser(portfolioId: portfolioId),
);

/// The inside of [chooseUnit]'s sheet: the properties, then the units of
/// the one chosen.
class UnitChooser extends ConsumerStatefulWidget {
  const new({required this.portfolioId, super.key});

  final String portfolioId;

  @override
  ConsumerState<UnitChooser> createState() => _UnitChooserState();
}

class _UnitChooserState extends ConsumerState<UnitChooser> {
  Property? _property;

  @override
  Widget build(BuildContext context) {
    final property = _property;
    return property == null ? _properties(context) : _units(context, property);
  }

  Widget _properties(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = propertiesProvider((
      portfolioId: widget.portfolioId,
      archived: false,
    ));
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingProperties,
      failedTitle: l10n.propertiesLoadFailedTitle,
      skeleton: const MmSkeletonList(itemCount: 3),
      builder: (page) => page.items.isEmpty
          ? Text(
              l10n.propertiesEmptyTitle,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListCard(
                  children: [
                    for (final property in page.items)
                      MmListTile(
                        leading: const Icon(MmIcons.property),
                        title: property.name,
                        subtitle: propertyPlace(property),
                        chevron: true,
                        onTap: () => setState(() => _property = property),
                      ),
                  ],
                ),
                if (page.hasMore)
                  LoadMoreButton(
                    onLoad: () => ref.read(provider.notifier).loadMore(),
                  ),
              ],
            ),
    );
  }

  Widget _units(BuildContext context, Property property) {
    final l10n = AppLocalizations.of(context);
    final provider = unitsProvider(property.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: property.name,
          actionLabel: l10n.otherPropertyAction,
          onAction: () => setState(() => _property = null),
        ),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingProperties,
          failedTitle: l10n.unitsLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 3),
          builder: (page) {
            final units = [
              for (final summary in page.items)
                if (!summary.unit.archived) summary,
            ];
            if (units.isEmpty) {
              return Text(
                l10n.unitsEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListCard(
                  children: [
                    for (final summary in units)
                      MmListTile(
                        leading: const Icon(MmIcons.unit),
                        title: summary.unit.label,
                        trailing: occupancyBadge(context, summary.occupancy),
                        onTap: () => Navigator.of(context).pop<UnitChoice>((
                          unitId: summary.unit.id,
                          unitLabel: summary.unit.label,
                          propertyId: property.id,
                          propertyName: property.name,
                        )),
                      ),
                  ],
                ),
                if (page.hasMore)
                  LoadMoreButton(
                    onLoad: () => ref.read(provider.notifier).loadMore(),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
