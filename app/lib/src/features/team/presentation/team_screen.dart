import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/invite_member_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/roles.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:maalik_e_makaan/src/shell/refresh_when_shown.dart';
import 'package:mm_ui/mm_ui.dart';

/// The people of the current portfolio (TEAM-02 to TEAM-04): every member
/// with their role, and for owners the invitations waiting for an answer,
/// with ways to invite, change roles, remove members and withdraw
/// invitations. Everyone may leave, except the last owner.
class TeamScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) {
      return MmPage(title: l10n.teamTitle, body: const _Loading());
    }
    final state = ref.watch(teamProvider(portfolio));
    void retry() => ref.invalidate(teamProvider(portfolio));
    final team = state.value?.value;
    final owner = portfolio.role == MemberRole.owner;
    // Kept alive in the More tab: what others did meanwhile (an invitation
    // accepted, a member who left) shows when the screen comes back.
    return RefreshWhenShown(
      onShown: () =>
          unawaited(ref.read(teamProvider(portfolio).notifier).reload()),
      child: MmPage(
        title: l10n.teamTitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefreshNotice(state: state, onRetry: retry),
            if (team != null)
              _TeamBody(portfolio: portfolio, team: team)
            else if (state.error case final error?)
              MmErrorState(
                title: l10n.teamLoadFailedTitle,
                message: failureMessage(l10n, AppFailure.from(error)),
                onRetry: retry,
              )
            else
              const _Loading(),
          ],
        ),
        bottomBar: owner
            ? MmActionBar(
                primary: MmButton(
                  label: l10n.inviteAction,
                  icon: MmIcons.invite,
                  onPressed: () => context.go(Routes.inviteMember),
                ),
              )
            : null,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loadingTeam,
    child: const MmSkeletonList(itemCount: 4),
  );
}

class _TeamBody extends ConsumerWidget {
  const new({required this.portfolio, required this.team});

  final PortfolioMembership portfolio;
  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final owner = portfolio.role == MemberRole.owner;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.teamMembersSection),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          padding: EdgeInsetsDirectional.zero,
          child: Column(
            children: [
              for (final (index, member) in team.members.indexed) ...[
                if (index > 0) const Divider(height: MmSize.hairline),
                _MemberTile(
                  member: member,
                  you: member.userId == userId,
                  onTap: owner
                      ? () => _openMember(
                          context,
                          member,
                          you: member.userId == userId,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (owner && team.invitations.isNotEmpty) ...[
          const SizedBox(height: MmSpace.s8),
          MmSectionHeader(
            title: l10n.teamInvitationsSection,
            subtitle: l10n.teamInvitationsHelp,
          ),
          const SizedBox(height: MmSpace.s2),
          MmCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              children: [
                for (final (index, invitation) in team.invitations.indexed) ...[
                  if (index > 0) const Divider(height: MmSize.hairline),
                  _InvitationTile(
                    invitation: invitation,
                    expired: invitation.isExpired(now),
                    onTap: () => _openInvitation(context, invitation),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: MmSpace.s8),
        _Leave(portfolio: portfolio, team: team),
      ],
    );
  }

  Future<void> _openMember(
    BuildContext context,
    TeamMember member, {
    required bool you,
  }) => showMmSheet<void>(
    context,
    title: breakableEmail(memberName(AppLocalizations.of(context), member)),
    // A name or address as the member typed it, in its own script's face.
    userTitle: true,
    builder: (context) => MemberSheet(
      portfolio: portfolio,
      member: member,
      onlyOwner:
          member.role == MemberRole.owner && team.count(MemberRole.owner) == 1,
      you: you,
    ),
  );

  Future<void> _openInvitation(BuildContext context, Invitation invitation) =>
      showMmSheet<void>(
        context,
        title: breakableEmail(invitation.email),
        userTitle: true,
        builder: (context) =>
            InvitationSheet(portfolio: portfolio, invitation: invitation),
      );
}

class _MemberTile extends StatelessWidget {
  const new({required this.member, required this.you, required this.onTap});

  final TeamMember member;
  final bool you;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = memberName(l10n, member);
    final role = roleLabel(l10n, member.role);
    final email = member.email;
    final direction = Directionality.of(context);
    return MmListTile(
      leading: MmAvatar(name: name),
      title: you
          ? l10n.memberYou(inSentence(breakableEmail(name), direction))
          : breakableEmail(name),
      subtitle: email == null || email == name
          ? role
          : l10n.memberRoleAndEmail(
              role,
              inSentence(breakableEmail(email), direction),
            ),
      // A long address wraps as far as it needs, never cut short.
      subtitleMaxLines: null,
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const new({
    required this.invitation,
    required this.expired,
    required this.onTap,
  });

  final Invitation invitation;
  final bool expired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = roleLabel(l10n, invitation.role);
    final date = dateLabel(context, pakistanDate(invitation.expiresAt));
    return MmListTile(
      leading: const Icon(MmIcons.email),
      title: breakableEmail(invitation.email),
      subtitle: expired
          ? l10n.invitationExpired(role, date)
          : l10n.invitationExpires(role, date),
      subtitleMaxLines: 4,
      trailing: expired
          ? MmStatusBadge(
              status: MmStatus.neutral,
              icon: MmIcons.clock,
              label: l10n.invitationExpiredBadge,
            )
          : null,
      chevron: !expired,
      onTap: onTap,
    );
  }
}

/// Leaving the portfolio, or why the last owner cannot.
class _Leave extends ConsumerStatefulWidget {
  const new({required this.portfolio, required this.team});

  final PortfolioMembership portfolio;
  final Team team;

  @override
  ConsumerState<_Leave> createState() => _LeaveState();
}

class _LeaveState extends ConsumerState<_Leave> with CommandState {
  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(widget.portfolio.name, Directionality.of(context));
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.leaveTitle(name),
      message: l10n.leaveBody,
      confirmLabel: l10n.leaveAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref.read(teamProvider(widget.portfolio).notifier).leave(),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.leftPortfolio(name),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastOwner =
        widget.portfolio.role == MemberRole.owner &&
        widget.team.count(MemberRole.owner) <= 1;
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (lastOwner)
          Text(
            l10n.leaveLastOwner,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.mm.colors.inkMuted),
          ),
        if (lastOwner) const SizedBox(height: MmSpace.s2),
        MmButton(
          label: l10n.leaveAction,
          icon: MmIcons.signOut,
          variant: MmButtonVariant.tertiary,
          busy: busy,
          onPressed: lastOwner ? null : _leave,
        ),
      ],
    );
  }
}

/// What an owner can do with a member: change their role, or remove them
/// (themselves they leave instead).
class MemberSheet extends ConsumerStatefulWidget {
  const new({
    required this.portfolio,
    required this.member,
    required this.onlyOwner,
    required this.you,
    super.key,
  });

  final PortfolioMembership portfolio;
  final TeamMember member;

  /// The member is the portfolio's only owner, whose role cannot change.
  final bool onlyOwner;

  /// The member is the signed-in user.
  final bool you;

  @override
  ConsumerState<MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<MemberSheet> with CommandState {
  late MemberRole _role = widget.member.role;

  TeamController get _team => ref.read(teamProvider(widget.portfolio).notifier);

  Future<void> _changeRole() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(
      memberName(l10n, widget.member),
      Directionality.of(context),
    );
    final role = _role;
    final done = await runCommand(
      () => _team.changeRole(widget.member.userId, role),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.roleChanged(name, roleLabel(l10n, role)),
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(
      memberName(l10n, widget.member),
      Directionality.of(context),
    );
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.removeMemberTitle(name),
      message: l10n.removeMemberBody,
      confirmLabel: l10n.removeMemberAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(() => _team.remove(widget.member.userId));
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.memberRemoved(name),
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final email = widget.member.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (email != null) ...[
          MmDetailRow(label: l10n.emailLabel, value: breakableEmail(email)),
          const SizedBox(height: MmSpace.s4),
        ],
        if (widget.onlyOwner)
          MmBanner(tone: MmBannerTone.info, message: l10n.onlyOwnerNote)
        else ...[
          MmRadioGroup<MemberRole>(
            label: l10n.memberRoleLabel,
            options: roleOptions(l10n),
            value: _role,
            onChanged: (role) {
              if (role != null) setState(() => _role = role);
            },
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.changeRoleAction,
            busy: busy,
            onPressed: _role == widget.member.role ? null : _changeRole,
          ),
        ],
        if (!widget.you && !widget.onlyOwner) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.removeMemberAction,
            icon: MmIcons.delete,
            // It asks first: the dialog's button is the filled one.
            variant: MmButtonVariant.destructiveOutlined,
            onPressed: busy ? null : _remove,
          ),
        ],
      ],
    );
  }
}

/// What an owner can do with a pending invitation: send it again (a new
/// link, as the old one is not kept) or withdraw it.
class InvitationSheet extends ConsumerStatefulWidget {
  const new({required this.portfolio, required this.invitation, super.key});

  final PortfolioMembership portfolio;
  final Invitation invitation;

  @override
  ConsumerState<InvitationSheet> createState() => _InvitationSheetState();
}

class _InvitationSheetState extends ConsumerState<InvitationSheet>
    with CommandState {
  Future<void> _revoke() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.revokeInvitationTitle(
        inSentence(
          breakableEmail(widget.invitation.email),
          Directionality.of(context),
        ),
      ),
      message: l10n.revokeInvitationBody,
      confirmLabel: l10n.revokeInvitationAction,
      // "Cancel" beside cancelling the invitation would be ambiguous.
      cancelLabel: l10n.keepInvitationAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref
          .read(teamProvider(widget.portfolio).notifier)
          .revoke(widget.invitation.id),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.invitationCancelled,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  void _inviteAgain() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(
      Routes.inviteMember,
      extra: InviteDraft(
        email: widget.invitation.email,
        role: widget.invitation.role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final invitation = widget.invitation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmDetailRow(
          label: l10n.memberRoleLabel,
          value: roleLabel(l10n, invitation.role),
          userData: false,
        ),
        MmDetailRow(
          label: l10n.invitationWorksUntil,
          value: invitation.isExpired(DateTime.now())
              ? l10n.invitationExpiredBadge
              : momentLabel(context, invitation.expiresAt),
          userData: false,
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.inviteAgainAction,
          icon: MmIcons.send,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : _inviteAgain,
        ),
        const SizedBox(height: MmSpace.s3),
        MmButton(
          label: l10n.revokeInvitationAction,
          icon: MmIcons.close,
          // It asks first: the dialog's button is the filled one.
          variant: MmButtonVariant.destructiveOutlined,
          busy: busy,
          onPressed: _revoke,
        ),
      ],
    );
  }
}
