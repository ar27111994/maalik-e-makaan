import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// [phone] as the profile form shows it: digits only, `03001234567` in
/// Pakistan and `00` with the country code abroad.
String phoneText(PhoneNumber? phone) => switch (phone) {
  null => '',
  PhoneNumber(isPakistani: true) => '0${phone.e164.substring(3)}',
  _ => '00${phone.digits}',
};

/// Saves the name and phone; throws `AppFailure`.
typedef SaveDetails = Future<void> Function({
  required String fullName,
  required PhoneNumber? phone,
});

/// The user's name and phone, as teammates see them, with a button that
/// saves both. Until the user edits a field, a fresher copy of [profile]
/// replaces what the fields show.
class ProfileForm extends StatefulWidget {
  const new({required this.profile, required this.onSave, super.key});

  final Profile profile;
  final SaveDetails onSave;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> with CommandState {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(
    text: phoneText(widget.profile.phone),
  );
  var _edited = false;
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_edited && widget.profile != oldWidget.profile) {
      _name.text = widget.profile.fullName;
      _phone.text = phoneText(widget.profile.phone);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _changed(String _) {
    setState(() {
      _edited = true;
      failure = null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final phone = _phone.text.trim();
    final saved = await runCommand(
      () => widget.onSave(
        fullName: _name.text,
        phone: phone.isEmpty ? null : PhoneNumber.tryParse(phone),
      ),
    );
    if (!saved || !mounted) return;
    setState(() => _edited = false);
    await showMmSnackbar(
      context,
      message: l10n.detailsSaved,
      tone: MmBannerTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Form(
      key: _form,
      autovalidateMode: _validation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmFormSection(
            title: l10n.profileSection,
            description: l10n.profileSectionHelp,
            children: [
              if (failure != null) FailureBanner(failure: failure),
              MmTextField(
                label: l10n.fullNameLabel,
                controller: _name,
                required: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => Validators.name(
                  l10n,
                  value,
                  maxLength: Profile.maxNameLength,
                ),
                onChanged: _changed,
              ),
              // A plain field rather than MmPhoneField, whose validator
              // cannot tell an empty field from a number that is not one:
              // here the phone is optional, so a typo must not save as "no
              // phone". Digits only (no spaces, "00" for abroad): one run of
              // digits reads left to right even in the Urdu field, where
              // "0300 1234567" would show as "1234567 0300".
              MmTextField(
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9+۰-۹٠-٩]')),
                ],
                label: l10n.phoneLabel,
                controller: _phone,
                optional: true,
                helper: l10n.phoneHelper,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  return PhoneNumber.tryParse(text) == null
                      ? l10n.validationPhone
                      : null;
                },
                onChanged: _changed,
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
          const SizedBox(height: MmSpace.s4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MmButton(
              label: l10n.saveDetailsAction,
              variant: MmButtonVariant.secondary,
              busy: busy,
              onPressed: _edited ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}
