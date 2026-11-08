import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Global search (SRCH-01): properties, units and tenants of the current
/// portfolio matching what is typed (a name, a locality or city, a phone
/// number or a CNIC), the best match first, each leading to its screen.
class SearchScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// How long typing pauses before the search runs (a typing pause, not
  /// motion, so not an MmDuration).
  // design-lint: allow-next-line typing pause, not motion
  static const searchDelay = Duration(milliseconds: 300);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _searchFor(String text) {
    _debounce?.cancel();
    _debounce = Timer(SearchScreen.searchDelay, () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final text = Theme.of(context).textTheme;
    return MmPage(
      title: l10n.searchTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmSearchField(
            hint: l10n.searchHint,
            autofocus: true,
            onChanged: _searchFor,
            onSubmitted: (text) {
              _debounce?.cancel();
              setState(() => _query = text.trim());
            },
          ),
          const SizedBox(height: MmSpace.s4),
          if (portfolio == null)
            const SizedBox.shrink()
          else if (_query.isEmpty)
            Text(l10n.searchIntro, style: text.bodyLarge)
          else if (_query.runes.length < minSearchLength)
            Text(l10n.searchTooShort, style: text.bodyLarge)
          else
            _Results(
              search: (portfolioId: portfolio.id, query: searchQuery(_query)),
            ),
        ],
      ),
    );
  }
}

/// [typed], trimmed, as the server reads it: `search_portfolio` counts
/// code points (`char_length`), not the letters on screen (an Urdu letter
/// with a diacritic is two), and reads at most [maxSearchLength] of them.
/// The cut never splits a code point.
String searchQuery(String typed) {
  final runes = typed.trim().runes;
  return runes.length <= maxSearchLength
      ? typed.trim()
      : String.fromCharCodes(runes.take(maxSearchLength)).trimRight();
}

class _Results extends ConsumerWidget {
  const new({required this.search});

  final SearchOf search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = searchProvider(search);
    // Each search is its own query: while one runs, its skeleton shows.
    return ref
        .watch(provider)
        .when(
          data: (results) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Said to screen readers as the results arrive: the list
              // below the field changes while the focus stays in it.
              Semantics(
                liveRegion: true,
                child: results.isEmpty
                    ? MmEmptyState(
                        icon: MmIcons.search,
                        title: l10n.searchNoMatches(
                          inSentence(search.query, Directionality.of(context)),
                        ),
                        message: l10n.searchNoMatchesBody,
                      )
                    : Text(
                        l10n.searchResultCount(results.length),
                        style: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: context.mm.colors.inkMuted),
                      ),
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: MmSpace.s2),
                ListCard(
                  children: [
                    for (final result in results) SearchResultTile(result),
                  ],
                ),
              ],
            ],
          ),
          error: (error, _) => MmErrorState(
            title: l10n.searchFailedTitle,
            message: failureMessage(l10n, AppFailure.from(error)),
            onRetry: () => ref.invalidate(provider),
          ),
          loading: () => Semantics(
            container: true,
            label: l10n.searching,
            child: const MmSkeletonList(itemCount: 3),
          ),
        );
  }
}

/// A search result: what it is, its name and a line about it, leading to
/// its screen.
class SearchResultTile extends StatelessWidget {
  const new(this.result, {super.key});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final kind = switch (result.kind) {
      SearchKind.property => l10n.propertyLabel,
      SearchKind.unit => l10n.unitLabel,
      SearchKind.tenant => l10n.tenantLabel,
    };
    final subtitle = result.subtitle;
    // A tenant's line is their phone number, shown as it is dialled here.
    final detail = subtitle == null
        ? null
        : switch (result.kind) {
            SearchKind.tenant => switch (PhoneNumber.tryParse(subtitle)) {
              final phone? => phoneLabel(phone, direction),
              null => inSentence(subtitle, direction),
            },
            _ => inSentence(subtitle, direction),
          };
    final propertyId = result.propertyId;
    final route = switch (result.kind) {
      SearchKind.property => Routes.property(result.id),
      SearchKind.tenant => Routes.tenant(result.id),
      SearchKind.unit when propertyId != null => Routes.unit(
        propertyId,
        result.id,
      ),
      // The unit's property could not be read: its screen cannot be found.
      SearchKind.unit => null,
    };
    return MmListTile(
      leading: Icon(switch (result.kind) {
        SearchKind.property => MmIcons.property,
        SearchKind.unit => MmIcons.unit,
        SearchKind.tenant => MmIcons.person,
      }),
      title: result.title,
      subtitle: appText(
        detail == null ? kind : l10n.searchResultLine(kind, detail),
        direction,
      ),
      subtitleMaxLines: 4,
      trailing: route == null ? null : const Icon(MmIcons.chevronEnd),
      onTap: route == null ? null : () => context.go(route),
    );
  }
}
