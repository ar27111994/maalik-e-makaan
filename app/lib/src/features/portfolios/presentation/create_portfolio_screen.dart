import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/owner_abroad_question.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Creating a portfolio, where the user becomes its owner. A new account
/// starts here (and can only sign out or open Settings until it has one);
/// later the portfolio switcher leads here for another.
///
/// It asks "Does the owner of these properties live abroad?" with no
/// answer chosen, and creates nothing until it is answered; the answer is
/// never taken from the creator's own residence (D-16).
class CreatePortfolioScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CreatePortfolioScreen> createState() =>
      _CreatePortfolioScreenState();
}

class _CreatePortfolioScreenState extends ConsumerState<CreatePortfolioScreen>
    with CommandState {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final GlobalKey _answerField = GlobalKey(debugLabel: 'owner abroad');
  AutovalidateMode _validation = AutovalidateMode.disabled;

  /// The answer to the owner-abroad question; none until chosen.
  OwnerAbroad? _ownerAbroad;

  /// Names this attempt: every retry sends it again, so a request that
  /// reached the server before the connection dropped creates nothing more.
  final String _attempt = newUuid();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(String userId) async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      // At large text sizes the question may be below the fold.
      final answer = _answerField.currentContext;
      if (_ownerAbroad == null && answer != null) {
        await Scrollable.ensureVisible(answer);
      }
      return;
    }
    final l10n = AppLocalizations.of(context);
    final answer = _ownerAbroad!;
    late PortfolioMembership created;
    final done = await runCommand(() async {
      created = await ref
          .read(portfoliosProvider(userId).notifier)
          .create(name: _name.text, id: _attempt, ownerAbroad: answer);
    });
    if (!done || !mounted) return;
    final name = inSentence(created.name, Directionality.of(context));
    // A retry whose first attempt reached the server gets that attempt's
    // portfolio back, with its answer: say so, as it may differ.
    final kept =
        created.ownerAbroad != answer && !created.ownerAbroad.needsAnswer;
    unawaited(
      showMmSnackbar(
        context,
        message: kept
            ? l10n.portfolioCreatedFirstAnswer(
                name,
                ownerLivesLabel(l10n, created.ownerAbroad),
              )
            : l10n.portfolioCreated(name),
        tone: kept ? MmBannerTone.info : MmBannerTone.success,
      ),
    );
    context.go(Routes.home);
  }

  void _clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final firstRun = ref.watch(portfolioGateProvider) == PortfolioGate.none;
    final failure = this.failure;
    final nameError =
        failure != null && rejectedReason == 'constraint_violation'
        ? l10n.portfolioNameInvalid
        : null;
    return MmPage(
      title: firstRun ? l10n.createFirstPortfolioTitle : l10n.newPortfolioTitle,
      actions: [
        if (firstRun) ...[
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(MmIcons.settings),
            onPressed: () => context.go(Routes.settings),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.read(authStatusProvider.notifier).signOut(),
            child: Text(l10n.signOutAction),
          ),
        ],
      ],
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && nameError == null)
              FailureBanner(failure: failure),
            Text(
              firstRun ? l10n.createFirstPortfolioBody : l10n.newPortfolioBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MmSpace.s6),
            MmTextField(
              label: l10n.portfolioNameLabel,
              controller: _name,
              required: true,
              helper: l10n.portfolioNameHelper,
              errorText: nameError,
              maxLength: PortfolioMembership.maxNameLength,
              inputFormatters: codePointLimit(
                PortfolioMembership.maxNameLength,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              validator: (value) => Validators.name(
                l10n,
                value,
                maxLength: PortfolioMembership.maxNameLength,
              ),
              onChanged: _clearFailure,
              onSubmitted: userId == null ? null : (_) => _create(userId),
            ),
            const SizedBox(height: MmSpace.s6),
            OwnerAbroadField(
              key: _answerField,
              enabled: !busy,
              onChanged: (answer) {
                _ownerAbroad = answer;
                _clearFailure('');
              },
            ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        secondary: firstRun
            ? null
            : MmButton(
                label: l10n.cancelAction,
                variant: MmButtonVariant.secondary,
                onPressed: busy ? null : () => context.go(Routes.more),
              ),
        primary: MmButton(
          label: l10n.createPortfolioAction,
          busy: busy,
          onPressed: userId == null ? null : () => _create(userId),
        ),
      ),
    );
  }
}
