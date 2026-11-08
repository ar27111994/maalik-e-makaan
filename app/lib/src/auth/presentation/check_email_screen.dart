import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// After an e-mail was sent (a new account's confirmation or a password
/// reset): where it went, what to do with it, and a way to send it again
/// once Supabase allows another (one a minute).
class CheckEmailScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// How long Supabase makes the user wait between two e-mails
  /// (`supabase/config.toml`: `max_frequency`).
  static const resendInterval = Duration(minutes: 1);

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen>
    with CommandState {
  Timer? _timer;
  Duration _wait = Duration.zero;
  var _resent = false;

  @override
  void initState() {
    super.initState();
    // The e-mail has just been sent.
    _startWait(CheckEmailScreen.resendInterval);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Disables sending again for [wait], counting down every second.
  void _startWait(Duration wait) {
    _timer?.cancel();
    _wait = wait;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wait -= const Duration(seconds: 1));
      if (_wait <= Duration.zero) timer.cancel();
    });
  }

  Future<void> _resend(PendingEmail email) async {
    final auth = ref.read(authStatusProvider.notifier);
    final sent = await runCommand(
      () => switch (email.purpose) {
        EmailPurpose.confirmation => auth.resendConfirmation(email.address),
        EmailPurpose.passwordReset => auth.sendPasswordReset(email.address),
      },
    );
    if (!mounted) return;
    setState(() {
      if (sent) {
        _resent = true;
        _startWait(CheckEmailScreen.resendInterval);
      } else if (failure case RateLimited(:final retryAfter)) {
        _startWait(retryAfter ?? CheckEmailScreen.resendInterval);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final email = ref.watch(pendingEmailProvider);
    final failure = this.failure;
    final waiting = _wait > Duration.zero;
    return MmPage(
      title: l10n.checkEmailTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null && failure is! RateLimited)
            FailureBanner(failure: failure),
          if (_resent && failure == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
              child: MmBanner(
                tone: MmBannerTone.success,
                message: l10n.emailSentAgain,
              ),
            ),
          ExcludeSemantics(
            child: Icon(
              MmIcons.email,
              size: MmSize.iconXl,
              color: context.mm.colors.inkMuted,
            ),
          ),
          const SizedBox(height: MmSpace.s4),
          if (email == null)
            Text(l10n.checkEmailBodyNoAddress, style: text.bodyLarge)
          else ...[
            Text(l10n.checkEmailSentTo, style: text.bodyLarge),
            const SizedBox(height: MmSpace.s1),
            // The address on a line of its own, left to right and in its
            // own script's face, so it never mixes into the sentence.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                breakableEmail(email.address),
                textDirection: TextDirection.ltr,
                style: context.mm.styleFor(email.address, text.titleMedium!),
              ),
            ),
            const SizedBox(height: MmSpace.s3),
            Text(l10n.checkEmailInstructions, style: text.bodyLarge),
          ],
          if (email?.purpose == EmailPurpose.passwordReset) ...[
            const SizedBox(height: MmSpace.s3),
            Text(l10n.checkEmailResetHint, style: text.bodyLarge),
          ],
          if (email != null) ...[
            const SizedBox(height: MmSpace.s6),
            MmButton(
              label: l10n.resendEmailAction,
              icon: MmIcons.send,
              variant: MmButtonVariant.secondary,
              busy: busy,
              onPressed: waiting ? null : () => _resend(email),
            ),
            if (waiting) ...[
              const SizedBox(height: MmSpace.s2),
              Text(
                l10n.resendWait(_wait.inSeconds),
                style: text.bodyMedium?.copyWith(
                  color: context.mm.colors.inkMuted,
                ),
              ),
            ],
          ],
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
    );
  }
}
