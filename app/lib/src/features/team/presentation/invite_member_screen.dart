import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/roles.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';

/// What the invitation form starts with ("Invite again" fills it in).
@immutable
final class InviteDraft {
  const new({required this.email, required this.role});

  final String email;
  final MemberRole role;
}

/// Inviting someone to the current portfolio by e-mail and role (TEAM-03),
/// owners only. The `invite-member` function e-mails the link when it can
/// and returns it either way, so the owner can copy it or share it on
/// WhatsApp; the screen says which happened.
class InviteMemberScreen extends ConsumerStatefulWidget {
  const new({this.draft, super.key});

  final InviteDraft? draft;

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.draft?.email);
  late MemberRole _role = widget.draft?.role ?? MemberRole.manager;
  AutovalidateMode _validation = AutovalidateMode.disabled;
  InvitationLink? _sent;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send(PortfolioMembership portfolio) async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final language =
        ref.read(settingsProvider).locale?.languageCode == AppLanguage.urdu.code
        ? AppLanguage.urdu
        : AppLanguage.english;
    late InvitationLink link;
    final done = await runCommand(() async {
      link = await ref
          .read(teamProvider(portfolio).notifier)
          .invite(email: _email.text, role: _role, language: language);
    });
    if (done && mounted) setState(() => _sent = link);
  }

  void _clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    // Keeps the team read while this screen is open, so the new invitation
    // shows on it as soon as it is made.
    if (portfolio != null) ref.listen(teamProvider(portfolio), (_, _) {});
    final sent = _sent;
    if (sent != null && portfolio != null) {
      return InvitationReady(link: sent, portfolioName: portfolio.name);
    }
    final failure = this.failure;
    final emailError = switch (rejectedReason) {
      'invalid_email' || 'already_member' => failureMessage(l10n, failure!),
      _ => null,
    };
    return MmPage(
      title: l10n.inviteTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && emailError == null)
              FailureBanner(failure: failure),
            Text(l10n.inviteBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: MmSpace.s6),
            MmTextField(
              label: l10n.inviteEmailLabel,
              controller: _email,
              required: true,
              errorText: emailError,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              maxLength: 254,
              inputFormatters: codePointLimit(254),
              validator: (value) => Validators.email(l10n, value),
              onChanged: _clearFailure,
            ),
            const SizedBox(height: MmSpace.s4),
            MmRadioGroup<MemberRole>(
              label: l10n.inviteRoleLabel,
              options: roleOptions(l10n),
              value: _role,
              onChanged: (role) {
                if (role != null) setState(() => _role = role);
              },
            ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: l10n.cancelAction,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => context.go(Routes.team),
        ),
        primary: MmButton(
          label: l10n.sendInvitationAction,
          icon: MmIcons.send,
          busy: busy,
          onPressed: portfolio == null ? null : () => _send(portfolio),
        ),
      ),
    );
  }
}

/// A new invitation: whether it was e-mailed, until when the link works,
/// and the link itself to copy or share on WhatsApp.
class InvitationReady extends ConsumerWidget {
  const new({required this.link, required this.portfolioName, super.key});

  final InvitationLink link;
  final String portfolioName;

  String _delivery(AppLocalizations l10n, TextDirection direction) {
    final email = inSentence(breakableEmail(link.email), direction);
    return switch (link.delivery) {
      EmailDelivery.sent => l10n.deliverySent(email),
      EmailDelivery.notConfigured => l10n.deliveryNotConfigured(email),
      EmailDelivery.rateLimited => l10n.deliveryRateLimited(email),
      EmailDelivery.failed => l10n.deliveryFailed(email),
      EmailDelivery.unknown => l10n.deliveryUnknown(email),
    };
  }

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await copyText(link.url.toString());
    if (!context.mounted) return;
    await showMmSnackbar(
      context,
      message: l10n.linkCopied,
      tone: MmBannerTone.success,
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final message = l10n.invitationShareMessage(
      portfolioName,
      link.url.toString(),
    );
    final opened = await ref.read(linkOpenerProvider)(whatsAppLink(message));
    if (opened || !context.mounted) return;
    await showMmSnackbar(
      context,
      message: l10n.linkNotOpened,
      tone: MmBannerTone.error,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sent = link.delivery == EmailDelivery.sent;
    return MmPage(
      title: l10n.invitationReadyTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmBanner(
            tone: sent ? MmBannerTone.success : MmBannerTone.warning,
            message: _delivery(l10n, Directionality.of(context)),
          ),
          const SizedBox(height: MmSpace.s4),
          Text(
            l10n.invitationValidUntil(
              momentLabel(context, link.expiresAt),
              breakableEmail(link.email),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MmSpace.s6),
          MmSectionHeader(title: l10n.invitationLinkLabel),
          const SizedBox(height: MmSpace.s2),
          MmCard(
            // A SelectableText reaches assistive technology as an empty,
            // unlabelled field on the web (docs/uat.md, D3): screen readers
            // hear the link from this node instead, and select or copy it
            // with Copy link below.
            child: Semantics(
              container: true,
              label: l10n.invitationLinkLabel,
              value: link.url.toString(),
              textDirection: TextDirection.ltr,
              child: ExcludeSemantics(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    link.url.toString(),
                    style: context.mm.styleFor(
                      link.url.toString(),
                      Theme.of(context).textTheme.bodyMedium!,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.shareWhatsAppAction,
            icon: MmIcons.share,
            variant: MmButtonVariant.secondary,
            onPressed: () => _share(context, ref),
          ),
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.copyLinkAction,
            icon: MmIcons.copy,
            variant: MmButtonVariant.secondary,
            onPressed: () => _copy(context),
          ),
        ],
      ),
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.doneAction,
          onPressed: () => context.go(Routes.team),
        ),
      ),
    );
  }
}
