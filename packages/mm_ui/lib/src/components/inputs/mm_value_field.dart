import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_ui/src/components/inputs/mm_text_input.dart';

/// A field that edits a value rather than free text (an amount, a CNIC, a
/// phone number): [formatter] lays the text out as the user types, [parse]
/// turns it into the value (null while it is incomplete or invalid) and
/// [display] writes a value back as text.
///
/// [onChanged] is called whenever the parsed value changes, including to
/// null, while the text keeps exactly what was typed. When [value] changes
/// from outside to something other than what the text already says, the
/// text is replaced; when [layout] changes (another digit grouping), a
/// valid value is written again in the new layout.
///
/// The text is announced through [describe] (the plain number and the
/// currency for an amount) or digit by digit when [spellOut] is set.
///
/// Internal to the inputs family: the public value fields build it.
class MmValueField<T extends Object> extends StatefulWidget {
  /// Creates the field.
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.parse,
    required this.display,
    required this.formatter,
    required this.keyboardType,
    this.layout,
    this.describe,
    this.spellOut = false,
    this.style,
    this.autofillHints,
    this.prefixIcon,
    this.suffixIcon,
    this.affixConstraints,
    this.helper,
    this.errorText,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    super.key,
  });

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// The current value; null for none.
  final T? value;

  /// Called with the parsed value whenever it changes.
  final ValueChanged<T?> onChanged;

  /// The value the text stands for, or null when it is incomplete or
  /// invalid.
  final T? Function(String text) parse;

  /// The text for a value.
  final String Function(T value) display;

  /// Lays the text out as it is typed.
  final TextInputFormatter formatter;

  /// The keyboard to show.
  final TextInputType keyboardType;

  /// What the text is laid out in (a digit grouping); when it changes, the
  /// current value is written again.
  final Object? layout;

  /// What a screen reader says for the text, or null to read it as shown.
  final String? Function(BuildContext context, String text)? describe;

  /// Whether a screen reader spells the text out, digit by digit.
  final bool spellOut;

  /// A fixed style for the text; null uses the body style in Latin.
  final TextStyle? style;

  /// What the platform may autofill.
  final Iterable<String>? autofillHints;

  /// Shown at the start inside the field.
  final Widget? prefixIcon;

  /// Shown at the end inside the field.
  final Widget? suffixIcon;

  /// Size limits of [prefixIcon] and [suffixIcon]; null keeps the 48 dp
  /// touch target as their least size.
  final BoxConstraints? affixConstraints;

  /// Shown below the field in muted ink.
  final String? helper;

  /// Shown below the field with the error icon while set.
  final String? errorText;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Whether the field accepts input.
  final bool enabled;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  @override
  State<MmValueField<T>> createState() => _MmValueFieldState<T>();
}

class _MmValueFieldState<T extends Object> extends State<MmValueField<T>> {
  late final MmFieldController _controller;

  /// The value the text stands for, as last reported.
  late T? _current;

  String _textOf(T? value) => value == null ? '' : widget.display(value);

  @override
  void initState() {
    super.initState();
    _current = widget.value;
    _controller = MmFieldController(
      text: _textOf(widget.value),
      describe: widget.describe,
      spellOut: widget.spellOut,
    );
  }

  @override
  void didUpdateWidget(MmValueField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller
      ..describe = widget.describe
      ..spellOut = widget.spellOut;
    if (widget.value != oldWidget.value && widget.value != _current) {
      _current = widget.value;
      _show(_textOf(widget.value));
    } else if (widget.layout != oldWidget.layout && _current != null) {
      _show(widget.display(_current!));
    }
  }

  void _show(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String text) {
    final next = widget.parse(text);
    if (next == _current) return;
    _current = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return MmTextInput(
      label: widget.label,
      controller: _controller,
      helper: widget.helper,
      errorText: widget.errorText,
      onChanged: _handleChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      affixConstraints: widget.affixConstraints,
      required: widget.required,
      optional: widget.optional,
      inputFormatters: [widget.formatter],
      style: widget.style,
      leftToRight: true,
    );
  }
}

/// A [TextEditingController] whose text a screen reader hears as
/// [describe] says (the plain number and the currency for an amount), or
/// spelled out digit by digit when [spellOut] is set.
///
/// While the platform's input method composes text, the text is read as
/// shown, so the composing underline still appears.
class MmFieldController extends TextEditingController {
  /// Creates a controller for [text].
  new({super.text, this.describe, this.spellOut = false});

  /// What a screen reader says for the text, or null to read it as shown.
  String? Function(BuildContext context, String text)? describe;

  /// Whether a screen reader spells the text out.
  bool spellOut;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      text: text,
      style: style,
      semanticsLabel: describe?.call(context, text),
      spellOut: spellOut ? true : null,
    );
  }
}
