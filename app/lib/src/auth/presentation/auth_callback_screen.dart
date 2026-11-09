import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Where links in Supabase's e-mails land
/// (`https://maalik-e-makaan.vercel.app/auth/callback?code=…`): it
/// exchanges the link's one-time code for a session (PKCE). On success the
/// router moves on by itself: to the app after confirming an address, to
/// "Choose a new password" after a reset link. A link that cannot be used
/// says why and leads back to signing in.
class AuthCallbackScreen extends ConsumerStatefulWidget {
  const new({required this.link, super.key});

  /// The link as it was opened, with its query and fragment.
  final Uri link;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen>
    with CommandState {
  @override
  void initState() {
    super.initState();
    // The code works once: exchange it once, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_complete());
    });
  }

  Future<void> _complete() async {
    final done = await runCommand(
      () =>
          ref.read(authStatusProvider.notifier).completeEmailLink(widget.link),
    );
    // Signed out before, the router moves on when the session arrives; signed
    // in already, it lets this screen finish, so leave it here. A password
    // reset is sent on to choosing the new password either way.
    if (done && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return MmPage(
      title: l10n.appName,
      scrollable: failure != null,
      body: failure == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: MmSpace.s4),
                  Text(
                    l10n.signingInCallback,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : MmErrorState(
              title: l10n.linkFailedTitle,
              message: failureMessage(l10n, failure),
              actionLabel: l10n.backToSignInAction,
              actionIcon: MmIcons.back,
              onRetry: () => context.go(Routes.signIn),
            ),
    );
  }
}
