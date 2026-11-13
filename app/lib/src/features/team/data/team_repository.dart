import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A portfolio's members and invitations. Every method throws [AppFailure].
///
/// Membership changes go through the database's functions, which check the
/// caller's role and keep a portfolio's last owner (`last_owner`).
abstract interface class TeamRepository {
  /// The members of [portfolioId] with their names, owners first.
  Future<List<TeamMember>> members(String portfolioId);

  /// The invitations of [portfolioId] neither accepted nor revoked, newest
  /// first. Only owners see any (the database shows others none).
  Future<List<Invitation>> pendingInvitations(String portfolioId);

  /// Invites [email] as [role] (owners only) through `invite-member`, which
  /// e-mails the link in [language] when it can and returns it either way.
  /// An earlier pending invitation of the address is replaced.
  ///
  /// Refusals: `already_member`, `invalid_email` (also `not_an_email`),
  /// `invalid_role`, [Forbidden] and rate limits.
  Future<InvitationLink> invite({
    required String portfolioId,
    required String email,
    required MemberRole role,
    required AppLanguage language,
  });

  /// Withdraws a pending invitation (owners only).
  Future<void> revokeInvitation(String invitationId);

  /// Gives [userId] the [role] in [portfolioId] (owners only). Refusals:
  /// `last_owner`, `member_not_found`, `invalid_role`.
  Future<void> changeRole({
    required String portfolioId,
    required String userId,
    required MemberRole role,
  });

  /// Removes [userId] from [portfolioId]: owners remove anyone, everyone
  /// may remove themselves (leave). Refusals: `last_owner`,
  /// `member_not_found`.
  Future<void> removeMember({
    required String portfolioId,
    required String userId,
  });

  /// Accepts the invitation [token] (`<id>.<verifier>`) for the signed-in
  /// user. Most refusals are an [InvitationRefused] answer, not a throw.
  Future<AcceptOutcome> accept(String token);

  /// Names [userId], a manager of [portfolioId], its caretaker, or clears
  /// the caretaker when [userId] is null (owners only). Naming the current
  /// caretaker again changes nothing. Refusals: `member_not_found`,
  /// `caretaker_not_manager`, [Forbidden].
  Future<void> setCaretaker({
    required String portfolioId,
    required String? userId,
  });
}

/// [TeamRepository] over `portfolio_members`, `profiles`,
/// `portfolio_invitations`, their functions and `invite-member`.
final class SupabaseTeamRepository implements TeamRepository {
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
  Future<List<TeamMember>> members(String portfolioId) => _guard(() async {
    // A portfolio has a handful of people, so one page. Profiles are read
    // separately: memberships point at auth.users, not at profiles.
    final rows = await _client
        .from('portfolio_members')
        .select(TeamMember.columns)
        .eq('portfolio_id', portfolioId);
    if (rows.isEmpty) return const [];
    final ids = [for (final row in rows) row['user_id']];
    final profiles = await _client
        .from('profiles')
        .select(TeamMember.profileColumns)
        .inFilter('id', ids);
    final byId = {for (final profile in profiles) profile['id']: profile};
    return sortMembers([
      for (final row in rows) TeamMember.fromRows(row, byId[row['user_id']]),
    ]);
  });

  @override
  Future<List<Invitation>> pendingInvitations(String portfolioId) =>
      _guard(() async {
        final rows = await _client
            .from('portfolio_invitations')
            .select(Invitation.columns)
            .eq('portfolio_id', portfolioId)
            .isFilter('accepted_at', null)
            .isFilter('revoked_at', null)
            .order('created_at', ascending: false);
        return [for (final row in rows) Invitation.fromRow(row)];
      });

  @override
  Future<InvitationLink> invite({
    required String portfolioId,
    required String email,
    required MemberRole role,
    required AppLanguage language,
  }) => _guard(() async {
    try {
      final response = await _client.functions.invoke(
        'invite-member',
        body: {
          'portfolio_id': portfolioId,
          'email': email.trim().toLowerCase(),
          'role': role.name,
          'locale': language.code,
        },
      );
      return InvitationLink.fromJson(response.data);
    } on FunctionException catch (error) {
      // The function names a malformed address by its field check.
      final failure = AppFailure.from(error);
      if (failure is RejectedFailure && failure.reason == 'not_an_email') {
        throw const RejectedFailure('invalid_email');
      }
      throw failure;
    }
  });

  @override
  Future<void> revokeInvitation(String invitationId) => _guard(() async {
    await _client.rpc<void>(
      'revoke_invitation',
      params: {'p_invitation_id': invitationId},
    );
  });

  @override
  Future<void> changeRole({
    required String portfolioId,
    required String userId,
    required MemberRole role,
  }) => _guard(() async {
    await _client.rpc<void>(
      'update_member_role',
      params: {
        'p_portfolio_id': portfolioId,
        'p_user_id': userId,
        'p_role': role.name,
      },
    );
  });

  @override
  Future<void> removeMember({
    required String portfolioId,
    required String userId,
  }) => _guard(() async {
    await _client.rpc<void>(
      'remove_member',
      params: {'p_portfolio_id': portfolioId, 'p_user_id': userId},
    );
  });

  @override
  Future<AcceptOutcome> accept(String token) => _guard(() async {
    final answer = await _client.rpc<Object?>(
      'accept_invitation',
      params: {'p_token': token},
    );
    return AcceptOutcome.fromJson(answer);
  });

  @override
  Future<void> setCaretaker({
    required String portfolioId,
    required String? userId,
  }) => _guard(() async {
    await _client.rpc<void>(
      'set_caretaker',
      params: {'p_portfolio_id': portfolioId, 'p_user_id': userId},
    );
  });
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => SupabaseTeamRepository(ref.watch(supabaseClientProvider)),
);
