import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Asking for a password-reset link. The answer is the same whether or not
/// the address has an account, so the form never reveals who does.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const new({this.initialEmail, super.key});

  /// The address typed on the sign-in screen, if any.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail?.trim());
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final email = _email.text.trim();
    final sent = await runCommand(
      () => ref.read(authStatusProvider.notifier).sendPasswordReset(email),
    );
    if (!sent || !mounted) return;
    ref.read(pendingEmailProvider.notifier).email = PendingEmail(
      address: email,
      purpose: EmailPurpose.passwordReset,
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
    final emailError = failure != null && rejectedReason == 'invalid_email'
        ? failureMessage(l10n, failure)
        : null;
    return MmPage(
      title: l10n.resetPasswordTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && emailError == null)
              FailureBanner(failure: failure),
            Text(
              l10n.resetPasswordBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MmSpace.s6),
            MmTextField(
              label: l10n.emailLabel,
              controller: _email,
              required: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              errorText: emailError,
              validator: (value) => Validators.email(l10n, value),
              onChanged: _clearFailure,
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: MmSpace.s6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MmButton(
                label: l10n.backToSignInAction,
                variant: MmButtonVariant.tertiary,
                icon: MmIcons.back,
                onPressed: () => context.go(Routes.signIn),
              ),
            ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.sendResetLinkAction,
          busy: busy,
          onPressed: _send,
        ),
      ),
    );
  }
}
