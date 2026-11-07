import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/saved_at.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:mm_ui/mm_ui.dart';

/// Says why the data on screen may be stale, when a refresh failed while a
/// saved copy is shown: "You are offline. Showing what was saved at …"
/// for a lost connection, otherwise the failure with a retry. Nothing when
/// the data is fresh or still loading.
class RefreshNotice<T> extends StatelessWidget {
  const new({required this.state, required this.onRetry, super.key});

  final AsyncValue<Snapshot<T>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.value;
    final error = state.error;
    if (snapshot == null || error == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final failure = AppFailure.from(error);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
      child: failure is NetworkFailure
          ? MmBanner(
              tone: MmBannerTone.warning,
              message: l10n.offlineShowingSaved(
                savedAtLabel(context, snapshot.savedAt),
              ),
              actionLabel: l10n.retryAction,
              onAction: onRetry,
            )
          : MmBanner(
              tone: MmBannerTone.error,
              message: failureMessage(l10n, failure),
              actionLabel: l10n.retryAction,
              onAction: onRetry,
            ),
    );
  }
}
