import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A portfolio that is deleted with the account, because the user is its
/// only owner.
@immutable
final class DoomedPortfolio {
  const new({required this.id, required this.name, required this.otherMembers});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'portfolio');
    return DoomedPortfolio(
      id: row.string('id'),
      name: row.string('name'),
      otherMembers: row.integer('other_members'),
    );
  }

  final String id;
  final String name;

  /// How many other people (managers, accountants, viewers) lose it.
  final int otherMembers;

  @override
  bool operator ==(Object other) =>
      other is DoomedPortfolio &&
      other.id == id &&
      other.name == name &&
      other.otherMembers == otherMembers;

  @override
  int get hashCode => Object.hash(id, name, otherMembers);
}

/// What deleting the account would do, from `GET delete-account`.
@immutable
final class DeletionPreview {
  const new({
    required this.portfoliosToDelete,
    required this.reauthMaxAge,
    required this.secondFactorRequired,
  });

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'preview');
    return DeletionPreview(
      portfoliosToDelete: [
        for (final item in row.list('portfolios_to_delete'))
          DoomedPortfolio.fromJson(item),
      ],
      reauthMaxAge: Duration(seconds: row.integer('reauth_max_age_seconds')),
      secondFactorRequired: row.boolean('second_factor_required'),
    );
  }

  /// Deleted with the account; from every other portfolio the user is only
  /// removed.
  final List<DoomedPortfolio> portfoliosToDelete;

  /// How recent the sign-in before deleting must be.
  final Duration reauthMaxAge;

  /// The account has a verified second factor, which this app cannot
  /// present yet.
  final bool secondFactorRequired;

  @override
  bool operator ==(Object other) =>
      other is DeletionPreview &&
      listEquals(other.portfoliosToDelete, portfoliosToDelete) &&
      other.reauthMaxAge == reauthMaxAge &&
      other.secondFactorRequired == secondFactorRequired;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(portfoliosToDelete),
    reauthMaxAge,
    secondFactorRequired,
  );
}

/// The account itself. Every method throws [AppFailure].
abstract interface class AccountRepository {
  Future<DeletionPreview> deletionPreview();

  /// Deletes the account for good: the portfolios it owns alone with
  /// everything in them, and its memberships elsewhere. The sign-in must be
  /// recent (see [DeletionPreview.reauthMaxAge]) and [confirmEmail] must be
  /// the account's address. Returns how many portfolios were deleted.
  Future<int> deleteAccount({required String confirmEmail});
}

/// [AccountRepository] over the `delete-account` Edge Function.
final class SupabaseAccountRepository implements AccountRepository {
  new(this._client);

  static const _function = 'delete-account';

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<DeletionPreview> deletionPreview() => _guard(() async {
    final response = await _client.functions.invoke(
      _function,
      method: HttpMethod.get,
    );
    return DeletionPreview.fromJson(response.data);
  });

  @override
  Future<int> deleteAccount({required String confirmEmail}) => _guard(() async {
    final response = await _client.functions.invoke(
      _function,
      body: {'confirm_email': confirmEmail.trim()},
    );
    final row = JsonRow.of(response.data, 'deletion');
    if (!row.boolean('deleted')) {
      throw const FormatException('the account was not deleted');
    }
    return row.list('deleted_portfolio_ids').length;
  });
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);
