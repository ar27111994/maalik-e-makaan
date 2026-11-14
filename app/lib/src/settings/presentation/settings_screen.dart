import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/place_names.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/profile_form.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/settings/presentation/text_size_preview.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The landlord's settings: their details, where they live (theirs alone),
/// the language, how the app looks (theme, contrast, text size) and shows
/// amounts, and the account (sign out, delete). Display settings belong to
/// the device and apply at once; the language is saved to the profile too.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    return MmPage(
      title: l10n.settingsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (userId != null) ...[
            _Details(userId: userId),
            const SizedBox(height: MmSpace.s8),
            _Residence(userId: userId),
            const SizedBox(height: MmSpace.s8),
          ],
          _Language(userId: userId),
          const SizedBox(height: MmSpace.s8),
          const _Appearance(),
          const SizedBox(height: MmSpace.s8),
          const _Numbers(),
          const SizedBox(height: MmSpace.s8),
          const _Account(),
          const SizedBox(height: MmSpace.s8),
          const _About(),
        ],
      ),
    );
  }
}

/// The name and phone, loaded from the profile (the saved copy first).
class _Details extends ConsumerWidget {
  const new({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider(userId));
    void retry() => ref.invalidate(profileProvider(userId));
    final snapshot = state.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefreshNotice(state: state, onRetry: retry),
        if (snapshot != null)
          ProfileForm(
            key: ValueKey(snapshot.value.id),
            profile: snapshot.value,
            onSave: ({required fullName, required phone}) => ref
                .read(profileProvider(userId).notifier)
                .saveDetails(fullName: fullName, phone: phone),
          )
        else if (state.error case final error?)
          MmErrorState(
            title: l10n.profileLoadFailedTitle,
            message: failureMessage(l10n, AppFailure.from(error)),
            onRetry: retry,
          )
        else
          Semantics(
            label: l10n.loadingProfile,
            child: const MmSkeleton.text(lines: 4),
          ),
      ],
    );
  }
}

/// Where the person lives, which only they see: the country and the zone
/// of their own times, or that they have not said. It opens the residence
/// screen to answer, change or clear it; with no zone, times are
/// Pakistan's.
class _Residence extends ConsumerWidget {
  const new({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(residenceProvider(userId));
    void retry() => ref.invalidate(residenceProvider(userId));
    final stored = state.value?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.residenceTitle,
          subtitle: l10n.settingsResidenceHelp,
        ),
        const SizedBox(height: MmSpace.s3),
        RefreshNotice(state: state, onRetry: retry),
        if (stored != null)
          _residenceRow(context, ref, stored)
        else if (state.error case final error?)
          MmErrorState(
            title: l10n.residenceLoadFailedTitle,
            message: failureMessage(l10n, AppFailure.from(error)),
            onRetry: retry,
          )
        else
          Semantics(
            label: l10n.loadingResidence,
            child: const MmSkeleton.text(lines: 2),
          ),
      ],
    );
  }

  Widget _residenceRow(
    BuildContext context,
    WidgetRef ref,
    AccountResidence stored,
  ) {
    final l10n = AppLocalizations.of(context);
    final country = stored.residence.country;
    final zone = stored.residence.timeZone;
    final (title, subtitle) = switch ((stored.stated, country)) {
      (false, _) => (l10n.residenceNotAnswered, l10n.residenceNotAnsweredHelp),
      (true, null) => (l10n.residenceNotSaid, l10n.zonePakistanOption),
      // No zone, or one this build does not know: times are Pakistan's.
      (true, final country?)
          when zone == null || zone.isPakistan || !zone.isKnown =>
        (countryName(context, country), l10n.zonePakistanOption),
      (true, final country?) => (
        countryName(context, country),
        '${zoneLabel(context, zone)}\n'
            '${zoneDifference(context, zone!, ref.read(nowProvider)())}',
      ),
    };
    return ListCard(
      children: [
        MmListTile(
          leading: const Icon(MmIcons.location),
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: null,
          userData: false,
          chevron: true,
          onTap: () => unawaited(context.push<bool>(Routes.residence)),
        ),
      ],
    );
  }
}

/// English or Urdu, each written in its own script. The choice applies at
/// once and is saved to the profile, so the server's e-mails use it too.
class _Language extends ConsumerWidget {
  const new({required this.userId});

  final String? userId;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    AppLanguage language,
  ) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(settingsProvider.notifier).setLocale(Locale(language.code));
    final userId = this.userId;
    if (userId == null) return;
    try {
      await ref.read(profileProvider(userId).notifier).saveLanguage(language);
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      await showMmSnackbar(
        context,
        message: l10n.languageNotSavedToProfile(failureMessage(l10n, failure)),
        tone: MmBannerTone.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final code = ref
        .watch(settingsProvider.select((s) => s.locale))
        ?.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.settingsLanguage,
          subtitle: l10n.settingsLanguageHelp,
        ),
        const SizedBox(height: MmSpace.s3),
        MmSegmentedControl<AppLanguage>(
          semanticLabel: l10n.settingsLanguage,
          expand: true,
          segments: [
            MmSegment(value: AppLanguage.english, label: l10n.languageEnglish),
            MmSegment(value: AppLanguage.urdu, label: l10n.languageUrdu),
          ],
          selected: code == AppLanguage.urdu.code
              ? AppLanguage.urdu
              : AppLanguage.english,
          onChanged: (language) => _choose(context, ref, language),
        ),
      ],
    );
  }
}

/// Theme, high contrast and the text size the phone asks for.
class _Appearance extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.settingsAppearance),
        const SizedBox(height: MmSpace.s3),
        MmSegmentedControl<ThemeMode>(
          semanticLabel: l10n.themeLabel,
          expand: true,
          segments: [
            MmSegment(value: ThemeMode.system, label: l10n.themeSystem),
            MmSegment(value: ThemeMode.light, label: l10n.themeLight),
            MmSegment(value: ThemeMode.dark, label: l10n.themeDark),
          ],
          selected: settings.themeMode,
          onChanged: controller.setThemeMode,
        ),
        const SizedBox(height: MmSpace.s3),
        MmSwitchTile(
          label: l10n.highContrastLabel,
          description: l10n.highContrastHelper,
          value: settings.highContrast,
          onChanged: (enabled) => controller.setHighContrast(enabled: enabled),
        ),
        const SizedBox(height: MmSpace.s6),
        const TextSizePreview(),
      ],
    );
  }
}

/// How amounts are grouped: Western or lakh and crore.
class _Numbers extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final grouping = ref.watch(settingsProvider.select((s) => s.grouping));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.settingsNumbers),
        const SizedBox(height: MmSpace.s3),
        MmRadioGroup<DigitGrouping>(
          label: l10n.groupingLabel,
          options: [
            MmOption(value: DigitGrouping.western, label: l10n.groupingWestern),
            MmOption(
              value: DigitGrouping.southAsian,
              label: l10n.groupingSouthAsian,
            ),
          ],
          value: grouping,
          onChanged: (value) async {
            if (value != null) {
              await ref.read(settingsProvider.notifier).setGrouping(value);
            }
          },
        ),
      ],
    );
  }
}

/// The signed-in address, signing out and deleting the account.
class _Account extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(authStatusProvider);
    final email = status is SignedIn ? status.email : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.settingsAccount),
        if (email != null) ...[
          const SizedBox(height: MmSpace.s2),
          MmDetailRow(label: l10n.signedInAs, value: breakableEmail(email)),
        ],
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.signOutAction,
          icon: MmIcons.signOut,
          variant: MmButtonVariant.secondary,
          onPressed: () => ref.read(authStatusProvider.notifier).signOut(),
        ),
        const SizedBox(height: MmSpace.s3),
        MmButton(
          label: l10n.deleteAccountAction,
          icon: MmIcons.delete,
          // It asks first (or opens the flow that does): the filled red
          // button is at the point of no return.
          variant: MmButtonVariant.destructiveOutlined,
          onPressed: () => context.go(Routes.deleteAccount),
        ),
      ],
    );
  }
}

/// The licences of the software, fonts and icons the app is built with
/// (the fonts' and icons' are registered by `MmLicenses.register`).
class _About extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.settingsAbout),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.licencesAction,
          variant: MmButtonVariant.secondary,
          onPressed: () =>
              showLicensePage(context: context, applicationName: l10n.appName),
        ),
      ],
    );
  }
}
