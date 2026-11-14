import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/device_time_zone.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/place_names.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The answers to "Do you live in Pakistan?".
enum ResidenceAnswer {
  /// In Pakistan: the country is Pakistan, times are Pakistan's.
  inPakistan,

  /// In another country, with the zone of the person's own clock.
  abroad,

  /// The person prefers not to say: nothing is stated, and the question is
  /// answered.
  notSaying,
}

/// "Where you live": the person's answer to "Do you live in Pakistan?", and
/// when abroad, the country and the zone of their own clock (D-16).
///
/// The app asks it once after signing in (the shell pushes it while the
/// person has never answered), and Settings opens it to answer or change.
/// It closes with `true` once saved, otherwise `false` (or null, by the
/// back button).
///
/// Nothing is chosen in advance and nothing is inferred: not from a +92
/// number, the app's language, the device's settings, the store or a
/// currency. The device's time zone is read only once a country is chosen,
/// only for that country's zones, and only offered: the person takes it
/// with a button. The answer is the person's alone; it never answers a
/// portfolio's question whether its owner lives abroad.
class ResidenceScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return MmPage(title: l10n.residenceTitle, body: const _Loading());
    }
    final state = ref.watch(residenceProvider(userId));
    void retry() => ref.invalidate(residenceProvider(userId));
    final snapshot = state.value;
    if (snapshot != null) {
      return _ResidenceForm(
        key: ValueKey(userId),
        userId: userId,
        residence: snapshot.value,
        notice: RefreshNotice(state: state, onRetry: retry),
      );
    }
    return MmPage(
      title: l10n.residenceTitle,
      body: switch (state.error) {
        final error? => MmErrorState(
          title: l10n.residenceLoadFailedTitle,
          message: failureMessage(l10n, AppFailure.from(error)),
          onRetry: retry,
        ),
        _ => const _Loading(),
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loadingResidence,
    child: const MmSkeleton.text(lines: 6),
  );
}

/// Closes the residence screen with [saved]; opened by its address alone
/// (nothing to go back to), it goes to Settings, where it lives.
void _close(BuildContext context, {required bool saved}) {
  if (context.canPop()) {
    context.pop(saved);
  } else {
    context.go(Routes.settings);
  }
}

class _ResidenceForm extends ConsumerStatefulWidget {
  const new({
    required this.userId,
    required this.residence,
    required this.notice,
    super.key,
  });

  final String userId;

  /// The residence as stored (or saved on this device).
  final AccountResidence residence;

  /// Says when the residence on screen may be stale.
  final Widget notice;

  @override
  ConsumerState<_ResidenceForm> createState() => _ResidenceFormState();
}

class _ResidenceFormState extends ConsumerState<_ResidenceForm>
    with CommandState {
  ResidenceAnswer? _answer;
  CountryCode? _country;

  /// The chosen zone; [TimeZoneId.pakistan] is the "Pakistan time" choice,
  /// stored as no zone.
  TimeZoneId? _zone;

  /// Whether Save was pressed: errors show from then on, as things change.
  bool _submitted = false;

  /// Whether the person changed anything, so a newer stored answer (the
  /// server's, after the saved copy) no longer replaces the form.
  bool _touched = false;

  final GlobalKey _answerKey = GlobalKey(debugLabel: 'residence answer');
  final GlobalKey _countryKey = GlobalKey(debugLabel: 'residence country');
  final GlobalKey _zoneKey = GlobalKey(debugLabel: 'residence zone');

  @override
  void initState() {
    super.initState();
    _start(widget.residence);
  }

  @override
  void didUpdateWidget(_ResidenceForm old) {
    super.didUpdateWidget(old);
    if (!_touched && widget.residence != old.residence) {
      _start(widget.residence);
    }
  }

  /// Starts from [stored]: nothing chosen when the person never answered;
  /// otherwise their answer. A country or zone this build does not know
  /// starts empty, so saving asks for one it knows.
  void _start(AccountResidence stored) {
    final country = stored.residence.country;
    final zone = stored.residence.timeZone;
    if (!stored.stated) {
      _answer = null;
      _country = null;
      _zone = null;
    } else if (country == null) {
      _answer = ResidenceAnswer.notSaying;
    } else if (country.isPakistan) {
      _answer = ResidenceAnswer.inPakistan;
    } else {
      _answer = ResidenceAnswer.abroad;
      _country = country.isKnown ? country : null;
      // No zone is "Pakistan time", the one way it is stored without one.
      _zone = zone == null || zone.isPakistan
          ? TimeZoneId.pakistan
          : (country.timeZones.contains(zone) ? zone : null);
    }
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _touched = true;
    failure = null;
  });

  String? _answerError(AppLocalizations l10n) =>
      _submitted && _answer == null ? l10n.chooseAnswerError : null;

  bool get _abroad => _answer == ResidenceAnswer.abroad;

  String? _countryError(AppLocalizations l10n) =>
      _submitted && _abroad && _country == null
      ? l10n.residenceCountryRequired
      : null;

  String? _zoneError(AppLocalizations l10n) =>
      _submitted && _abroad && _zone == null
      ? l10n.residenceZoneRequired
      : null;

  /// Brings the first field with an error into view (at large text sizes
  /// it may be below the fold), once the errors are on screen.
  void _showFirstError(AppLocalizations l10n) {
    final key = _answerError(l10n) != null
        ? _answerKey
        : _countryError(l10n) != null
        ? _countryKey
        : _zoneKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target);
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _submitted = true);
    final answer = _answer;
    final invalid =
        answer == null || (_abroad && (_country == null || _zone == null));
    if (invalid) {
      _showFirstError(l10n);
      return;
    }
    final (country, zone) = switch (answer) {
      ResidenceAnswer.inPakistan => (CountryCode.pakistan, null),
      ResidenceAnswer.abroad => (_country, _zone!.isPakistan ? null : _zone),
      ResidenceAnswer.notSaying => (null, null),
    };
    final done = await runCommand(
      () => ref
          .read(residenceProvider(widget.userId).notifier)
          .save(country: country, timeZone: zone),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.residenceSaved,
        tone: MmBannerTone.success,
      ),
    );
    _close(context, saved: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final answer = _answer;
    return MmPage(
      title: l10n.residenceTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.notice,
          if (failure != null) ...[
            if (rejectedReason == 'constraint_violation')
              MmBanner(
                tone: MmBannerTone.error,
                message: l10n.residenceNotSaved,
              )
            else
              FailureBanner(failure: failure),
            const SizedBox(height: MmSpace.s4),
          ],
          MmBanner(
            tone: MmBannerTone.info,
            icon: MmIcons.lock,
            message: l10n.residencePrivacy,
          ),
          const SizedBox(height: MmSpace.s4),
          Text(l10n.residenceUse, style: text.bodyLarge),
          const SizedBox(height: MmSpace.s2),
          Text(
            l10n.residencePortfolioNote,
            style: text.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: MmSpace.s6),
          MmRadioGroup<ResidenceAnswer>(
            key: _answerKey,
            label: l10n.residenceQuestion,
            required: true,
            errorText: _answerError(l10n),
            value: answer,
            options: [
              MmOption(
                value: ResidenceAnswer.inPakistan,
                label: l10n.residenceInPakistan,
              ),
              MmOption(
                value: ResidenceAnswer.abroad,
                label: l10n.residenceAbroad,
              ),
              MmOption(
                value: ResidenceAnswer.notSaying,
                label: l10n.residenceNotSaying,
              ),
            ],
            onChanged: busy ? null : (value) => _changed(() => _answer = value),
          ),
          if (answer == ResidenceAnswer.abroad)
            ..._abroadFields(l10n)
          else if (answer != null) ...[
            const SizedBox(height: MmSpace.s4),
            Text(l10n.residencePakistanTimeOnly, style: text.bodyMedium),
          ],
        ],
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: widget.residence.stated
              ? l10n.cancelAction
              : l10n.notNowAction,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => _close(context, saved: false),
        ),
        primary: MmButton(label: l10n.saveAction, busy: busy, onPressed: _save),
      ),
    );
  }

  /// The country, the device's suggestion and the time zone, for someone
  /// who lives abroad.
  List<Widget> _abroadFields(AppLocalizations l10n) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    final country = _country;
    final now = ref.read(nowProvider)();
    final suggestion = country == null
        ? null
        : suggestedZone(ref.watch(deviceTimeZoneProvider), country, now);
    final enabled = !busy;
    return [
      const SizedBox(height: MmSpace.s4),
      MmSelectField<CountryCode>(
        key: _countryKey,
        label: l10n.residenceCountryLabel,
        placeholder: l10n.residenceCountryPlaceholder,
        required: true,
        errorText: _countryError(l10n),
        value: country,
        options: [
          for (final code in countriesInOrder(context))
            MmOption(
              value: code,
              label: countryName(context, code),
              // In Urdu, the English name under it too: many know a
              // country by it.
              description: urdu ? countryNameInEnglish(code) : null,
              searchTerms: countrySearchTerms(code),
            ),
        ],
        onChanged: enabled
            ? (code) => _changed(() {
                _country = code;
                // A zone of another country goes; Pakistan time stays.
                final zone = _zone;
                if (zone != null &&
                    !zone.isPakistan &&
                    !code.timeZones.contains(zone)) {
                  _zone = null;
                }
              })
            : null,
      ),
      if (suggestion != null && suggestion != _zone) ...[
        const SizedBox(height: MmSpace.s4),
        MmBanner(
          tone: MmBannerTone.info,
          icon: MmIcons.clock,
          message: l10n.residenceSuggestion(cityName(context, suggestion)),
          actionLabel: l10n.residenceUseSuggestion(
            cityName(context, suggestion),
          ),
          onAction: enabled ? () => _changed(() => _zone = suggestion) : null,
        ),
      ],
      const SizedBox(height: MmSpace.s4),
      MmSelectField<TimeZoneId>(
        key: _zoneKey,
        label: l10n.residenceZoneLabel,
        helper: l10n.residenceZoneHelper,
        placeholder: l10n.residenceZonePlaceholder,
        required: true,
        errorText: _zoneError(l10n),
        value: _zone,
        options: [
          if (country != null)
            for (final zone in country.timeZones)
              MmOption(
                value: zone,
                label: cityName(context, zone),
                description: zoneDifference(context, zone, now),
                searchTerms: citySearchTerms(zone),
              ),
          MmOption(
            value: TimeZoneId.pakistan,
            label: l10n.zonePakistanOption,
            description: l10n.zonePakistanOptionHelp,
          ),
        ],
        onChanged: enabled ? (zone) => _changed(() => _zone = zone) : null,
      ),
    ];
  }
}
