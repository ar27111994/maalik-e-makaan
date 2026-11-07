import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_ui/src/components/inputs/mm_text_input.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

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
/// The value is one unbroken line, in the Latin face in both languages,
/// on the line height of the body text of the ambient script, so a value
/// field is as tall as a text field beside it. The [marker] sits on the
/// value's line and grows with the text only up to 150%, like an icon
/// beside words. A value is never cut short: when it would not fit the
/// field at the reader's text size (the largest amounts at 200% on a
/// 320 dp phone), it is set only as much smaller as it needs, down to the
/// caption size at most, while the label, helper and error keep the
/// reader's size.
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
    this.marker,
    this.markerLeading = true,
    this.unit,
    this.autofillHints,
    this.helper,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.onSubmitted,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
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

  /// The style of the value, in the Latin face (its line height is set to
  /// the field's); the Latin body style by default.
  final TextStyle? style;

  /// Words shown beside the value and hidden from assistive technology
  /// ("Rs", "روپے"); [describe] says them with the value.
  final String? marker;

  /// Whether [marker] comes before the value (at the start edge) or after
  /// it (at the end edge). The value sits against the marker.
  final bool markerLeading;

  /// The unit the value is in ("rupees"), said by assistive technology
  /// while the field is empty.
  final String? unit;

  /// What the platform may autofill.
  final Iterable<String>? autofillHints;

  /// Shown below the field in muted ink.
  final String? helper;

  /// Shown below the field with the error icon while set.
  final String? errorText;

  /// Checks the value (null while the text is not one) when the enclosing
  /// `Form` validates, and returns the error to show, or null.
  final FormFieldValidator<T>? validator;

  /// When the field validates itself.
  final AutovalidateMode? autovalidateMode;

  /// Called with the value (null when the text is not one) when the user
  /// submits from the keyboard.
  final ValueChanged<T?>? onSubmitted;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Whether the field accepts input.
  final bool enabled;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  @override
  State<MmValueField<T>> createState() => _MmValueFieldState<T>();
}

class _MmValueFieldState<T extends Object> extends State<MmValueField<T>> {
  /// The Latin body style, the default style of a value.
  static final TextStyle _latinBody = MmSemantics.withUrduFallback(
    MmTypeScale.latinBody,
  );

  /// The room Material 3 leaves between an affix and the text.
  static const double _affixGap = 4;

  /// The room the cursor takes after the text: its width (2 dp) and the
  /// gap before it (1 dp). A text field scrolls a text that leaves less.
  static const double _caretRoom = 3;

  /// How close the scale of a value that does not fit at the reader's
  /// size comes to the largest scale at which it fits.
  static const double _scalePrecision = 0.005;

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

  /// Lays the value's line out in a field [width] wide holding [text]: at
  /// the reader's text size when the text and the marker fit, otherwise
  /// at the largest smaller size at which they do (never below the caption
  /// size), always on the line height of the script's body text at the
  /// reader's size.
  MmValueLine _line(BuildContext context, double width, String text) {
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final reader = MediaQuery.textScalerOf(context);
    final base = widget.style ?? _latinBody;
    final size = base.fontSize!;
    final body = theme.textTheme.bodyLarge!;
    final line = reader.scale(body.fontSize!) * body.height!;
    TextStyle valueAt(double scale) =>
        base.copyWith(height: line / (size * scale));
    final markerStyle = base.copyWith(
      fontWeight: body.fontWeight,
      color: context.mm.colors.inkMuted,
    );
    // The marker grows with the text only as far as an icon beside words
    // does: the figures need the room more.
    double markerScale(double scale) =>
        math.min(scale, MmIconLabel.maxIconScale);

    final marker = widget.marker;
    final leading = widget.markerLeading;
    final padding = theme.inputDecorationTheme.contentPadding!.resolve(
      direction,
    );
    final ltr = direction == TextDirection.ltr;
    final start = ltr ? padding.left : padding.right;
    final end = ltr ? padding.right : padding.left;
    // What does not grow with the text: the field's padding (around the
    // marker too), the marker's gap to the value, and the cursor's room.
    final fixed =
        start +
        end +
        _caretRoom +
        (marker == null ? 0 : _Marker.inner + _affixGap);
    double room(double scale) =>
        width -
        fixed -
        (marker == null
            ? 0
            : _widthOf(marker, markerStyle, markerScale(scale)));
    bool fits(double scale) =>
        _widthOf(text, valueAt(scale), scale) <= room(scale);

    final most = reader.scale(size) / size;
    final least = math.min(most, MmTypeScale.latinCaption.fontSize! / size);
    var scale = most;
    if (!fits(most)) {
      // The largest scale that fits, by halving the range it lies in; the
      // least scale is kept even when nothing fits (a field narrower than
      // any phone's), and the field then scrolls its text.
      var low = least;
      var high = most;
      while (high - low > _scalePrecision) {
        final middle = (low + high) / 2;
        if (fits(middle)) {
          low = middle;
        } else {
          high = middle;
        }
      }
      scale = low;
    }

    final shown = marker == null
        ? null
        : _Marker(
            marker,
            leading: leading,
            outer: leading ? start : end,
            style: markerStyle,
            textScaler: TextScaler.linear(markerScale(scale)),
            // The value's line, at the marker's scale: the same line box and
            // baseline as the value's.
            line: StrutStyle.fromTextStyle(
              valueAt(scale)
                  .copyWith(fontSize: size * scale / markerScale(scale)),
              forceStrutHeight: true,
            ),
          );
    // The value sits against its marker, or at the start edge without one.
    final towardStart = marker == null || leading;
    return MmValueLine(
      style: valueAt(scale),
      textScaler: TextScaler.linear(scale),
      textAlign: towardStart == ltr ? TextAlign.left : TextAlign.right,
      prefixIcon: leading ? shown : null,
      suffixIcon: leading ? null : shown,
    );
  }

  /// The width of [text] on one line in [style] at [scale].
  static double _widthOf(String text, TextStyle style, double scale) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(scale),
      maxLines: 1,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final validator = widget.validator;
    final onSubmitted = widget.onSubmitted;
    return MmTextInput(
      label: widget.label,
      controller: _controller,
      helper: widget.helper,
      errorText: widget.errorText,
      validator: validator == null
          ? null
          : (text) => validator(widget.parse(text ?? '')),
      autovalidateMode: widget.autovalidateMode,
      onChanged: _handleChanged,
      onSubmitted: onSubmitted == null
          ? null
          : (text) => onSubmitted(widget.parse(text)),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      required: widget.required,
      optional: widget.optional,
      inputFormatters: [widget.formatter],
      leftToRight: true,
      valueLine: _line,
      emptyHint: widget.unit,
    );
  }
}

/// The words beside a value inside its field ("Rs", "روپے"), always
/// visible and hidden from assistive technology, which hears them with the
/// value. They sit on the value's line: the same line box and baseline.
class _Marker extends StatelessWidget {
  const new(
    this.marker, {
    required this.leading,
    required this.outer,
    required this.style,
    required this.textScaler,
    required this.line,
  });

  /// The room between the marker and the value, besides Material's own gap
  /// between an affix and the text.
  static const double inner = MmSpace.s1;

  final String marker;

  /// Whether the marker comes before the value (start) or after it (end).
  final bool leading;

  /// The room between the marker and the field's edge: the field's padding.
  final double outer;

  /// The marker's style.
  final TextStyle style;

  /// The marker's text scale.
  final TextScaler textScaler;

  /// The line the marker sits on: the value's.
  final StrutStyle line;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: EdgeInsetsDirectional.only(
        start: leading ? outer : inner,
        end: leading ? inner : outer,
      ),
      child: Text(
        marker,
        style: style,
        textScaler: textScaler,
        strutStyle: line,
      ),
    ),
  );
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
