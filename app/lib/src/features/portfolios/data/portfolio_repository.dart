import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Portfolios and memberships. Every method throws [AppFailure].
abstract interface class PortfolioRepository {
  /// The portfolios [userId] belongs to that are not archived, by name.
  Future<List<PortfolioMembership>> listMine(String userId);

  /// Creates a portfolio named [name] with the caller as its owner.
  ///
  /// [id] is chosen by the caller once per attempt and sent again on every
  /// retry, so a request that reached the server before the connection
  /// dropped returns the same portfolio instead of creating a second one.
  /// Refusals: `portfolio_limit_reached` (20 owned), `account_deleted`,
  /// `constraint_violation` (an invalid name), and rate limits.
  Future<PortfolioMembership> create({
    required String name,
    required String id,
  });
}

/// [PortfolioRepository] over `portfolio_members` and `create_portfolio`.
final class SupabasePortfolioRepository implements PortfolioRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<PortfolioMembership>> listMine(String userId) => _guard(() async {
    // A person belongs to a handful of portfolios (at most 20 owned; see
    // docs/architecture/permissions.md on memberships), so one page.
    final rows = await _client
        .from('portfolio_members')
        .select(PortfolioMembership.columns)
        .eq('user_id', userId)
        .isFilter('portfolio.archived_at', null);
    return sortByName(rows.map(PortfolioMembership.fromRow));
  });

  @override
  Future<PortfolioMembership> create({
    required String name,
    required String id,
  }) => _guard(() async {
    final row = JsonRow.of(
      await _client.rpc<Object?>(
        'create_portfolio',
        params: {
          'p_name': sanitizeSingleLine(
            name,
            maxLength: PortfolioMembership.maxNameLength,
          ),
          'p_id': id,
        },
      ),
      'portfolio',
    );
    return PortfolioMembership(
      id: row.string('id'),
      name: row.string('name'),
      role: MemberRole.owner,
    );
  });
}

/// [memberships] by name, ignoring case, then by id so the order is stable.
List<PortfolioMembership> sortByName(
  Iterable<PortfolioMembership> memberships,
) => memberships.toList()
  ..sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => SupabasePortfolioRepository(ref.watch(supabaseClientProvider)),
);
