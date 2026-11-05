import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/inputs/mm_text_input.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';

/// A labelled password field: the text is hidden, and a button at the end
/// shows or hides it ("Show password" / "Hide password", which is also the
/// button's accessible label).
///
/// It has the same anatomy as `MmTextField` (label above, "Required" or
/// "Optional" in words, helper or error below) and offers the password
/// manager the saved password, or with [newPassword] a new one to store.
/// Suggestions and autocorrect are off, and the password reads left to
/// right exactly as typed in both languages.
///
/// Use it only for secrets the user types. To keep a tenant's CNIC off a
/// shared screen, show it with `MmCnicText`, which masks it.
///
/// ```dart
/// MmPasswordField(
///   label: l10n.password,
///   required: true,
///   textInputAction: TextInputAction.done,
///   onSubmitted: (_) => signIn(),
///   onChanged: (password) => this.password = password,
/// )
/// ```
class MmPasswordField extends StatefulWidget {
  /// Creates a password field labelled [label]. [controller] and
  /// [initialValue] are exclusive; a field is not both [required] and
  /// [optional].
  const new({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.newPassword = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.required = false,
    this.optional = false,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Pass either a controller or an initial value, not both.',
       ),
       assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// Controls the text; when null the field keeps its own, starting with
  /// [initialValue].
  final TextEditingController? controller;

  /// The text the field starts with when it has no [controller].
  final String? initialValue;

  /// Shown inside the field while it is empty.
  final String? hint;

  /// Guidance shown below the field in muted ink ("At least 8 characters").
  final String? helper;

  /// An error from outside the field ("Wrong password"); it is shown
  /// instead of [validator]'s while set.
  final String? errorText;

  /// Checks the password when the enclosing `Form` validates and returns
  /// the error to show, or null.
  final FormFieldValidator<String>? validator;

  /// When the field validates itself; by default only when the `Form`
  /// asks.
  final AutovalidateMode? autovalidateMode;

  /// Called with the password after every change.
  final ValueChanged<String>? onChanged;

  /// Called with the password when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard's action button (next, done).
  final TextInputAction? textInputAction;

  /// Whether this is a new password (sign-up, change of password): the
  /// password manager then offers to generate and store one instead of
  /// filling a saved one.
  final bool newPassword;

  /// Whether the field accepts input.
  final bool enabled;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  @override
  State<MmPasswordField> createState() => _MmPasswordFieldState();
}

class _MmPasswordFieldState extends State<MmPasswordField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final strings = MmLocalizations.of(context);
    return MmTextInput(
      label: widget.label,
      controller: widget.controller,
      initialValue: widget.initialValue,
      hint: widget.hint,
      helper: widget.helper,
      errorText: widget.errorText,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: [
        if (widget.newPassword)
          AutofillHints.newPassword
        else
          AutofillHints.password,
      ],
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      required: widget.required,
      optional: widget.optional,
      obscureText: !_revealed,
      leftToRight: true,
      suffixIcon: IconButton(
        onPressed: widget.enabled
            ? () => setState(() => _revealed = !_revealed)
            : null,
        tooltip: _revealed ? strings.hidePassword : strings.showPassword,
        icon: Icon(_revealed ? MmIcons.hide : MmIcons.show),
      ),
    );
  }
}
