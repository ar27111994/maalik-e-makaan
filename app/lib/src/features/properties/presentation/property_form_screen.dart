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
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Adding a property, or editing one ([propertyId]) (PROP-01): what it is,
/// where it is (the province decides the compliance rules, shown as soon
/// as it is chosen), its size and its value.
class PropertyFormScreen extends ConsumerWidget {
  const new({this.propertyId, super.key});

  /// The property edited; null to add one.
  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = propertyId;
    if (id == null) return const _PropertyForm(property: null);
    final state = ref.watch(propertyProvider(id));
    final property = state.value?.value;
    if (property != null) {
      return _PropertyForm(key: ValueKey(property.id), property: property);
    }
    return MmPage(
      title: l10n.editPropertyTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(propertyProvider(id)),
        loadingLabel: l10n.loadingProperty,
        failedTitle: l10n.propertyLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PropertyForm extends ConsumerStatefulWidget {
  const new({required this.property, super.key});

  final Property? property;

  @override
  ConsumerState<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends ConsumerState<_PropertyForm>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final Property? _old = widget.property;

  /// Names this attempt to add: a retry adds nothing more.
  final String _attempt = newUuid();

  late final _name = TextEditingController(text: _old?.name);
  late PropertyType _type = _old?.type ?? PropertyType.house;
  late final _address = TextEditingController(text: _old?.addressLine);
  late final _locality = TextEditingController(text: _old?.locality);
  late final _city = TextEditingController(text: _old?.city);
  late Province? _province = _old?.province;
  late final _plotSize = TextEditingController(
    text: _old?.plotSize?.toString(),
  );
  late AreaUnit? _plotUnit = _old?.plotSizeUnit ?? AreaUnit.marla;
  late final _covered = TextEditingController(
    text: _old?.coveredAreaSqft?.toString(),
  );
  late final _year = TextEditingController(text: _old?.yearBuilt?.toString());
  late Money? _price = _old?.purchasePrice;
  late CalendarDate? _purchasedOn = _old?.purchasedOn;
  late Money? _value = _old?.estimatedValue;
  late CalendarDate? _valuedOn = _old?.valueEstimatedOn;
  late final _taxRef = TextEditingController(text: _old?.propertyTaxRef);
  late final _notes = TextEditingController(text: _old?.notes);
  AutovalidateMode _validation = AutovalidateMode.disabled;
  bool _provinceMissing = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _locality,
      _city,
      _plotSize,
      _covered,
      _year,
      _taxRef,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    if (failure != null) setState(() => failure = null);
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(normalizeDigits(controller.text).trim());

  Future<void> _save(String portfolioId) async {
    final valid = _form.currentState!.validate();
    setState(() => _provinceMissing = _province == null);
    if (!valid || _province == null) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final size = Hundredths.tryParse(_plotSize.text);
    final property = Property(
      id: _old?.id ?? _attempt,
      name: _name.text,
      type: _type,
      addressLine: _address.text,
      locality: _locality.text,
      city: _city.text,
      province: _province!,
      plotSize: size,
      plotSizeUnit: size == null ? null : _plotUnit,
      coveredAreaSqft: _int(_covered),
      yearBuilt: _int(_year),
      purchasePrice: _price,
      purchasedOn: _purchasedOn,
      estimatedValue: _value,
      valueEstimatedOn: _valuedOn,
      propertyTaxRef: _taxRef.text,
      notes: _notes.text,
    );
    late Property saved;
    final done = await runCommand(() async {
      saved = _old == null
          ? await ref
                .read(
                  propertiesProvider((
                    portfolioId: portfolioId,
                    archived: false,
                  )).notifier,
                )
                .create(property)
          : await ref
                .read(propertyProvider(property.id).notifier)
                .save(property);
    });
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: _old == null
            ? l10n.propertyAdded(
                inSentence(saved.name, Directionality.of(context)),
              )
            : l10n.propertySaved(
                inSentence(saved.name, Directionality.of(context)),
              ),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.property(saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    // Keeps what this form changes read while it is open.
    if (_old != null) ref.listen(propertyProvider(_old.id), (_, _) {});
    if (_old == null && portfolio != null) {
      ref.listen(
        propertiesProvider((portfolioId: portfolio.id, archived: false)),
        (_, _) {},
      );
    }
    final failure = this.failure;
    final nameError = rejectedReason == 'duplicate_property_name'
        ? failureMessage(l10n, failure!)
        : null;
    final today = dates.today(context);
    final firstDay = CalendarDate(1900, 1, 1);
    final province = _province;
    const digits = TextInputType.numberWithOptions(decimal: true);
    return MmPage(
      title: _old == null ? l10n.newPropertyTitle : l10n.editPropertyTitle,
      body: Form(
        key: _form,
        autovalidateMode: _validation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null && nameError == null)
              FailureBanner(failure: failure),
            MmFormSection(
              title: l10n.propertySectionBasics,
              children: [
                MmTextField(
                  label: l10n.propertyNameLabel,
                  controller: _name,
                  required: true,
                  helper: l10n.propertyNameHelper,
                  errorText: nameError,
                  maxLength: Property.maxNameLength,
                  inputFormatters: codePointLimit(Property.maxNameLength),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Property.maxNameLength,
                  ),
                  onChanged: _changed,
                ),
                MmSelectField<PropertyType>(
                  label: l10n.typeLabel,
                  required: true,
                  options: [
                    for (final type in PropertyType.values)
                      MmOption(value: type, label: l10n.propertyType(type)),
                  ],
                  value: _type,
                  onChanged: (type) => setState(() => _type = type),
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.propertySectionLocation,
              children: [
                MmTextField(
                  label: l10n.addressLabel,
                  controller: _address,
                  optional: true,
                  maxLength: Property.maxAddressLength,
                  inputFormatters: codePointLimit(Property.maxAddressLength),
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Property.maxAddressLength,
                    required: false,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.localityLabel,
                  controller: _locality,
                  optional: true,
                  maxLength: Property.maxLocalityLength,
                  inputFormatters: codePointLimit(Property.maxLocalityLength),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Property.maxLocalityLength,
                    required: false,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.cityLabel,
                  controller: _city,
                  required: true,
                  maxLength: Property.maxCityLength,
                  inputFormatters: codePointLimit(Property.maxCityLength),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Property.maxCityLength,
                  ),
                  onChanged: _changed,
                ),
                MmSelectField<Province>(
                  label: l10n.provinceLabel,
                  required: true,
                  helper: l10n.provinceHelper,
                  errorText: _provinceMissing && province == null
                      ? l10n.validationRequired
                      : null,
                  options: [
                    for (final province in Province.values)
                      MmOption(value: province, label: l10n.province(province)),
                  ],
                  value: province,
                  onChanged: (province) => setState(() => _province = province),
                ),
                if (province != null)
                  MmBanner(
                    tone: MmBannerTone.info,
                    icon: MmIcons.police,
                    message: l10n.policeHint(province),
                  ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.propertySectionSize,
              children: [
                MmTextField(
                  label: l10n.plotSizeLabel,
                  controller: _plotSize,
                  optional: true,
                  keyboardType: digits,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final size = Hundredths.tryParse(text);
                    return size == null ||
                            !size.isPositive ||
                            size.compareTo(Property.maxPlotSize) > 0
                        ? l10n.validationPositiveNumber
                        : null;
                  },
                  onChanged: _changed,
                ),
                MmSelectField<AreaUnit>(
                  label: l10n.plotUnitLabel,
                  options: [
                    for (final unit in AreaUnit.values)
                      MmOption(value: unit, label: l10n.areaUnit(unit)),
                  ],
                  value: _plotUnit,
                  onChanged: (unit) => setState(() => _plotUnit = unit),
                ),
                MmTextField(
                  label: l10n.coveredAreaLabel,
                  controller: _covered,
                  optional: true,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.wholeNumber(
                    l10n,
                    value,
                    min: 1,
                    max: Property.maxCoveredArea,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.yearBuiltLabel,
                  controller: _year,
                  optional: true,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.wholeNumber(
                    l10n,
                    value,
                    min: Property.firstYear,
                    max: Property.lastYear,
                  ),
                  onChanged: _changed,
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s8),
            MmFormSection(
              title: l10n.propertySectionValue,
              children: [
                MmMoneyField(
                  label: l10n.purchasePriceLabel,
                  value: _price,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  onChanged: (amount) => setState(() => _price = amount),
                ),
                MmDateField(
                  label: l10n.purchasedOnLabel,
                  value: _purchasedOn,
                  optional: true,
                  firstDate: firstDay,
                  lastDate: today,
                  onChanged: (date) => setState(() => _purchasedOn = date),
                ),
                MmMoneyField(
                  label: l10n.estimatedValueLabel,
                  value: _value,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  onChanged: (amount) => setState(() => _value = amount),
                ),
                MmDateField(
                  label: l10n.valueEstimatedOnLabel,
                  value: _valuedOn,
                  optional: true,
                  firstDate: firstDay,
                  lastDate: today,
                  onChanged: (date) => setState(() => _valuedOn = date),
                ),
                MmTextField(
                  label: l10n.propertyTaxRefLabel,
                  controller: _taxRef,
                  optional: true,
                  maxLength: Property.maxTaxRefLength,
                  inputFormatters: codePointLimit(Property.maxTaxRefLength),
                  validator: (value) => Validators.name(
                    l10n,
                    value,
                    maxLength: Property.maxTaxRefLength,
                    required: false,
                  ),
                  onChanged: _changed,
                ),
                MmTextField(
                  label: l10n.notesLabel,
                  controller: _notes,
                  optional: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: Property.maxNotesLength,
                  inputFormatters: codePointLimit(Property.maxNotesLength),
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
                  _old == null ? Routes.properties : Routes.property(_old.id),
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
