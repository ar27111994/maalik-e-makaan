import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Signing in with e-mail and password, with the ways to a new account and
/// to a forgotten password. After an account was deleted it says so.
class SignInScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with CommandState {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    // Success changes the session; the router then leaves this screen.
    await runCommand(
      () => ref
          .read(authStatusProvider.notifier)
          .signIn(email: _email.text, password: _password.text),
    );
  }

  /// Sends the confirmation e-mail again after a sign-in refused because
  /// the address is not confirmed yet.
  Future<void> _resendConfirmation() async {
    final email = _email.text.trim();
    final sent = await runCommand(
      () => ref.read(authStatusProvider.notifier).resendConfirmation(email),
    );
    if (!sent || !mounted) return;
    ref.read(pendingEmailProvider.notifier).email = PendingEmail(
      address: email,
      purpose: EmailPurpose.confirmation,
    );
    context.go(Routes.checkEmail);
  }

  void _clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(authStatusProvider);
    final failure = this.failure;
    final emailError = rejectedReason == 'invalid_email' && failure != null
        ? failureMessage(l10n, failure)
        : null;
    return MmPage(
      title: l10n.signInTitle,
      body: AutofillGroup(
        child: Form(
          key: _form,
          autovalidateMode: _validation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status case SignedOut(cause: SignOutCause.accountDeleted))
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
                  child: MmBanner(
                    tone: MmBannerTone.success,
                    title: l10n.accountDeletedTitle,
                    message: l10n.accountDeletedBody,
                  ),
                ),
              if (status case SignedOut(
                cause: SignOutCause.deletionUnconfirmed,
              ))
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
                  child: MmBanner(
                    tone: MmBannerTone.info,
                    title: l10n.deletionUnconfirmedTitle,
                    message: l10n.deletionUnconfirmedBody,
                  ),
                ),
              if (failure != null && emailError == null)
                FailureBanner(
                  failure: failure,
                  actionLabel: rejectedReason == 'email_not_confirmed'
                      ? l10n.resendEmailAction
                      : null,
                  onAction: rejectedReason == 'email_not_confirmed' && !busy
                      ? _resendConfirmation
                      : null,
                ),
              MmTextField(
                label: l10n.emailLabel,
                controller: _email,
                required: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: emailError,
                validator: (value) => Validators.email(l10n, value),
                onChanged: _clearFailure,
              ),
              const SizedBox(height: MmSpace.s4),
              MmPasswordField(
                label: l10n.passwordLabel,
                controller: _password,
                required: true,
                textInputAction: TextInputAction.done,
                validator: (value) => Validators.required(l10n, value),
                onChanged: _clearFailure,
                onSubmitted: (_) => _signIn(),
              ),
              const SizedBox(height: MmSpace.s2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MmButton(
                  label: l10n.forgotPasswordAction,
                  variant: MmButtonVariant.tertiary,
                  onPressed: () =>
                      context.go(Routes.forgotPassword, extra: _email.text),
                ),
              ),
              const SizedBox(height: MmSpace.s6),
              Text(
                l10n.noAccountPrompt,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: MmSpace.s2),
              MmButton(
                label: l10n.signUpAction,
                variant: MmButtonVariant.secondary,
                onPressed: () => context.go(Routes.signUp),
              ),
            ],
          ),
        ),
      ),
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.signInAction,
          busy: busy,
          onPressed: _signIn,
        ),
      ),
    );
  }
}
