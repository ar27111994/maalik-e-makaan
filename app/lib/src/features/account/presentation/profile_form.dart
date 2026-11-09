import 'package:flutter/material.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/validation.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

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
  late PhoneNumber? _phone = widget.profile.phone;
  var _edited = false;
  AutovalidateMode _validation = AutovalidateMode.disabled;

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_edited && widget.profile != oldWidget.profile) {
      _name.text = widget.profile.fullName;
      _phone = widget.profile.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed([Object? _]) {
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
    final saved = await runCommand(
      () => widget.onSave(fullName: _name.text, phone: _phone),
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
              // Optional, so a typo must not save as "no phone": the field
              // reports it with invalidText and the form does not save.
              MmPhoneField(
                label: l10n.phoneLabel,
                value: _phone,
                optional: true,
                helper: l10n.phoneHelper,
                invalidText: l10n.validationPhone,
                textInputAction: TextInputAction.done,
                onChanged: (phone) {
                  _phone = phone;
                  _changed();
                },
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
