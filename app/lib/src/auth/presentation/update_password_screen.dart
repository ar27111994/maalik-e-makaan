import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:mm_ui/mm_ui.dart';

/// Choosing a new password after following a reset link. The link signed
/// the user in for this alone: saving the password finishes it, and "Sign
/// out" abandons it.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen>
    with CommandState {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final saved = await runCommand(
      () =>
          ref.read(authStatusProvider.notifier).updatePassword(_password.text),
    );
    // The session is now an ordinary one and the router moves on; the
    // app's messenger keeps the confirmation on the next screen.
    if (saved && mounted) {
      await showMmSnackbar(
        context,
        message: AppLocalizations.of(context).passwordSaved,
        tone: MmBannerTone.success,
      );
    }
  }

  void _clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final passwordError =
        failure != null &&
            const {'weak_password', 'same_password'}.contains(rejectedReason)
        ? failureMessage(l10n, failure)
        : null;
    return MmPage(
      title: l10n.choosePasswordTitle,
      actions: [
        TextButton(
          onPressed: busy
              ? null
              : () => ref.read(authStatusProvider.notifier).signOut(),
          child: Text(l10n.signOutAction),
        ),
      ],
      body: AutofillGroup(
        child: Form(
          key: _form,
          autovalidateMode: _validation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failure != null && passwordError == null)
                FailureBanner(failure: failure),
              Text(
                l10n.choosePasswordBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: MmSpace.s6),
              MmPasswordField(
                label: l10n.newPasswordLabel,
                controller: _password,
                required: true,
                newPassword: true,
                helper: l10n.passwordHelper,
                errorText: passwordError,
                textInputAction: TextInputAction.next,
                validator: (value) => Validators.newPassword(l10n, value),
                onChanged: _clearFailure,
              ),
              const SizedBox(height: MmSpace.s4),
              MmPasswordField(
                label: l10n.repeatPasswordLabel,
                controller: _repeat,
                required: true,
                newPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    Validators.repeatedPassword(l10n, value, _password.text),
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.savePasswordAction,
          busy: busy,
          onPressed: _save,
        ),
      ),
    );
  }
}
