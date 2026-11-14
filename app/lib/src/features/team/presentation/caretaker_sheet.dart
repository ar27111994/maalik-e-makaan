import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/roles.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// The members of [team] who may be named the caretaker (its managers), by
/// name.
List<TeamMember> caretakerCandidates(Team team) {
  String key(TeamMember member) =>
      (member.fullName.isNotEmpty ? member.fullName : member.email ?? '')
          .toLowerCase();
  return [
    for (final member in team.members)
      if (member.role.canBeCaretaker) member,
  ]..sort((a, b) => key(a).compareTo(key(b)));
}

/// Lets an owner of [portfolio] name its caretaker, one of its managers,
/// or name none; [current] is the caretaker's user id, if any.
Future<void> showCaretakerSheet(
  BuildContext context, {
  required PortfolioMembership portfolio,
  required String? current,
}) => showMmSheet<void>(
  context,
  title: AppLocalizations.of(context).caretakerLabel,
  builder: (context) => CaretakerSheet(portfolio: portfolio, current: current),
);

/// The caretaker choice: the portfolio's managers and "No caretaker", the
/// current choice selected. A team without a manager leads to the team,
/// where an owner makes someone a manager first.
class CaretakerSheet extends ConsumerStatefulWidget {
  const new({required this.portfolio, required this.current, super.key});

  final PortfolioMembership portfolio;

  /// The caretaker's user id, or null when there is none.
  final String? current;

  @override
  ConsumerState<CaretakerSheet> createState() => _CaretakerSheetState();
}

class _CaretakerSheetState extends ConsumerState<CaretakerSheet>
    with CommandState {
  /// "No caretaker" in the choices: user ids are never empty.
  static const _none = '';

  late String _choice = widget.current ?? _none;

  Future<void> _save(Team team) async {
    final l10n = AppLocalizations.of(context);
    final userId = _choice == _none ? null : _choice;
    final chosen = team.members.where((m) => m.userId == userId);
    final done = await runCommand(
      () => ref
          .read(teamProvider(widget.portfolio).notifier)
          .setCaretaker(userId),
    );
    if (!mounted) return;
    if (!done) {
      // The member may have just left or stopped being a manager: the team
      // read again shows them as they are now.
      if (rejectedReason case 'caretaker_not_manager' || 'member_not_found') {
        unawaited(ref.read(teamProvider(widget.portfolio).notifier).reload());
      }
      return;
    }
    final message = chosen.isEmpty
        ? l10n.caretakerCleared
        : l10n.caretakerNamed(
            inSentence(
              memberName(l10n, chosen.first),
              Directionality.of(context),
            ),
          );
    unawaited(
      showMmSnackbar(context, message: message, tone: MmBannerTone.success),
    );
    Navigator.of(context).pop();
  }

  void _openTeam() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(Routes.team);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(teamProvider(widget.portfolio));
    return SnapshotView<Team>(
      state: state,
      onRetry: () => ref.invalidate(teamProvider(widget.portfolio)),
      loadingLabel: l10n.loadingTeam,
      failedTitle: l10n.teamLoadFailedTitle,
      skeleton: const MmSkeleton.text(lines: 4),
      builder: (team) => _choices(l10n, team),
    );
  }

  Widget _choices(AppLocalizations l10n, Team team) {
    final candidates = caretakerCandidates(team);
    if (candidates.isEmpty && widget.current == null) {
      return MmEmptyState(
        icon: MmIcons.person,
        title: l10n.caretakerNone,
        message: l10n.caretakerNoManagers,
        actionLabel: l10n.openTeamAction,
        onAction: _openTeam,
      );
    }
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          FailureBanner(failure: failure),
          const SizedBox(height: MmSpace.s4),
        ],
        MmRadioGroup<String>(
          label: l10n.caretakerQuestion,
          helper: l10n.caretakerManagersOnly,
          value: _choice,
          options: [
            for (final member in candidates)
              MmOption(
                value: member.userId,
                label: memberName(l10n, member),
                description: switch (member.email) {
                  // A member without a name is listed by their address.
                  final email? when email != memberName(l10n, member) =>
                    breakableEmail(email),
                  _ => null,
                },
              ),
            MmOption(value: _none, label: l10n.caretakerNone),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() {
                  _choice = value ?? _none;
                  this.failure = null;
                }),
        ),
        const SizedBox(height: MmSpace.s6),
        MmButton(
          label: l10n.saveCaretakerAction,
          busy: busy,
          onPressed: _choice == (widget.current ?? _none)
              ? null
              : () => _save(team),
        ),
      ],
    );
  }
}
