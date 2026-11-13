import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in user's declared residence. Every method throws
/// [AppFailure].
abstract interface class ResidenceRepository {
  /// The residence of [userId] (every account has one, at first empty).
  Future<AccountResidence> fetch(String userId);

  /// Saves the country and the zone the user chose (either may be null:
  /// not stated) and returns them as stored, with the time the server
  /// stamped. Refusals: `account_deleted` (the account's deletion has
  /// started), `constraint_violation` (a country or zone the database does
  /// not store).
  Future<AccountResidence> update(
    String userId, {
    required CountryCode? country,
    required TimeZoneId? timeZone,
  });
}

/// [ResidenceRepository] over `public.profile_residences`, where a client
/// reads and updates only its own row, and only `residence_country` and
/// `time_zone` (`stated_at` is the server's).
final class SupabaseResidenceRepository implements ResidenceRepository {
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
  Future<AccountResidence> fetch(String userId) => _guard(() async {
    final row = await _client
        .from('profile_residences')
        .select(AccountResidence.columns)
        .eq('user_id', userId)
        .single();
    return AccountResidence.fromRow(row);
  });

  @override
  Future<AccountResidence> update(
    String userId, {
    required CountryCode? country,
    required TimeZoneId? timeZone,
  }) => _guard(() async {
    final row = await _client
        .from('profile_residences')
        .update({
          'residence_country': country?.code,
          'time_zone': timeZone?.name,
        })
        .eq('user_id', userId)
        .select(AccountResidence.columns)
        .single();
    return AccountResidence.fromRow(row);
  });
}

final residenceRepositoryProvider = Provider<ResidenceRepository>(
  (ref) => SupabaseResidenceRepository(ref.watch(supabaseClientProvider)),
);
