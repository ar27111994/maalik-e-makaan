import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_ui/src/components/inputs/mm_field_frame.dart';
import 'package:mm_ui/src/foundation/mm_clean_text_formatter.dart';
import 'package:mm_ui/src/foundation/mm_field_error.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// How a value field sets its one line in a field of a given width: the
/// text style and text scale of the value, the currency marker beside it
/// and the edge the value sits against (see `MmValueField`).
///
/// Internal to the inputs family.
@immutable
class MmValueLine {
  /// Describes the line.
  const new({
    required this.style,
    required this.textScaler,
    required this.textAlign,
    this.prefixIcon,
    this.suffixIcon,
  });

  /// The style of the value, without its colour (the field sets the colour
  /// for its state).
  final TextStyle style;

  /// The text scale of the value and of [prefixIcon] and [suffixIcon]: the
  /// reader's, or less when the value would not fit at it.
  final TextScaler textScaler;

  /// Where the value sits on its line.
  final TextAlign textAlign;

  /// Shown at the start inside the field, sized by its own content.
  final Widget? prefixIcon;

  /// Shown at the end inside the field, sized by its own content.
  final Widget? suffixIcon;
}

/// Lays out the line of a value field [width] wide that holds [text].
typedef MmValueLayout = MmValueLine Function(
  BuildContext context,
  double width,
  String text,
);

/// The one text field the inputs family is built on: a [TextFormField] (so
/// `Form` validation, saving and resetting work) inside [MmFieldFrame],
/// always cleaning out the characters the database rejects
/// ([MmCleanTextFormatter]).
///
/// The typed text is set in the body style through `context.mm.styleFor`,
/// so Latin text typed in the Urdu UI (a name in English) is set in
/// Atkinson while Urdu stays in Nastaliq; the field rebuilds only when the
/// text changes script.
///
/// A value field passes [valueLine] instead: the field then lays its one
/// line out for its width and its current text (rebuilding as the text
/// changes), while the label, helper and error keep the reader's text size.
///
/// Internal to the inputs family: the public fields build it.
class MmTextInput extends StatefulWidget {
  /// Creates the field. [controller] and [initialValue] are exclusive.
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
    this.suffixIcon,
    this.required = false,
    this.optional = false,
    this.inputFormatters,
    this.obscureText = false,
    this.leftToRight = false,
    this.valueLine,
    this.emptyHint,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Pass either a controller or an initial value, not both.',
       );

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// Controls the text; when null the field keeps its own.
  final TextEditingController? controller;

  /// The text the field starts with when it has no [controller].
  final String? initialValue;

  /// Shown inside the field while it is empty.
  final String? hint;

  /// Shown below the field in muted ink.
  final String? helper;

  /// An error from outside the field (a server check); it wins over
  /// [validator] while set.
  final String? errorText;

  /// Validates the text when the enclosing `Form` validates.
  final FormFieldValidator<String>? validator;

  /// When the field validates itself.
  final AutovalidateMode? autovalidateMode;

  /// Called with the text after every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard to show.
  final TextInputType? keyboardType;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  /// What the platform may autofill.
  final Iterable<String>? autofillHints;

  /// How the keyboard capitalises.
  final TextCapitalization textCapitalization;

  /// The most user-perceived characters (grapheme clusters) allowed; shows
  /// a counter.
  final int? maxLength;

  /// The fewest lines the field is tall.
  final int minLines;

  /// The most lines the field grows to.
  final int maxLines;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// Shown at the start inside the field, always.
  final Widget? prefixIcon;

  /// Shown before the text while the field is focused or filled.
  final String? prefixText;

  /// Shown at the end inside the field, always (an action button).
  final Widget? suffixIcon;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Formatters applied after [MmCleanTextFormatter].
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the text is hidden (a password).
  final bool obscureText;

  /// Whether the text itself reads left to right in both languages
  /// (numbers, passwords: exactly as typed), while sitting at the start edge
  /// of the field like the rest of the form (the right edge in Urdu).
  final bool leftToRight;

  /// Lays out the line of a value (an amount, a CNIC): its style, scale,
  /// alignment and currency marker, for the field's width and text. Its
  /// affixes replace [prefixIcon] and [suffixIcon].
  final MmValueLayout? valueLine;

  /// Said after the field's name while the field is empty: the unit its
  /// value is in ("rupees").
  final String? emptyHint;

  @override
  State<MmTextInput> createState() => _MmTextInputState();
}

class _MmTextInputState extends State<MmTextInput> {
  /// The latest text, and whether it has Urdu letters.
  late String _text;
  late bool _arabic;

  @override
  void initState() {
    super.initState();
    _text = widget.controller?.text ?? widget.initialValue ?? '';
    _arabic = MmSemantics.hasArabicScript(_text);
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(MmTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      // build() follows, so no setState.
      _text = widget.controller?.text ?? _text;
      _arabic = MmSemantics.hasArabicScript(_text);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() => _track(widget.controller!.text);

  void _handleChanged(String text) {
    _track(text);
    widget.onChanged?.call(text);
  }

  /// Remembers [text]. A value field lays its line out for its text, so it
  /// rebuilds on every change of the text; any other field rebuilds only
  /// when the text changes script, the only change `styleFor` reacts to.
  void _track(String text) {
    if (text == _text) return;
    final arabic = MmSemantics.hasArabicScript(text);
    final rebuild =
        widget.valueLine != null ||
        widget.emptyHint != null ||
        arabic != _arabic;
    _text = text;
    _arabic = arabic;
    if (rebuild) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final ink = widget.enabled ? mm.colors.ink : mm.colors.inkMuted;
    final valueLine = widget.valueLine;
    final Widget field;
    if (valueLine == null) {
      field = _field(
        context,
        style: mm.styleFor(
          _text,
          Theme.of(context).textTheme.bodyLarge!.copyWith(color: ink),
        ),
        textAlign: _startAlign(context),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
      );
    } else {
      final media = MediaQuery.of(context);
      field = LayoutBuilder(
        builder: (context, constraints) {
          final line = valueLine(context, constraints.maxWidth, _text);
          return MediaQuery(
            data: media.copyWith(textScaler: line.textScaler),
            child: _field(
              context,
              style: line.style.copyWith(color: ink),
              textAlign: line.textAlign,
              prefixIcon: line.prefixIcon,
              suffixIcon: line.suffixIcon,
              // The affixes of a value are words, not buttons: they take
              // only their own size.
              affixConstraints: const BoxConstraints(),
              // The helper and the error are not on the value's line: they
              // keep the reader's text size.
              subtextScaler: media.textScaler,
            ),
          );
        },
      );
    }
    return MmFieldFrame(
      label: widget.label,
      required: widget.required,
      optional: widget.optional,
      enabled: widget.enabled,
      hint: _text.isEmpty ? widget.emptyHint : null,
      child: field,
    );
  }

  /// Where the text sits when nothing else says: at the start edge, also
  /// when it reads left to right in the Urdu UI.
  TextAlign _startAlign(BuildContext context) {
    if (!widget.leftToRight) return TextAlign.start;
    return Directionality.of(context) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
  }

  Widget _field(
    BuildContext context, {
    required TextStyle style,
    required TextAlign textAlign,
    Widget? prefixIcon,
    Widget? suffixIcon,
    BoxConstraints? affixConstraints,
    TextScaler? subtextScaler,
  }) => TextFormField(
    controller: widget.controller,
    initialValue: widget.initialValue,
    forceErrorText: widget.errorText,
    validator: widget.validator,
    autovalidateMode: widget.autovalidateMode,
    errorBuilder: (context, message) =>
        MmFieldFrame.atScale(subtextScaler, MmFieldError(message)),
    decoration: MmFieldFrame.decoration(
      context,
      hint: widget.hint,
      helper: widget.helper,
      prefixIcon: prefixIcon,
      prefixText: widget.prefixText,
      suffixIcon: suffixIcon,
      affixConstraints: affixConstraints,
      subtextScaler: subtextScaler,
    ),
    onChanged: _handleChanged,
    onFieldSubmitted: widget.onSubmitted,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    textCapitalization: widget.textCapitalization,
    maxLength: widget.maxLength,
    minLines: widget.minLines,
    maxLines: widget.maxLines,
    enabled: widget.enabled,
    readOnly: widget.readOnly,
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    obscureText: widget.obscureText,
    autocorrect: !widget.obscureText,
    enableSuggestions: !widget.obscureText,
    style: style,
    textDirection: widget.leftToRight ? TextDirection.ltr : null,
    textAlign: textAlign,
    inputFormatters: [const MmCleanTextFormatter(), ...?widget.inputFormatters],
  );
}
