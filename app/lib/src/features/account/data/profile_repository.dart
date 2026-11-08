import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in user's profile. Every method throws [AppFailure].
abstract interface class ProfileRepository {
  Future<Profile> fetch(String userId);

  /// Saves the name and phone (the columns a client may change besides the
  /// language) and returns the profile as stored.
  Future<Profile> updateDetails(
    String userId, {
    required String fullName,
    required PhoneNumber? phone,
  });

  /// Saves the app language, so e-mails and reminders the server sends use
  /// it too.
  Future<void> updateLanguage(String userId, AppLanguage language);
}

/// [ProfileRepository] over `public.profiles`, where a client may update
/// only `full_name`, `phone` and `locale` of its own row.
final class SupabaseProfileRepository implements ProfileRepository {
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
  Future<Profile> fetch(String userId) => _guard(() async {
    final row = await _client
        .from('profiles')
        .select(Profile.columns)
        .eq('id', userId)
        .single();
    return Profile.fromRow(row);
  });

  @override
  Future<Profile> updateDetails(
    String userId, {
    required String fullName,
    required PhoneNumber? phone,
  }) => _guard(() async {
    final row = await _client
        .from('profiles')
        .update({
          'full_name': singleLineWithin(fullName, Profile.maxNameLength),
          'phone': phone?.e164,
        })
        .eq('id', userId)
        .select(Profile.columns)
        .single();
    return Profile.fromRow(row);
  });

  @override
  Future<void> updateLanguage(String userId, AppLanguage language) =>
      _guard(() async {
        await _client
            .from('profiles')
            .update({'locale': language.code})
            .eq('id', userId);
      });
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);
