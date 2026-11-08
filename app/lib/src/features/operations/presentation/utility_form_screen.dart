import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/place_fields.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Upper-cases what is typed into an identifier field, as it is stored.
class _UpperCase extends TextInputFormatter {
  const new();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// The error of an identifier field ([pattern] once normalised), or null.
String? identifierError(
  AppLocalizations l10n,
  String? text,
  RegExp pattern,
  String message,
) {
  final value = normalizeIdentifier(text ?? '');
  if (value.isEmpty) return null;
  return pattern.hasMatch(value) ? null : message;
}

/// A hint when [text], a reference number, has another number of digits
/// than [provider]'s bills carry; null when it matches or none is known.
String? referenceHint(
  AppLocalizations l10n,
  String text,
  UtilityProvider provider,
) {
  final digits = provider.referenceDigits;
  final value = normalizeIdentifier(text);
  if (digits == null || value.isEmpty) return null;
  final count = value.replaceAll(RegExp('[^0-9]'), '').length;
  return count == digits ? null : l10n.referenceDigitsHint(digits);
}

/// Adding a utility connection, or editing one ([accountId]) (UTIL-01):
/// where it is, what supplies it, its numbers, whose name it is in, and
/// who pays. Its property is fixed once added.
class UtilityFormScreen extends ConsumerWidget {
  const new({this.accountId, super.key});

  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = accountId;
    if (id == null) return const _UtilityForm();
    final state = ref.watch(utilityAccountProvider(id));
    if (state.value?.value.account case final account?) {
      return _UtilityForm(key: ValueKey(account.id), account: account);
    }
    return MmPage(
      title: l10n.editConnectionTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(utilityAccountProvider(id)),
        loadingLabel: l10n.loadingUtility,
        failedTitle: l10n.utilityLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _UtilityForm extends ConsumerStatefulWidget {
  const new({this.account, super.key});

  final UtilityAccount? account;

  @override
  ConsumerState<_UtilityForm> createState() => _UtilityFormState();
}

class _UtilityFormState extends ConsumerState<_UtilityForm> with CommandState {
  final _form = GlobalKey<FormState>();
  late final UtilityAccount? _old = widget.account;

  /// Names this attempt to add: a retry adds nothing more.
  final String _attempt = newUuid();

  late PlaceChoice _place = (
    propertyId: _old?.propertyId,
    unitId: _old?.unitId,
  );
  late UtilityType _type = _old?.type ?? UtilityType.electricity;
  late UtilityProvider? _provider = _old?.provider;
  late final _providerOther = TextEditingController(text: _old?.providerOther);
  late final _reference = TextEditingController(text: _old?.referenceNumber);
  late final _customerId = TextEditingController(text: _old?.customerId);
  late final _meter = TextEditingController(text: _old?.meterNumber);
  late final _title = TextEditingController(text: _old?.accountTitle);
  late bool _inMyName = _old?.inLandlordName ?? true;
  late bool _subMeter = _old?.isSubMeter ?? false;
  late bool _protected = _old?.isProtectedConsumer ?? false;
  late BillResponsibility _responsibility =
      _old?.responsibility ?? BillResponsibility.tenant;
  late final _notes = TextEditingController(text: _old?.notes);
  AutovalidateMode _validation = AutovalidateMode.disabled;
  bool _tried = false;

  @override
  void dispose() {
    for (final controller in [
      _providerOther,
      _reference,
      _customerId,
      _meter,
      _title,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  Future<void> _save(String portfolioId) async {
    final l10n = AppLocalizations.of(context);
    final valid = _form.currentState!.validate();
    setState(() => _tried = true);
    final propertyId = _place.propertyId;
    final provider = _provider;
    if (!valid || propertyId == null || provider == null) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final draft = UtilityAccountDraft(
      propertyId: propertyId,
      unitId: _place.unitId,
      type: _type,
      provider: provider,
      providerOther: _providerOther.text,
      referenceNumber: _reference.text,
      customerId: _customerId.text,
      meterNumber: _meter.text,
      accountTitle: _title.text,
      inLandlordName: _inMyName,
      isSubMeter: _subMeter,
      isProtectedConsumer: _protected,
      responsibility: _responsibility,
      notes: _notes.text,
    );
    late UtilityAccount saved;
    final old = _old;
    final done = await runCommand(() async {
      saved = old == null
          ? await ref
                .read(
                  utilityAccountsProvider((
                    portfolioId: portfolioId,
                    archived: false,
                  )).notifier,
                )
                .create(_attempt, draft)
          : await ref.read(utilityAccountProvider(old.id).notifier).save(draft);
    });
    if (!done || !mounted) return;
    // A retry finds the connection its first try stored, which the connection
    // lost: fields changed since then were not saved.
    final earlier = old == null && UtilityAccountDraft.of(saved) != draft;
    unawaited(
      showMmSnackbar(
        context,
        message: earlier
            ? l10n.savedEarlierUnchanged
            : old == null
            ? l10n.connectionAdded
            : l10n.connectionSaved,
        tone: earlier ? MmBannerTone.warning : MmBannerTone.success,
      ),
    );
    context.go(Routes.utility(saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (_old case final old?) {
      // Keeps what this form changes read while it is open.
      ref.listen(utilityAccountProvider(old.id), (_, _) {});
    } else if (portfolio != null) {
      ref.listen(
        utilityAccountsProvider((portfolioId: portfolio.id, archived: false)),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final duplicate = rejectedReason == 'duplicate_utility_reference';
    final provider = _provider;
    final hint = provider == null
        ? null
        : referenceHint(l10n, _reference.text, provider);
    return MmPage(
      title: _old == null ? l10n.newConnectionTitle : l10n.editConnectionTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && !duplicate) FailureBanner(failure: failure),
            MmFormSection(
              title: l10n.connectionSectionWhere,
              children: [
                if (portfolio != null)
                  PlaceFields(
                    portfolioId: portfolio.id,
                    value: _place,
                    propertyRequired: true,
                    propertyFixed: _old != null,
                    propertyName: _old?.propertyName,
                    unitLabel: _old?.unitLabel,
                    propertyError: _tried && _place.propertyId == null
                        ? l10n.validationRequired
                        : null,
                    onChanged: (place) => setState(() => _place = place),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.connectionSectionSupplier,
              children: [
                MmSelectField<UtilityType>(
                  label: l10n.utilityTypeLabel,
                  required: true,
                  options: [
                    for (final type in UtilityType.values)
                      MmOption(value: type, label: l10n.utilityType(type)),
                  ],
                  value: _type,
                  onChanged: (type) => setState(() {
                    _type = type;
                    if (_provider case final p?
                        when !type.providers.contains(p)) {
                      _provider = null;
                    }
                  }),
                ),
                MmSelectField<UtilityProvider>(
                  label: l10n.providerLabel,
                  required: true,
                  errorText: _tried && _provider == null
                      ? l10n.validationRequired
                      : null,
                  options: [
                    for (final provider in _type.providers)
                      MmOption(
                        value: provider,
                        label: l10n.utilityProvider(provider),
                      ),
                  ],
                  value: provider,
                  onChanged: (provider) => setState(() => _provider = provider),
                ),
                if (provider == UtilityProvider.other)
                  MmTextField(
                    label: l10n.providerNameLabel,
                    controller: _providerOther,
                    optional: true,
                    maxLength: UtilityAccount.maxProviderOtherLength,
                    inputFormatters: codePointLimit(
                      UtilityAccount.maxProviderOtherLength,
                    ),
                    validator: (value) => Validators.name(
                      l10n,
                      value,
                      maxLength: UtilityAccount.maxProviderOtherLength,
                      required: false,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.connectionSectionNumbers,
              children: [
                MmTextField(
                  label: l10n.referenceNumberLabel,
                  controller: _reference,
                  optional: true,
                  helper: hint ?? l10n.referenceNumberHelp,
                  maxLength: UtilityAccount.maxReferenceLength,
                  errorText: duplicate ? failureMessage(l10n, failure!) : null,
                  leftToRight: true,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: const [_UpperCase()],
                  validator: (value) => identifierError(
                    l10n,
                    value,
                    UtilityAccount.referencePattern,
                    l10n.referenceNumberInvalid,
                  ),
                  onChanged: (value) {
                    _changed();
                    setState(() {});
                  },
                ),
                MmTextField(
                  label: l10n.customerIdLabel,
                  controller: _customerId,
                  optional: true,
                  maxLength: UtilityAccount.maxCustomerIdLength,
                  leftToRight: true,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: const [_UpperCase()],
                  validator: (value) => identifierError(
                    l10n,
                    value,
                    UtilityAccount.customerIdPattern,
                    l10n.customerIdInvalid,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.meterNumberLabel,
                  controller: _meter,
                  optional: true,
                  maxLength: UtilityAccount.maxMeterLength,
                  leftToRight: true,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: const [_UpperCase()],
                  validator: (value) => identifierError(
                    l10n,
                    value,
                    UtilityAccount.meterPattern,
                    l10n.meterNumberInvalid,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.nameOnBillLabel,
                  controller: _title,
                  optional: true,
                  maxLength: UtilityAccount.maxTitleLength,
                  inputFormatters: codePointLimit(
                    UtilityAccount.maxTitleLength,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.connectionSectionWho,
              children: [
                MmSwitchTile(
                  label: l10n.inMyNameLabel,
                  description: l10n.inMyNameHelp,
                  value: _inMyName,
                  onChanged: (value) => setState(() => _inMyName = value),
                ),
                MmSelectField<BillResponsibility>(
                  label: l10n.whoPaysLabel,
                  required: true,
                  options: [
                    for (final who in BillResponsibility.values)
                      MmOption(value: who, label: l10n.responsibility(who)),
                  ],
                  value: _responsibility,
                  onChanged: (who) => setState(() => _responsibility = who),
                ),
                MmSwitchTile(
                  label: l10n.subMeterLabel,
                  description: l10n.subMeterHelp,
                  value: _subMeter,
                  onChanged: (value) => setState(() => _subMeter = value),
                ),
                if (_type == UtilityType.electricity)
                  MmSwitchTile(
                    label: l10n.protectedLabel,
                    description: l10n.protectedHelp(ProtectedTariff.limit),
                    value: _protected,
                    onChanged: (value) => setState(() => _protected = value),
                  ),
                MmTextField(
                  label: l10n.notesLabel,
                  controller: _notes,
                  optional: true,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: UtilityAccount.maxNotesLength,
                  inputFormatters: codePointLimit(
                    UtilityAccount.maxNotesLength,
                  ),
                  keyboardType: TextInputType.multiline,
                  onChanged: _changed,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomBar: MmActionBar(
        secondary: MmButton(
          label: l10n.cancelAction,
          variant: MmButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => context.go(
                  _old == null ? Routes.utilities : Routes.utility(_old.id),
                ),
        ),
        primary: MmButton(
          label: l10n.saveAction,
          busy: busy,
          onPressed: portfolio == null ? null : () => _save(portfolio.id),
        ),
      ),
    );
  }
}
