import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';

/// The team of the portfolio given as the argument (with the user's role
/// in it, which decides whether invitations are read): the saved copy at
/// once, then the server's.
final StreamNotifierProviderFamily<
  TeamController,
  Snapshot<Team>,
  PortfolioMembership
>
teamProvider = StreamNotifierProvider.autoDispose
    .family<TeamController, Snapshot<Team>, PortfolioMembership>(
      TeamController.new,
    );

/// Reads a portfolio's team and changes it. Every command throws
/// [AppFailure] and, once the server has answered, shows the team as it now
/// is.
final class TeamController extends SwrNotifier<Team> {
  new(this.portfolio);

  final PortfolioMembership portfolio;

  TeamRepository get _repository => ref.read(teamRepositoryProvider);

  @override
  String get query => 'team.${portfolio.id}';

  @override
  Stream<Snapshot<Team>> build() {
    ref.watch(teamRepositoryProvider);
    return super.build();
  }

  @override
  Future<Team> fetch() async {
    final repository = _repository;
    // Only owners may see invitations; others would read none anyway.
    final owner = portfolio.role == MemberRole.owner;
    final members = await repository.members(portfolio.id);
    final invitations = owner
        ? await repository.pendingInvitations(portfolio.id)
        : const <Invitation>[];
    return Team(members: members, invitations: invitations);
  }

  @override
  Team decode(Object? json) => Team.fromJson(json);

  @override
  Object? encode(Team value) => value.toJson();

  /// Invites [email] as [role]; the e-mail is in [language].
  Future<InvitationLink> invite({
    required String email,
    required MemberRole role,
    required AppLanguage language,
  }) async {
    final link = await _repository.invite(
      portfolioId: portfolio.id,
      email: email,
      role: role,
      language: language,
    );
    await reload();
    return link;
  }

  /// Withdraws a pending invitation.
  Future<void> revoke(String invitationId) async {
    await _repository.revokeInvitation(invitationId);
    await reload();
  }

  /// Gives [userId] the [role]. When it is the user's own role, the
  /// portfolio list is read again so every screen follows.
  Future<void> changeRole(String userId, MemberRole role) async {
    final you = userId == ref.read(currentUserIdProvider);
    await _repository.changeRole(
      portfolioId: portfolio.id,
      userId: userId,
      role: role,
    );
    if (you) {
      await _reloadPortfolios(userId);
    } else {
      await reload();
    }
  }

  /// Removes [userId] from the portfolio.
  Future<void> remove(String userId) async {
    await _repository.removeMember(portfolioId: portfolio.id, userId: userId);
    await reload();
  }

  /// Leaves the portfolio. The portfolio list is read again, so the app
  /// moves to another portfolio, or asks for a first one.
  Future<void> leave() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw const SessionExpired();
    await _repository.removeMember(portfolioId: portfolio.id, userId: userId);
    await _reloadPortfolios(userId);
  }

  Future<void> _reloadPortfolios(String userId) async {
    try {
      await ref.read(portfoliosProvider(userId).notifier).reload();
    } on AppFailure {
      // The change is made; the list catches up on its next refresh.
      ref.invalidate(portfoliosProvider(userId));
    }
  }
}
