import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:mm_ui/mm_ui.dart';

/// A section whose screens arrive in a later phase: it says so plainly
/// instead of showing an empty page.
class PendingScreen extends StatelessWidget {
  const new({required this.section, super.key});

  final String Function(AppLocalizations l10n) section;

  static Widget welcome(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.welcomeTitle);
  static Widget signIn(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.signInTitle);
  static Widget signUp(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.signUpTitle);
  static Widget forgotPassword(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.resetPasswordTitle);
  static Widget checkEmail(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.checkEmailTitle);
  static Widget updatePassword(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.choosePasswordTitle);
  static Widget authCallback(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.signingInCallback);
  static Widget home(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.navHome);
  static Widget tenants(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.navTenants);
  static Widget money(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.navMoney);
  static Widget properties(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.navProperties);
  static Widget more(BuildContext context, GoRouterState state) =>
      PendingScreen(section: (l10n) => l10n.navMore);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final name = section(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  MmIcons.maintenance,
                  size: MmSpace.s12,
                  color: context.mm.colors.inkMuted,
                ),
              ),
              const SizedBox(height: MmSpace.s4),
              Semantics(
                header: true,
                child: Text(
                  l10n.comingSoonTitle(name),
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: MmSpace.s2),
              Text(
                l10n.comingSoonBody,
                style: text.bodyLarge?.copyWith(
                  color: context.mm.colors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
