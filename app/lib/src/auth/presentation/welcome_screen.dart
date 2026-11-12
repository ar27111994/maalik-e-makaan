import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';

/// The first-launch screen: the app's welcome in English and in Urdu, each
/// in its own script and direction whatever the device's language, and one
/// button per language. The choice is kept on the device (and saved to the
/// profile at sign-up or sign-in); Settings can change it later.
class WelcomeScreen extends ConsumerWidget {
  const new({super.key});

  static const _english = Locale('en');
  static const _urdu = Locale('ur');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final english = lookupAppLocalizations(_english);
    final urdu = lookupAppLocalizations(_urdu);
    final settings = ref.read(settingsProvider.notifier);
    return MmPage(
      title: english.appName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InLanguage(
            locale: _english,
            child: _Greeting(l10n: english),
          ),
          const SizedBox(height: MmSpace.s6),
          _InLanguage(
            locale: _urdu,
            child: _Greeting(l10n: urdu),
          ),
          const SizedBox(height: MmSpace.s8),
          _InLanguage(
            locale: _english,
            child: MmButton(
              label: english.continueInEnglish,
              variant: MmButtonVariant.secondary,
              expand: true,
              onPressed: () => settings.setLocale(_english),
            ),
          ),
          const SizedBox(height: MmSpace.s3),
          _InLanguage(
            locale: _urdu,
            child: MmButton(
              label: urdu.continueInUrdu,
              variant: MmButtonVariant.secondary,
              expand: true,
              onPressed: () => settings.setLocale(_urdu),
            ),
          ),
        ],
      ),
    );
  }
}

/// [child] in [locale]: its localisations, its script's type (Noto Sans
/// Arabic for Urdu, on its taller lines) and its direction, in the current
/// theme's mode and contrast.
class _InLanguage extends StatelessWidget {
  const new({required this.locale, required this.child});

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return Localizations.override(
      context: context,
      locale: locale,
      child: Theme(
        data: MmTheme.data(
          brightness: Theme.of(context).brightness,
          script: MmScript.of(locale),
          highContrast: mm.highContrast,
        ),
        child: Directionality(
          textDirection: MmScript.of(locale) == MmScript.urdu
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child,
        ),
      ),
    );
  }
}

/// The welcome heading and explanation in one language.
class _Greeting extends StatelessWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.welcomeTitle, style: text.headlineSmall),
        ),
        const SizedBox(height: MmSpace.s2),
        Text(l10n.welcomeBody, style: text.bodyLarge),
      ],
    );
  }
}
