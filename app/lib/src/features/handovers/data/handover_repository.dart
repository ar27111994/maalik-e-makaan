import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cash handovers and positions. Every method throws [AppFailure].
///
/// Owners, managers and accountants record handovers (as the giver; an
/// owner records any); owners confirm and void them.
abstract interface class HandoverRepository {
  Future<CashBook> cashBook(String portfolioId);

  /// The page of handovers before [before], newest first.
  Future<Paged<CashHandover>> handovers(
    String portfolioId, {
    PageCursor? before,
  });

  /// Records [draft] under the id chosen for this attempt.
  Future<CashHandover> record({
    required String id,
    required String portfolioId,
    required HandoverDraft draft,
  });

  /// Refusal: `already_voided`.
  Future<CashHandover> confirm(String handoverId);

  /// Refusals: `reason_required`, `already_voided`.
  Future<CashHandover> voidHandover(String handoverId, String reason);
}

/// [HandoverRepository] over `cash_handovers` and its functions.
final class SupabaseHandoverRepository implements HandoverRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<Paged<CashHandover>> _page(
    String portfolioId,
    PageCursor? before,
  ) async {
    final rows = await _client
        .from('cash_handovers')
        .select(CashHandover.columns)
        .eq('portfolio_id', portfolioId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(CashHandover.fromRow).toList(), (h) => h.cursor);
  }

  @override
  Future<CashBook> cashBook(String portfolioId) => _guard(() async {
    final (positions, handovers) = await (
      _client.rpc<List<dynamic>>(
        'get_cash_positions',
        params: {'p_portfolio_id': portfolioId},
      ),
      _page(portfolioId, null),
    ).wait;
    return CashBook(
      positions: positions.map(CashPosition.fromRow).toList(),
      handovers: handovers,
    );
  });

  @override
  Future<Paged<CashHandover>> handovers(
    String portfolioId, {
    PageCursor? before,
  }) => _guard(() => _page(portfolioId, before));

  @override
  Future<CashHandover> record({
    required String id,
    required String portfolioId,
    required HandoverDraft draft,
  }) => _guard(() async {
    try {
      final row = await _client
          .from('cash_handovers')
          .insert({'id': id, 'portfolio_id': portfolioId, ...draft.toWrite()})
          .select(CashHandover.columns)
          .single();
      return CashHandover.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A retry of an insert that reached the server.
      final row = await _client
          .from('cash_handovers')
          .select(CashHandover.columns)
          .eq('id', id)
          .single();
      return CashHandover.fromRow(row);
    }
  });

  @override
  Future<CashHandover> confirm(String handoverId) => _guard(() async {
    final row = await _client.rpc<Object?>(
      'confirm_cash_handover',
      params: {'p_handover_id': handoverId},
    );
    return CashHandover.fromRow(row);
  });

  @override
  Future<CashHandover> voidHandover(String handoverId, String reason) =>
      _guard(() async {
        final row = await _client.rpc<Object?>(
          'void_cash_handover',
          params: {
            'p_handover_id': handoverId,
            'p_reason': sanitizeSingleLine(
              reason,
              maxLength: Charge.maxReasonLength,
            ),
          },
        );
        return CashHandover.fromRow(row);
      });
}

final handoverRepositoryProvider = Provider<HandoverRepository>(
  (ref) => SupabaseHandoverRepository(ref.watch(supabaseClientProvider)),
);
