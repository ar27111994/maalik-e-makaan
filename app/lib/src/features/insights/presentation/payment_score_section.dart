import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_labels.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/reports_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_ui/mm_ui.dart';

/// A tenant's payment score on their screen (INS-03): the gauge, its band
/// in words, what it is made of, and how it is worked out.
class PaymentScoreSection extends ConsumerWidget {
  const new({required this.tenantId, super.key});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium!.copyWith(color: context.mm.colors.inkMuted);
    final scores = ref.watch(paymentScoresProvider(portfolio.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.scoreSectionTitle),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: switch (scores) {
            AsyncValue(value: final byTenant?) => switch (byTenant[tenantId]) {
              final score? => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: MmScoreGauge(
                      score: score.score,
                      bandLabel: scoreBandLabel(
                        l10n,
                        MmScoreBand.of(score.score),
                      ),
                      semanticLabel: l10n.scoreSpoken(
                        '${score.score}',
                        scoreBandLabel(l10n, MmScoreBand.of(score.score)),
                      ),
                      caption: detailLine(scoreLines(context, score).skip(1)),
                    ),
                  ),
                  const SizedBox(height: MmSpace.s3),
                  Text(l10n.scoreFormulaHelp, style: muted),
                ],
              ),
              null => Text(l10n.scoreNotYet, style: text.bodyLarge),
            },
            AsyncValue(:final error?) => MmErrorState(
              title: l10n.scoresLoadFailedTitle,
              message: failureMessage(l10n, AppFailure.from(error)),
              onRetry: () => ref.invalidate(paymentFactsProvider(portfolio.id)),
            ),
            _ => Semantics(
              container: true,
              label: l10n.loadingScores,
              child: const MmSkeleton.text(lines: 3),
            ),
          },
        ),
      ],
    );
  }
}
