import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The two answers to "Does the owner of these properties live abroad?",
/// yes first, as the question asks it.
List<MmOption<OwnerAbroad>> ownerAbroadOptions(AppLocalizations l10n) => [
  MmOption(value: OwnerAbroad.abroad, label: l10n.ownerAbroadYes),
  MmOption(value: OwnerAbroad.inPakistan, label: l10n.ownerAbroadNo),
];

/// Where the owner lives, as a value: "Abroad", "In Pakistan" or "Not
/// answered yet".
String ownerLivesLabel(AppLocalizations l10n, OwnerAbroad answer) =>
    switch (answer) {
      OwnerAbroad.abroad => l10n.ownerLivesAbroad,
      OwnerAbroad.inPakistan => l10n.ownerLivesInPakistan,
      OwnerAbroad.notAnswered => l10n.ownerLivesNotAnswered,
    };

/// The question on a new portfolio's form: no answer chosen in advance, and
/// the form cannot be submitted until one is (D-16). Nothing is read from
/// the creator's own residence, because whoever creates a portfolio is
/// often a caretaker or a relative.
class OwnerAbroadField extends StatelessWidget {
  const new({required this.onChanged, this.enabled = true, super.key});

  /// Called with the answer chosen.
  final ValueChanged<OwnerAbroad> onChanged;

  /// Whether the answer may be changed (not while the form is saving).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormField<OwnerAbroad>(
      validator: (value) => value == null ? l10n.ownerAbroadRequired : null,
      builder: (field) => MmRadioGroup<OwnerAbroad>(
        label: l10n.ownerAbroadQuestion,
        required: true,
        helper: l10n.ownerAbroadNewHelp,
        errorText: field.errorText,
        value: field.value,
        options: ownerAbroadOptions(l10n),
        onChanged: enabled
            ? (value) {
                if (value == null) return;
                field.didChange(value);
                onChanged(value);
              }
            : null,
      ),
    );
  }
}

/// Asks the signed-in user, an owner or a manager of [membership], "Does
/// the owner of these properties live abroad?" for a portfolio nobody has
/// answered for, in a sheet. Completes with true once answered (by them or,
/// as it turned out, by someone first), otherwise false or null ("Not now",
/// or the sheet closed).
Future<bool?> showOwnerAbroadQuestion(
  BuildContext context,
  PortfolioMembership membership,
) => showMmSheet<bool>(
  context,
  title: membership.name,
  // The portfolio's name as its owner typed it.
  userTitle: true,
  builder: (context) => OwnerAbroadQuestionSheet(membership: membership),
);

/// The question for a portfolio nobody has answered for: nothing chosen in
/// advance, and the answer saved only by "Save answer", so a stray tap
/// saves nothing (a manager's answer is final for them).
///
/// It answers only while the question is unanswered: when another member
/// answered first, the sheet shows the answer that won and changes
/// nothing.
class OwnerAbroadQuestionSheet extends ConsumerStatefulWidget {
  const new({required this.membership, super.key});

  final PortfolioMembership membership;

  @override
  ConsumerState<OwnerAbroadQuestionSheet> createState() =>
      _OwnerAbroadQuestionSheetState();
}

class _OwnerAbroadQuestionSheetState
    extends ConsumerState<OwnerAbroadQuestionSheet>
    with CommandState {
  OwnerAbroad? _answer;
  bool _submitted = false;

  /// The answer stored when someone else answered first.
  OwnerAbroad? _won;

  bool get _owner => widget.membership.role == MemberRole.owner;

  Future<void> _save() async {
    final answer = _answer;
    if (answer == null) {
      setState(() => _submitted = true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final id = widget.membership.id;
    late OwnerAbroad stored;
    final done = await runCommand(() async {
      final abroad = answer == OwnerAbroad.abroad;
      // Portfolio details on screen read the stored answer at once;
      // otherwise the portfolio list shows it, and the details catch up
      // when next opened.
      if (ref.exists(portfolioDetailsProvider(id))) {
        stored = await ref
            .read(portfolioDetailsProvider(id).notifier)
            .answerOwnerAbroad(abroad: abroad);
      } else {
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) throw const SessionExpired();
        stored = await ref
            .read(portfoliosProvider(userId).notifier)
            .answerOwnerAbroad(id, abroad: abroad);
      }
    });
    if (!mounted) return;
    if (!done) {
      // The role may have changed meanwhile: the list read again says
      // whether the question still applies.
      if (failure is Forbidden) unawaited(_reloadPortfolios());
      return;
    }
    if (stored != answer) {
      setState(() => _won = stored);
      return;
    }
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.answerSaved,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _reloadPortfolios() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(portfoliosProvider(userId).notifier).reload();
    } on AppFailure {
      // The banner already says what went wrong; the list catches up later.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    // The list stays read while the sheet is open, so the answer reaches it
    // whoever opened the sheet.
    final userId = ref.watch(currentUserIdProvider);
    if (userId != null) ref.watch(portfoliosProvider(userId));
    final won = _won;
    if (won != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmBanner(
            tone: MmBannerTone.info,
            title: l10n.answeredFirstTitle,
            message: won == OwnerAbroad.abroad
                ? l10n.answeredFirstAbroad
                : l10n.answeredFirstPakistan,
          ),
          const SizedBox(height: MmSpace.s4),
          Text(
            _owner ? l10n.ownerAbroadOwnerNote : l10n.ownerAbroadOnlyOwners,
            style: text.bodyMedium,
          ),
          const SizedBox(height: MmSpace.s6),
          MmButton(
            label: l10n.doneAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    }
    final failure = this.failure;
    final name = inSentence(widget.membership.name, Directionality.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          FailureBanner(failure: failure),
          const SizedBox(height: MmSpace.s4),
        ],
        Text(l10n.ownerAbroadUnanswered(name), style: text.bodyLarge),
        const SizedBox(height: MmSpace.s4),
        MmRadioGroup<OwnerAbroad>(
          label: l10n.ownerAbroadQuestion,
          required: true,
          helper: _owner
              ? l10n.ownerAbroadOwnerNote
              : l10n.ownerAbroadManagerNote,
          errorText: _submitted && _answer == null
              ? l10n.chooseAnswerError
              : null,
          value: _answer,
          options: ownerAbroadOptions(l10n),
          onChanged: busy
              ? null
              : (value) => setState(() {
                  _answer = value;
                  this.failure = null;
                }),
        ),
        const SizedBox(height: MmSpace.s6),
        MmButton(label: l10n.saveAnswerAction, busy: busy, onPressed: _save),
        const SizedBox(height: MmSpace.s3),
        MmButton(
          label: l10n.notNowAction,
          variant: MmButtonVariant.tertiary,
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Lets an owner change the answer of [portfolioId], once given: the
/// current answer is chosen (this is a change, not a first question), and
/// Save stays off until another is chosen. Completes with true once
/// changed.
Future<bool?> showOwnerAbroadChange(
  BuildContext context, {
  required String portfolioId,
  required OwnerAbroad current,
}) => showMmSheet<bool>(
  context,
  title: AppLocalizations.of(context).changeAnswerAction,
  builder: (context) =>
      OwnerAbroadChangeSheet(portfolioId: portfolioId, current: current),
);

/// The owners' change of the owner-abroad answer (`set_owner_abroad`
/// without the unanswered-only rule, which only owners may use).
class OwnerAbroadChangeSheet extends ConsumerStatefulWidget {
  const new({required this.portfolioId, required this.current, super.key});

  final String portfolioId;
  final OwnerAbroad current;

  @override
  ConsumerState<OwnerAbroadChangeSheet> createState() =>
      _OwnerAbroadChangeSheetState();
}

class _OwnerAbroadChangeSheetState extends ConsumerState<OwnerAbroadChangeSheet>
    with CommandState {
  late OwnerAbroad? _answer = widget.current;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final answer = _answer!;
    final done = await runCommand(
      () => ref
          .read(portfolioDetailsProvider(widget.portfolioId).notifier)
          .changeOwnerAbroad(abroad: answer == OwnerAbroad.abroad),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.answerChanged,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          FailureBanner(failure: failure),
          const SizedBox(height: MmSpace.s4),
        ],
        MmRadioGroup<OwnerAbroad>(
          label: l10n.ownerAbroadQuestion,
          value: _answer,
          options: ownerAbroadOptions(l10n),
          onChanged: busy
              ? null
              : (value) => setState(() {
                  _answer = value;
                  this.failure = null;
                }),
        ),
        const SizedBox(height: MmSpace.s6),
        MmButton(
          label: l10n.saveAnswerAction,
          busy: busy,
          onPressed: _answer == widget.current ? null : _save,
        ),
      ],
    );
  }
}
