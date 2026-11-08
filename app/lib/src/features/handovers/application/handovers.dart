import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover_repository.dart';

/// A portfolio's cash: who holds how much and the handovers (LEDGER-11),
/// the saved copy first.
final StreamNotifierProviderFamily<
  CashBookController,
  Snapshot<CashBook>,
  String
>
cashBookProvider = StreamNotifierProvider.autoDispose
    .family<CashBookController, Snapshot<CashBook>, String>(
      CashBookController.new,
    );

/// Reads a portfolio's cash and records, confirms and voids handovers.
/// Commands throw [AppFailure].
final class CashBookController extends SwrNotifier<CashBook> {
  new(this.portfolioId);

  final String portfolioId;

  HandoverRepository get _repository => ref.read(handoverRepositoryProvider);

  @override
  String get query => 'cash.$portfolioId';

  @override
  Stream<Snapshot<CashBook>> build() {
    ref.watch(handoverRepositoryProvider);
    return super.build();
  }

  @override
  Future<CashBook> fetch() => _repository.cashBook(portfolioId);

  @override
  CashBook decode(Object? json) => CashBook.fromJson(json);

  @override
  Object? encode(CashBook value) => value.toJson();

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.handovers.next;
    if (current == null || next == null) return;
    final more = await _repository.handovers(portfolioId, before: next);
    await show(
      CashBook(
        positions: current.positions,
        handovers: current.handovers.followedBy(more),
      ),
    );
  }

  /// Records a handover ([id] names this attempt: keep it for retries).
  Future<CashHandover> record(String id, HandoverDraft draft) async {
    final handover = await _repository.record(
      id: id,
      portfolioId: portfolioId,
      draft: draft,
    );
    await reload();
    return handover;
  }

  Future<void> confirm(String handoverId) async {
    await _repository.confirm(handoverId);
    await reload();
  }

  Future<void> voidHandover(String handoverId, String reason) async {
    await _repository.voidHandover(handoverId, reason);
    await reload();
  }
}
