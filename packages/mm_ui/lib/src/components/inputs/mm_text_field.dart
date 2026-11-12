import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_ui/src/components/inputs/mm_text_input.dart';
import 'package:mm_ui/src/foundation/mm_clean_text_formatter.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A labelled text field for anything a landlord types in words: a
/// tenant's name, an address, a note.
///
/// The label sits above the field (never floating) and is its accessible
/// name; [required] or [optional] add that word after it. [helper] sits
/// below in muted ink; an error ([errorText], or [validator] when the
/// enclosing `Form` validates) replaces it in the overdue colour with the
/// error icon and is announced. Characters the database rejects are
/// removed as they are typed or pasted ([MmCleanTextFormatter]), and Latin
/// text typed in the Urdu UI is set in Atkinson rather than the Urdu face.
///
/// Use `MmPasswordField` for passwords and the money, CNIC and phone
/// fields for those values: they format and parse them as they are typed.
///
/// Material fades the outline and the helper or error line in and out
/// over 167 ms (the error also slides a quarter of its height into place)
/// whatever the platform's reduced-motion setting: Flutter's
/// `InputDecorator` fixes those durations, so no field can turn them off.
///
/// ```dart
/// MmTextField(
///   label: l10n.tenantName,
///   required: true,
///   autofillHints: const [AutofillHints.name],
///   textCapitalization: TextCapitalization.words,
///   validator: (name) => name!.trim().isEmpty ? l10n.enterName : null,
///   onChanged: (name) => draft.name = name,
/// )
/// ```
class MmTextField extends StatelessWidget {
  /// Creates a text field labelled [label]. [controller] and
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
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.required = false,
    this.optional = false,
    this.inputFormatters,
    this.leftToRight = false,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Pass either a controller or an initial value, not both.',
       ),
       assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       ),
       assert(maxLength == null || maxLength > 0, 'maxLength must be > 0.'),
       assert(minLines > 0, 'minLines must be > 0.'),
       assert(maxLines >= minLines, 'maxLines must be >= minLines.');

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// Controls the text; when null the field keeps its own, starting with
  /// [initialValue].
  final TextEditingController? controller;

  /// The text the field starts with when it has no [controller].
  final String? initialValue;

  /// An example shown inside the field while it is empty ("Ali Raza").
  final String? hint;

  /// Guidance shown below the field in muted ink.
  final String? helper;

  /// An error from outside the field, such as a server check ("This name is
  /// already taken"), shown below the field with the error icon at once, in
  /// place of [helper], and announced.
  ///
  /// While it is set it wins: [validator] is not called, and the field
  /// counts as invalid, so the enclosing `Form`'s `validate()` returns false.
  /// Typing does not clear it: set it back to null once the user changes
  /// what it is about (in [onChanged], say). The field then shows
  /// [validator]'s error again only when it next validates.
  final String? errorText;

  /// Checks the text when the enclosing `Form` validates (or as
  /// [autovalidateMode] says) and returns the error to show, or null.
  final FormFieldValidator<String>? validator;

  /// When the field validates itself; by default only when the `Form`
  /// asks.
  final AutovalidateMode? autovalidateMode;

  /// Called with the text after every change.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard to show; text, or multiline when [maxLines] is above 1.
  final TextInputType? keyboardType;

  /// The keyboard's action button (next, done).
  final TextInputAction? textInputAction;

  /// What the platform may autofill ([AutofillHints.name]).
  final Iterable<String>? autofillHints;

  /// How the keyboard capitalises (words, for names).
  final TextCapitalization textCapitalization;

  /// The most characters the field takes, counted as a reader perceives
  /// them (an Urdu letter with its marks or an emoji counts once); shows a
  /// counter below the field.
  final int? maxLength;

  /// The fewest lines the field is tall.
  final int minLines;

  /// The most lines the field grows to before it scrolls.
  final int maxLines;

  /// Whether the field accepts input. A disabled field and its label are
  /// muted.
  final bool enabled;

  /// Whether the text can be selected and copied but not changed.
  final bool readOnly;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// An icon at the start inside the field. It grows with the text size,
  /// up to one and a half times.
  final IconData? prefixIcon;

  /// Text before the input while the field is focused or filled.
  final String? prefixText;

  /// A widget at the end inside the field, such as an action button. Icons
  /// in it that set no size of their own grow with the text, up to one and
  /// a half times; an `IconButton` takes its size from its `iconSize`.
  final Widget? suffix;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// More formatters, applied after [MmCleanTextFormatter].
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the text reads left to right in both languages, exactly as
  /// typed: an email address, a web address, an account or meter number.
  /// It still sits at the start edge of the field like the rest of the form
  /// (the right edge in Urdu). Words a person writes (a name, an address, a
  /// note) keep the default, which follows the text's own script.
  final bool leftToRight;

  @override
  Widget build(BuildContext context) {
    return MmTextInput(
      label: label,
      controller: controller,
      initialValue: initialValue,
      hint: hint,
      helper: helper,
      errorText: errorText,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      autofocus: autofocus,
      // The icon grows with the text, as icons beside words do, up to
      // one and a half times.
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              size: MmIconLabel.scaledSize(context, MmSize.iconLg),
            ),
      prefixText: prefixText,
      // An icon in the suffix grows with the text too, unless it sets its
      // own size.
      suffixIcon: suffix == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(
                size: MmIconLabel.scaledSize(context, MmSize.iconLg),
              ),
              child: suffix!,
            ),
      required: required,
      optional: optional,
      inputFormatters: inputFormatters,
      leftToRight: leftToRight,
    );
  }
}
