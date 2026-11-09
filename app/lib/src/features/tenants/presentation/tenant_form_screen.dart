import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Adding a tenant, or editing one ([tenantId]) (TEN-01 to TEN-03): who
/// they are, their CNIC (checked as typed), how to reach them, work and
/// addresses, an emergency contact, two references, household and tax, and
/// the consent the landlord recorded. Before saving, another tenant in use
/// with the same CNIC or phone is pointed out.
class TenantFormScreen extends ConsumerWidget {
  const new({this.tenantId, super.key});

  final String? tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = tenantId;
    if (id == null) return const _TenantForm(tenant: null);
    final state = ref.watch(tenantProvider(id));
    final tenant = state.value?.value;
    if (tenant != null) {
      return _TenantForm(key: ValueKey(tenant.id), tenant: tenant);
    }
    return MmPage(
      title: l10n.editTenantTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(tenantProvider(id)),
        loadingLabel: l10n.loadingTenant,
        failedTitle: l10n.tenantLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _TenantForm extends ConsumerStatefulWidget {
  const new({required this.tenant, super.key});

  final Tenant? tenant;

  @override
  ConsumerState<_TenantForm> createState() => _TenantFormState();
}

class _TenantFormState extends ConsumerState<_TenantForm> with CommandState {
  final _form = GlobalKey<FormState>();
  late final Tenant? _old = widget.tenant;
  final String _attempt = newUuid();

  late TenantKind _kind = _old?.kind ?? TenantKind.individual;
  late final _name = TextEditingController(text: _old?.fullName);
  late GuardianRelation? _relation = _old?.guardianRelation;
  late final _guardian = TextEditingController(text: _old?.guardianName);
  late Cnic? _cnic = _old?.cnic;
  late CalendarDate? _cnicExpiry = _old?.cnicExpiry;
  late final _ntn = TextEditingController(text: _old?.ntn);
  late PhoneNumber? _phone = _old?.phone;
  late PhoneNumber? _altPhone = _old?.altPhone;
  late final _email = TextEditingController(text: _old?.email);
  late final _occupation = TextEditingController(text: _old?.occupation);
  late final _employer = TextEditingController(text: _old?.employer);
  late final _permanent = TextEditingController(text: _old?.permanentAddress);
  late final _previous = TextEditingController(text: _old?.previousAddress);
  late final _emergencyName = TextEditingController(text: _old?.emergencyName);
  late PhoneNumber? _emergencyPhone = _old?.emergencyPhone;
  late final _emergencyRelation = TextEditingController(
    text: _old?.emergencyRelation,
  );
  late final _ref1Name = TextEditingController(text: _old?.reference1.name);
  late PhoneNumber? _ref1Phone = _old?.reference1.phone;
  late final _ref2Name = TextEditingController(text: _old?.reference2.name);
  late PhoneNumber? _ref2Phone = _old?.reference2.phone;
  late final _household = TextEditingController(
    text: _old?.householdSize?.toString(),
  );
  late bool _withholding = _old?.deductsWithholdingTax ?? false;
  late bool _consent = _old?.consentRecordedAt != null;
  late final _consentNote = TextEditingController(text: _old?.consentNote);
  late final _notes = TextEditingController(text: _old?.notes);
  AutovalidateMode _validation = AutovalidateMode.disabled;

  List<TextEditingController> get _controllers => [
    _name,
    _guardian,
    _ntn,
    _email,
    _occupation,
    _employer,
    _permanent,
    _previous,
    _emergencyName,
    _emergencyRelation,
    _ref1Name,
    _ref2Name,
    _household,
    _consentNote,
    _notes,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  Tenant _tenant() => Tenant(
    id: _old?.id ?? _attempt,
    kind: _kind,
    fullName: _name.text,
    guardianName: _guardian.text,
    guardianRelation: _guardian.text.trim().isEmpty ? null : _relation,
    cnic: _cnic,
    cnicExpiry: _cnicExpiry,
    ntn: _ntn.text,
    phone: _phone,
    altPhone: _altPhone,
    email: _email.text,
    occupation: _occupation.text,
    employer: _employer.text,
    permanentAddress: _permanent.text,
    previousAddress: _previous.text,
    emergencyName: _emergencyName.text,
    emergencyPhone: _emergencyPhone,
    emergencyRelation: _emergencyRelation.text,
    reference1: (name: _ref1Name.text, phone: _ref1Phone),
    reference2: (name: _ref2Name.text, phone: _ref2Phone),
    householdSize: int.tryParse(normalizeDigits(_household.text).trim()),
    deductsWithholdingTax: _withholding,
    // The first time consent is recorded is the moment it was given.
    consentRecordedAt: _consent
        ? _old?.consentRecordedAt ?? DateTime.now().toUtc()
        : null,
    consentNote: _consentNote.text,
    notes: _notes.text,
  );

  Future<void> _save(String portfolioId) async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final tenant = _tenant();
    final list = tenantsProvider((
      portfolioId: portfolioId,
      archived: false,
      search: '',
    ));
    var matches = const <TenantMatch>[];
    final checked = await runCommand(() async {
      final phoneChanged = tenant.phone != _old?.phone;
      final cnicChanged = tenant.cnic != _old?.cnic;
      if (!phoneChanged && !cnicChanged) return;
      matches = await ref
          .read(list.notifier)
          .matches(
            cnic: cnicChanged ? tenant.cnic : null,
            phone: phoneChanged ? tenant.phone : null,
            exceptId: _old?.id,
          );
    });
    if (!checked || !mounted) return;
    if (matches.isNotEmpty) {
      final go = await showMmConfirmDialog(
        context,
        title: l10n.duplicateTenantTitle,
        message: l10n.duplicateTenantBody(
          matches.map((match) => match.fullName).join(', '),
        ),
        confirmLabel: l10n.saveAnywayAction,
      );
      if (!go || !mounted) return;
    }
    late Tenant saved;
    final done = await runCommand(() async {
      saved = _old == null
          ? await ref.read(list.notifier).create(tenant)
          : await ref.read(tenantProvider(tenant.id).notifier).save(tenant);
    });
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: _old == null
            ? l10n.tenantAdded(
                inSentence(saved.fullName, Directionality.of(context)),
              )
            : l10n.tenantSaved(
                inSentence(saved.fullName, Directionality.of(context)),
              ),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.tenant(saved.id));
  }

  String? _optionalName(AppLocalizations l10n, String? value, int max) =>
      Validators.name(l10n, value, maxLength: max, required: false);

  MmTextField _text(
    AppLocalizations l10n, {
    required String label,
    required TextEditingController controller,
    required int maxLength,
    TextCapitalization capitalization = TextCapitalization.words,
  }) => MmTextField(
    label: label,
    controller: controller,
    optional: true,
    maxLength: maxLength,
    inputFormatters: codePointLimit(maxLength),
    textCapitalization: capitalization,
    validator: (value) => _optionalName(l10n, value, maxLength),
    onChanged: _changed,
  );

  MmPhoneField _phoneField(
    AppLocalizations l10n, {
    required String label,
    required PhoneNumber? value,
    required ValueChanged<PhoneNumber?> onChanged,
  }) => MmPhoneField(
    label: label,
    value: value,
    optional: true,
    invalidText: l10n.validationPhone,
    onChanged: (phone) {
      _changed();
      setState(() => onChanged(phone));
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (_old != null) ref.listen(tenantProvider(_old.id), (_, _) {});
    if (portfolio != null) {
      ref.listen(
        tenantsProvider((
          portfolioId: portfolio.id,
          archived: false,
          search: '',
        )),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final cnicError = rejectedReason == 'duplicate_cnic'
        ? failureMessage(l10n, failure!)
        : null;
    final today = dates.today(context);
    return MmPage(
      title: _old == null ? l10n.newTenantTitle : l10n.editTenantTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && cnicError == null)
              FailureBanner(failure: failure),
            MmFormSection(
              title: l10n.tenantSectionWho,
              children: [
                MmSegmentedControl<TenantKind>(
                  semanticLabel: l10n.tenantKindLabel,
                  expand: true,
                  segments: [
                    for (final kind in const [
                      TenantKind.individual,
                      TenantKind.company,
                      TenantKind.government,
                    ])
                      MmSegment(value: kind, label: l10n.tenantKind(kind)),
                  ],
                  selected: _kind,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                MmTextField(
                  label: l10n.fullNameTenantLabel,
                  controller: _name,
                  required: true,
                  maxLength: Tenant.maxNameLength,
                  inputFormatters: codePointLimit(Tenant.maxNameLength),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Tenant.maxNameLength,
                  ),
                  onChanged: _changed,
                ),
                if (_kind == TenantKind.individual) ...[
                  MmSelectField<GuardianRelation>(
                    label: l10n.guardianRelationLabel,
                    optional: true,
                    options: [
                      for (final relation in GuardianRelation.values)
                        MmOption(
                          value: relation,
                          label: l10n.guardianRelation(relation),
                        ),
                    ],
                    value: _relation,
                    onChanged: (relation) =>
                        setState(() => _relation = relation),
                  ),
                  _text(
                    l10n,
                    label: l10n.guardianNameLabel,
                    controller: _guardian,
                    maxLength: Tenant.maxNameLength,
                  ),
                ],
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionIdentity,
              children: [
                MmCnicField(
                  label: l10n.cnicLabel,
                  value: _cnic,
                  optional: true,
                  helper: l10n.cnicHelper,
                  errorText: cnicError,
                  invalidText: l10n.validationCnic,
                  onChanged: (cnic) {
                    _changed();
                    setState(() => _cnic = cnic);
                  },
                ),
                MmDateField(
                  label: l10n.cnicExpiryLabel,
                  value: _cnicExpiry,
                  optional: true,
                  firstDate: CalendarDate(2000, 1, 1),
                  lastDate: today.addYears(20),
                  onChanged: (date) => setState(() => _cnicExpiry = date),
                ),
                MmTextField(
                  label: l10n.ntnLabel,
                  controller: _ntn,
                  optional: true,
                  maxLength: 15,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    final text = (value ?? '').trim().toUpperCase();
                    if (text.isEmpty) return null;
                    return Tenant.ntnPattern.hasMatch(text)
                        ? null
                        : l10n.validationNtn;
                  },
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionContact,
              children: [
                _phoneField(
                  l10n,
                  label: l10n.phoneLabel,
                  value: _phone,
                  onChanged: (phone) => _phone = phone,
                ),
                _phoneField(
                  l10n,
                  label: l10n.altPhoneLabel,
                  value: _altPhone,
                  onChanged: (phone) => _altPhone = phone,
                ),
                MmTextField(
                  label: l10n.emailOptionalLabel,
                  controller: _email,
                  optional: true,
                  maxLength: 254,
                  inputFormatters: codePointLimit(254),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? null
                      : Validators.email(l10n, value),
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionWork,
              children: [
                _text(
                  l10n,
                  label: l10n.occupationLabel,
                  controller: _occupation,
                  maxLength: Tenant.maxOccupationLength,
                  capitalization: TextCapitalization.sentences,
                ),
                _text(
                  l10n,
                  label: l10n.employerLabel,
                  controller: _employer,
                  maxLength: Tenant.maxNameLength,
                ),
                _text(
                  l10n,
                  label: l10n.permanentAddressLabel,
                  controller: _permanent,
                  maxLength: Tenant.maxAddressLength,
                  capitalization: TextCapitalization.sentences,
                ),
                _text(
                  l10n,
                  label: l10n.previousAddressLabel,
                  controller: _previous,
                  maxLength: Tenant.maxAddressLength,
                  capitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionEmergency,
              children: [
                _text(
                  l10n,
                  label: l10n.contactNameLabel,
                  controller: _emergencyName,
                  maxLength: Tenant.maxNameLength,
                ),
                _text(
                  l10n,
                  label: l10n.contactRelationLabel,
                  controller: _emergencyRelation,
                  maxLength: Tenant.maxRelationLength,
                  capitalization: TextCapitalization.sentences,
                ),
                _phoneField(
                  l10n,
                  label: l10n.phoneLabel,
                  value: _emergencyPhone,
                  onChanged: (phone) => _emergencyPhone = phone,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionReferences,
              children: [
                _text(
                  l10n,
                  label: l10n.referenceNameLabel(1),
                  controller: _ref1Name,
                  maxLength: Tenant.maxNameLength,
                ),
                _phoneField(
                  l10n,
                  label: l10n.referencePhoneLabel(1),
                  value: _ref1Phone,
                  onChanged: (phone) => _ref1Phone = phone,
                ),
                _text(
                  l10n,
                  label: l10n.referenceNameLabel(2),
                  controller: _ref2Name,
                  maxLength: Tenant.maxNameLength,
                ),
                _phoneField(
                  l10n,
                  label: l10n.referencePhoneLabel(2),
                  value: _ref2Phone,
                  onChanged: (phone) => _ref2Phone = phone,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionHousehold,
              children: [
                MmTextField(
                  label: l10n.householdSizeLabel,
                  controller: _household,
                  optional: true,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.wholeNumber(
                    l10n,
                    value,
                    min: 1,
                    max: Tenant.maxHousehold,
                  ),
                  onChanged: _changed,
                ),
                MmSwitchTile(
                  label: l10n.withholdingTaxLabel,
                  description: l10n.withholdingTaxHelp,
                  value: _withholding,
                  onChanged: (value) => setState(() => _withholding = value),
                ),
                MmTextField(
                  label: l10n.notesLabel,
                  controller: _notes,
                  optional: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: Tenant.maxNotesLength,
                  inputFormatters: codePointLimit(Tenant.maxNotesLength),
                  keyboardType: TextInputType.multiline,
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.tenantSectionConsent,
              children: [
                MmCheckboxTile(
                  label: l10n.consentLabel,
                  value: _consent,
                  onChanged: (value) =>
                      setState(() => _consent = value ?? false),
                ),
                if (_consent)
                  _text(
                    l10n,
                    label: l10n.consentNoteLabel,
                    controller: _consentNote,
                    maxLength: Tenant.maxConsentLength,
                    capitalization: TextCapitalization.sentences,
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
                  _old == null ? Routes.tenants : Routes.tenant(_old.id),
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
