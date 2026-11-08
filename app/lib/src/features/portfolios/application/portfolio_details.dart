import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';

/// The settings of the portfolio whose id is the argument: the saved copy
/// at once, then the server's.
final StreamNotifierProviderFamily<
  PortfolioDetailsController,
  Snapshot<PortfolioDetails>,
  String
>
portfolioDetailsProvider = StreamNotifierProvider.autoDispose
    .family<PortfolioDetailsController, Snapshot<PortfolioDetails>, String>(
      PortfolioDetailsController.new,
    );

/// Reads a portfolio's settings and saves changes (owners only).
final class PortfolioDetailsController extends SwrNotifier<PortfolioDetails> {
  new(this.portfolioId);

  final String portfolioId;

  @override
  String get query => 'portfolio.$portfolioId';

  @override
  Stream<Snapshot<PortfolioDetails>> build() {
    ref.watch(portfolioRepositoryProvider);
    return super.build();
  }

  @override
  Future<PortfolioDetails> fetch() =>
      ref.read(portfolioRepositoryProvider).details(portfolioId);

  @override
  PortfolioDetails decode(Object? json) => PortfolioDetails.fromRow(json);

  @override
  Object? encode(PortfolioDetails value) => value.toRow();

  /// Saves [details] and shows them as stored. Throws [AppFailure]. The
  /// portfolio list is read again, so a new name shows everywhere.
  Future<PortfolioDetails> save(PortfolioDetails details) async {
    final saved = await ref
        .read(portfolioRepositoryProvider)
        .updateDetails(details);
    await show(saved);
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      try {
        await ref.read(portfoliosProvider(userId).notifier).reload();
      } on AppFailure {
        ref.invalidate(portfoliosProvider(userId));
      }
    }
    return saved;
  }
}
