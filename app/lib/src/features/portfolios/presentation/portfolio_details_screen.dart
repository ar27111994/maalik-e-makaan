import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The current portfolio's settings, which owners change: its name, what a
/// new tenancy starts with (due day, grace days, yearly increase) and the
/// payment details tenants see on receipts and reminders.
class PortfolioDetailsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) {
      return MmPage(title: l10n.portfolioDetailsTitle, body: const _Loading());
    }
    final state = ref.watch(portfolioDetailsProvider(portfolio.id));
    void retry() => ref.invalidate(portfolioDetailsProvider(portfolio.id));
    final details = state.value?.value;
    if (details != null) {
      return _DetailsForm(
        key: ValueKey(details.id),
        details: details,
        editable: portfolio.role == MemberRole.owner,
        notice: RefreshNotice(state: state, onRetry: retry),
      );
    }
    return MmPage(
      title: l10n.portfolioDetailsTitle,
      body: switch (state.error) {
        final error? => MmErrorState(
          title: l10n.portfolioDetailsLoadFailedTitle,
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
    label: AppLocalizations.of(context).loadingPortfolioDetails,
    child: const MmSkeleton.text(lines: 8),
  );
}

class _DetailsForm extends ConsumerStatefulWidget {
  const new({
    required this.details,
    required this.editable,
    required this.notice,
    super.key,
  });

  final PortfolioDetails details;

  /// Only owners may change the details.
  final bool editable;

  /// Says when the details on screen may be stale.
  final Widget notice;

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> with CommandState {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.details.name);
  late int _dueDay = widget.details.defaultDueDay;
  late int _graceDays = widget.details.defaultGraceDays;
  late final _increment = TextEditingController(
    text: percentFromBasisPoints(widget.details.defaultIncrementBasisPoints),
  );
  late final _landlordName = TextEditingController(
    text: widget.details.landlordName,
  );
  late final _landlordPhone = TextEditingController(
    text: widget.details.landlordPhone?.national.replaceAll(' ', ''),
  );
  late final _raast = TextEditingController(
    text: widget.details.raastId?.national.replaceAll(' ', ''),
  );
  late final _accountTitle = TextEditingController(
    text: widget.details.bankAccountTitle,
  );
  late final _iban = TextEditingController(
    text: widget.details.bankIban?.formatted,
  );
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _increment,
      _landlordName,
      _landlordPhone,
      _raast,
      _accountTitle,
      _iban,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  static PhoneNumber? _phone(String text) =>
      text.trim().isEmpty ? null : PhoneNumber.tryParse(text);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final iban = _iban.text.trim();
    final details = PortfolioDetails(
      id: widget.details.id,
      name: _name.text,
      defaultDueDay: _dueDay,
      defaultGraceDays: _graceDays,
      defaultIncrementBasisPoints: parsePercent(_increment.text)!,
      landlordName: _landlordName.text,
      landlordPhone: _phone(_landlordPhone.text),
      raastId: _phone(_raast.text),
      bankAccountTitle: _accountTitle.text,
      bankIban: iban.isEmpty ? null : Iban.tryParse(iban),
    );
    final done = await runCommand(
      () => ref
          .read(portfolioDetailsProvider(widget.details.id).notifier)
          .save(details),
    );
    if (!done || !mounted) return;
    await showMmSnackbar(
      context,
      message: l10n.portfolioDetailsSaved,
      tone: MmBannerTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final editable = widget.editable;
    String? phoneError(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      return PhoneNumber.tryParse(text) == null ? l10n.validationPhone : null;
    }

    final digits = [FilteringTextInputFormatter.allow(RegExp('[0-9+۰-۹٠-٩]'))];
    return MmPage(
      title: l10n.portfolioDetailsTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.notice,
            if (failure != null) FailureBanner(failure: failure),
            MmTextField(
              label: l10n.portfolioNameLabel,
              controller: _name,
              required: true,
              enabled: editable,
              maxLength: PortfolioMembership.maxNameLength,
              textCapitalization: TextCapitalization.words,
              validator: (value) => Validators.name(
                l10n,
                value,
                maxLength: PortfolioMembership.maxNameLength,
              ),
              onChanged: _changed,
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenancyDefaultsSection,
              description: l10n.tenancyDefaultsHelp,
              children: [
                MmSelectField<int>(
                  label: l10n.dueDayLabel,
                  helper: l10n.dueDayHelper,
                  options: [
                    for (
                      var day = PortfolioDetails.firstDueDay;
                      day <= PortfolioDetails.lastDueDay;
                      day++
                    )
                      MmOption(value: day, label: '$day'),
                  ],
                  value: _dueDay,
                  onChanged: editable
                      ? (day) => setState(() => _dueDay = day)
                      : null,
                ),
                MmStepperField(
                  label: l10n.graceDaysLabel,
                  helper: l10n.graceDaysHelper,
                  value: _graceDays,
                  min: 0,
                  max: PortfolioDetails.maxGraceDays,
                  decreaseLabel: l10n.fewerDaysAction,
                  increaseLabel: l10n.moreDaysAction,
                  format: l10n.dayCount,
                  onChanged: editable
                      ? (days) => setState(() => _graceDays = days)
                      : null,
                ),
                MmTextField(
                  label: l10n.incrementLabel,
                  controller: _increment,
                  required: true,
                  enabled: editable,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => Validators.percent(l10n, value),
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.paymentDetailsSection,
              description: l10n.paymentDetailsHelp,
              children: [
                MmTextField(
                  label: l10n.landlordNameLabel,
                  controller: _landlordName,
                  optional: true,
                  enabled: editable,
                  maxLength: PortfolioDetails.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: PortfolioDetails.maxNameLength,
                    required: false,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.landlordPhoneLabel,
                  controller: _landlordPhone,
                  optional: true,
                  enabled: editable,
                  helper: l10n.phoneHelper,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digits,
                  validator: phoneError,
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.raastIdLabel,
                  controller: _raast,
                  optional: true,
                  enabled: editable,
                  helper: l10n.raastIdHelper,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digits,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final phone = PhoneNumber.tryParse(text);
                    return phone != null && phone.isMobile
                        ? null
                        : l10n.validationRaast;
                  },
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.bankAccountTitleLabel,
                  controller: _accountTitle,
                  optional: true,
                  enabled: editable,
                  maxLength: PortfolioDetails.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: PortfolioDetails.maxNameLength,
                    required: false,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.ibanLabel,
                  controller: _iban,
                  optional: true,
                  enabled: editable,
                  helper: l10n.ibanHelper,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    return Iban.tryParse(text) == null
                        ? l10n.validationIban
                        : null;
                  },
                  onChanged: _changed,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomBar: editable
          ? MmActionBar(
              secondary: MmButton(
                label: l10n.cancelAction,
                variant: MmButtonVariant.secondary,
                onPressed: busy ? null : () => context.go(Routes.more),
              ),
              primary: MmButton(
                label: l10n.saveAction,
                busy: busy,
                onPressed: _save,
              ),
            )
          : null,
    );
  }
}
