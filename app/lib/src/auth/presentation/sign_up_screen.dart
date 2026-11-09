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
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Creating an account: name, e-mail and a password that meets the
/// server's rules, in the language chosen on this device. Supabase then
/// e-mails a confirmation link ("Check your e-mail").
class SignUpScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> with CommandState {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final email = _email.text.trim();
    late SignUpOutcome outcome;
    final done = await runCommand(() async {
      outcome = await ref
          .read(authStatusProvider.notifier)
          .signUp(email: email, password: _password.text, fullName: _name.text);
    });
    // Signed in at once (confirmation off): the router moves on.
    if (!done || !mounted || outcome == SignUpOutcome.signedIn) return;
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
    final failure = this.failure;
    String? errorFor(Set<String> reasons) =>
        failure != null && reasons.contains(rejectedReason)
        ? failureMessage(l10n, failure)
        : null;
    final emailError = errorFor(const {'email_taken', 'invalid_email'});
    final passwordError = errorFor(const {'weak_password'});
    return MmPage(
      title: l10n.signUpTitle,
      body: AutofillGroup(
        child: Form(
          key: _form,
          autovalidateMode: _validation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failure != null &&
                  emailError == null &&
                  passwordError == null)
                FailureBanner(failure: failure),
              MmTextField(
                label: l10n.fullNameLabel,
                controller: _name,
                required: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => Validators.name(
                  l10n,
                  value,
                  maxLength: Profile.maxNameLength,
                ),
              ),
              const SizedBox(height: MmSpace.s4),
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
                newPassword: true,
                helper: l10n.passwordHelper,
                errorText: passwordError,
                textInputAction: TextInputAction.done,
                validator: (value) => Validators.newPassword(l10n, value),
                onChanged: _clearFailure,
                onSubmitted: (_) => _signUp(),
              ),
              const SizedBox(height: MmSpace.s6),
              Text(
                l10n.haveAccountPrompt,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: MmSpace.s2),
              MmButton(
                label: l10n.signInAction,
                variant: MmButtonVariant.secondary,
                onPressed: () => context.go(Routes.signIn),
              ),
            ],
          ),
        ),
      ),
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.signUpAction,
          busy: busy,
          onPressed: _signUp,
        ),
      ),
    );
  }
}
