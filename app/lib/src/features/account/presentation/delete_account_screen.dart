import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Deleting the account (AUTH-03), through the `delete-account` function.
///
/// It first says exactly what goes: the portfolios the user owns alone,
/// with everything in them and how many others lose them; their place in
/// every other portfolio; their sign-in and profile. Then it asks for the
/// password (the server wants a sign-in from the last few minutes, so the
/// app signs in again) and for the e-mail address typed out, and only then
/// enables the destructive button. Afterwards the sign-in screen confirms
/// that the account is gone.
///
/// Back and Cancel cancel while the password is checked; once the request
/// is on its way, both wait for its answer: the page cannot be
/// popped, and the router keeps it whichever way it is left
/// ([AccountDeletionController.leave]). Another section cancels too, but
/// keeps the screen in its own: shown again, it is no longer busy, and says
/// that the deletion was cancelled and nothing was sent. Another account
/// signed in meanwhile (another tab) gets the screen, and its Delete waits
/// for the earlier request's answer, so that Back and Cancel can always
/// cancel its own deletion while its password is checked.
class DeleteAccountScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preview = ref.watch(accountDeletionProvider);
    final status = ref.watch(authStatusProvider);
    final email = status is SignedIn ? status.email : null;
    return ValueListenableBuilder(
      valueListenable: ref.read(accountDeletionProvider.notifier).sending,
      builder: (context, sending, _) => PopScope(
        canPop: !sending,
        child: switch (preview) {
          AsyncValue(:final value?) when email != null => _DeleteAccountForm(
            preview: value,
            email: email,
            sending: sending,
          ),
          AsyncValue(:final error?) when !waitsForSession(preview) => MmPage(
            title: l10n.deleteAccountTitle,
            body: MmErrorState(
              title: l10n.deletionPreviewFailedTitle,
              message: failureMessage(l10n, AppFailure.from(error)),
              onRetry: () => ref.invalidate(accountDeletionProvider),
            ),
          ),
          _ => MmPage(
            title: l10n.deleteAccountTitle,
            body: Semantics(
              label: l10n.loadingDeletionPreview,
              child: const MmSkeleton.text(lines: 6),
            ),
          ),
        },
      ),
    );
  }
}

class _DeleteAccountForm extends ConsumerStatefulWidget {
  const new({
    required this.preview,
    required this.email,
    required this.sending,
  });

  final DeletionPreview preview;

  /// The account's address, which the user types to confirm.
  final String email;

  /// Whether a deletion's request is on its way, this form's or one an
  /// earlier account sent from the screen: Cancel waits, and so does
  /// Delete.
  final bool sending;

  @override
  ConsumerState<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends ConsumerState<_DeleteAccountForm>
    with CommandState {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _typed = TextEditingController();
  AutovalidateMode _validation = AutovalidateMode.disabled;

  /// Whether the last deletion was cancelled before its request was sent:
  /// the screen was left for another section while the password was
  /// checked, and that section kept it.
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _typed.dispose();
    super.dispose();
  }

  bool get _typedMatches =>
      _typed.text.trim().toLowerCase() == widget.email.trim().toLowerCase();

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _cancelled = false);
    // Success signs out; the router then shows the sign-in screen, which
    // says the account was deleted.
    var sent = true;
    await runCommand(() async {
      sent = await ref
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: _password.text, confirmEmail: _typed.text);
    });
    if (!sent && mounted) setState(() => _cancelled = true);
  }

  void _clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final preview = widget.preview;
    final failure = this.failure;
    String? errorFor(String reason) =>
        failure != null && rejectedReason == reason
        ? failureMessage(l10n, failure)
        : null;
    final passwordError = errorFor('invalid_credentials');
    final emailError = errorFor('does_not_match_account');
    final blocked = preview.secondFactorRequired;
    return MmPage(
      title: l10n.deleteAccountTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmBanner(
              tone: MmBannerTone.warning,
              title: l10n.deleteAccountWarningTitle,
              message: l10n.deleteAccountWarningBody,
            ),
            const SizedBox(height: MmSpace.s6),
            MmSectionHeader(title: l10n.deleteAccountWhatGoes),
            const SizedBox(height: MmSpace.s2),
            if (preview.portfoliosToDelete.isEmpty)
              Text(l10n.deleteAccountNoPortfolios, style: text.bodyLarge)
            else ...[
              Text(
                l10n.deleteAccountPortfolios(preview.portfoliosToDelete.length),
                style: text.bodyLarge,
              ),
              const SizedBox(height: MmSpace.s3),
              MmCard(
                padding: EdgeInsetsDirectional.zero,
                child: Column(
                  children: [
                    for (final (index, portfolio)
                        in preview.portfoliosToDelete.indexed) ...[
                      if (index > 0) const Divider(height: MmSize.hairline),
                      _DoomedPortfolioTile(portfolio: portfolio),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: MmSpace.s3),
            Text(l10n.deleteAccountMemberships, style: text.bodyLarge),
            const SizedBox(height: MmSpace.s3),
            Text(l10n.deleteAccountSignIn, style: text.bodyLarge),
            const SizedBox(height: MmSpace.s8),
            if (blocked)
              MmBanner(
                tone: MmBannerTone.error,
                message: failureMessage(
                  l10n,
                  const RejectedFailure('mfa_required'),
                ),
              )
            else
              MmFormSection(
                title: l10n.deleteAccountConfirmTitle,
                description: l10n.deleteAccountConfirmBody(
                  preview.reauthMaxAge.inMinutes,
                ),
                children: [
                  if (_cancelled)
                    MmBanner(
                      tone: MmBannerTone.info,
                      title: l10n.deletionCancelledTitle,
                      message: l10n.deletionCancelledBody,
                    ),
                  if (failure != null &&
                      passwordError == null &&
                      emailError == null)
                    FailureBanner(failure: failure),
                  MmPasswordField(
                    label: l10n.passwordLabel,
                    controller: _password,
                    required: true,
                    errorText: passwordError,
                    textInputAction: TextInputAction.next,
                    validator: (value) => Validators.required(l10n, value),
                    onChanged: _clearFailure,
                  ),
                  MmTextField(
                    label: l10n.typeEmailToConfirm(
                      breakableEmail(widget.email),
                    ),
                    hint: breakableEmail(widget.email),
                    controller: _typed,
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    errorText: emailError,
                    validator: (value) =>
                        _typedMatches ? null : l10n.validationTypedEmail,
                    onChanged: _clearFailure,
                  ),
                ],
              ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: l10n.cancelAction,
          variant: MmButtonVariant.secondary,
          onPressed: widget.sending ? null : () => context.go(Routes.settings),
        ),
        primary: MmButton(
          label: l10n.deleteAccountConfirmAction,
          icon: MmIcons.delete,
          variant: MmButtonVariant.destructive,
          busy: busy,
          // Waits while another deletion's request is on its way, one an
          // earlier account sent before this one signed in (another tab):
          // started then, its password check would run while the screen
          // cannot be left, so neither Back nor Cancel could cancel it.
          // While this form's own command runs, the busy button already
          // ignores presses and keeps its colours and focus.
          onPressed: blocked || !_typedMatches || (widget.sending && !busy)
              ? null
              : _delete,
        ),
      ),
    );
  }
}

/// One portfolio that goes with the account, and who else loses it.
class _DoomedPortfolioTile extends StatelessWidget {
  const new({required this.portfolio});

  final DoomedPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MmListTile(
      leading: const Icon(MmIcons.property),
      title: portfolio.name,
      subtitle: portfolio.otherMembers == 0
          ? l10n.doomedPortfolioOnlyYou
          : l10n.doomedPortfolioOthers(portfolio.otherMembers),
    );
  }
}
