import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Where an invitation e-mail's link lands (`/invite#token=…`, TEAM-03).
///
/// The router keeps the token on the device and sends a signed-out person
/// to sign in or create an account first. Here the invitation is accepted
/// at once (they followed the link to accept it): the screen then welcomes
/// them to the portfolio, or says plainly why the invitation cannot be
/// used and what to do. A lost connection keeps the invitation to try
/// again.
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen>
    with CommandState {
  AcceptOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(pendingInvitationProvider) != null) {
        unawaited(_accept());
      }
    });
  }

  Future<void> _accept() async {
    late AcceptOutcome outcome;
    final done = await runCommand(() async {
      outcome = await ref.read(pendingInvitationProvider.notifier).accept();
    });
    if (done && mounted) setState(() => _outcome = outcome);
  }

  Future<void> _setAside() async {
    await ref.read(pendingInvitationProvider.notifier).clear();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outcome = _outcome;
    final failure = this.failure;
    final pending = ref.watch(pendingInvitationProvider) != null;
    // A link just opened is kept on the device a moment after this screen
    // first builds: answer it then.
    ref.listen(pendingInvitationProvider, (previous, next) {
      if (previous == null && next != null && _outcome == null && !busy) {
        unawaited(_accept());
      }
    });
    // Keeps the portfolio list read while the invitation is answered, so
    // the portfolio joined is named as soon as it is listed.
    final userId = ref.watch(currentUserIdProvider);
    if (userId != null) ref.listen(portfoliosProvider(userId), (_, _) {});
    final Widget body;
    if (outcome is InvitationAccepted) {
      body = _Accepted(outcome: outcome);
    } else if (outcome is InvitationRefused) {
      body = _Refused(reason: outcome.reason, onSetAside: _setAside);
    } else if (failure != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmErrorState(
            title: l10n.invitationNotAcceptedTitle,
            message: failureMessage(l10n, failure),
            onRetry: _accept,
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.notNowAction,
            variant: MmButtonVariant.tertiary,
            onPressed: _setAside,
          ),
        ],
      );
    } else if (busy || pending) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: MmSpace.s8),
          const CircularProgressIndicator(),
          const SizedBox(height: MmSpace.s4),
          Text(
            l10n.acceptingInvitation,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      body = MmEmptyState(
        icon: MmIcons.invite,
        title: l10n.acceptInvitationTitle,
        message: l10n.noInvitationBody,
        actionLabel: l10n.goToAppAction,
        onAction: () => context.go(Routes.home),
      );
    }
    return MmPage(title: l10n.acceptInvitationTitle, body: body);
  }
}

class _Accepted extends ConsumerWidget {
  const new({required this.outcome});

  final InvitationAccepted outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final memberships = userId == null
        ? null
        : ref.watch(portfoliosProvider(userId)).value?.value;
    String? name;
    for (final membership in memberships ?? const <PortfolioMembership>[]) {
      if (membership.id == outcome.portfolioId) name = membership.name;
    }
    return MmEmptyState(
      icon: MmIcons.success,
      title: name == null
          ? l10n.invitationAcceptedNoName
          : l10n.invitationAcceptedTitle(
              inSentence(name, Directionality.of(context)),
            ),
      message: l10n.invitationAcceptedBody(roleLabel(l10n, outcome.role)),
      actionLabel: l10n.openPortfolioAction,
      onAction: () => context.go(Routes.home),
    );
  }
}

class _Refused extends ConsumerWidget {
  const new({required this.reason, required this.onSetAside});

  final InvitationRefusal reason;

  /// Forgets the invitation and goes to the app.
  final VoidCallback onSetAside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final message = switch (reason) {
      InvitationRefusal.invalid => l10n.invitationInvalidBody,
      InvitationRefusal.revoked => l10n.invitationRevokedBody,
      InvitationRefusal.alreadyUsed => l10n.invitationAlreadyUsedBody,
      InvitationRefusal.expired => l10n.invitationExpiredBody,
      InvitationRefusal.emailNotVerified => l10n.invitationEmailNotVerifiedBody,
      InvitationRefusal.emailMismatch => l10n.invitationEmailMismatchBody,
      InvitationRefusal.unknown => l10n.invitationUnknownBody,
    };
    final status = ref.watch(authStatusProvider);
    final email = status is SignedIn ? status.email : null;
    final mismatch = reason == InvitationRefusal.emailMismatch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmEmptyState(
          icon: MmIcons.warning,
          title: l10n.invitationFailedTitle,
          message: message,
          actionLabel: l10n.goToAppAction,
          onAction: onSetAside,
        ),
        if (mismatch && email != null) ...[
          const SizedBox(height: MmSpace.s4),
          MmDetailRow(label: l10n.signedInAs, value: breakableEmail(email)),
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.signOutAction,
            icon: MmIcons.signOut,
            variant: MmButtonVariant.secondary,
            onPressed: () => ref.read(authStatusProvider.notifier).signOut(),
          ),
        ],
      ],
    );
  }
}
