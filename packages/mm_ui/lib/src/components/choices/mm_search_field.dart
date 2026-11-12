import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_clean_text_formatter.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A search box: an inset well at the top of a list of tenants, properties
/// or payments, or of a long `MmSelectField` sheet.
///
/// It is a sunken well with the focus ring while it has focus, a search
/// icon at the start, and a clear button once there is text. In light mode
/// the well has no outline at rest; in dark and high-contrast modes, where
/// its tone is all but the page's, it is framed in the field outline. Its
/// accessible name is [hint] ("Search" unless given). Control and spoofing
/// characters (bidirectional overrides, zero-width spaces) are removed as
/// they are typed or pasted, as in every text field.
///
/// Filter as the landlord types with [onChanged]; search on submit with
/// [onSubmitted]. Clearing calls [onChanged] with the empty text and keeps
/// focus in the field. For a value that is saved with a form, use a text
/// field instead.
///
/// ```dart
/// MmSearchField(
///   hint: l10n.searchTenants,
///   onChanged: (query) => setState(() => this.query = query),
/// )
/// ```
class MmSearchField extends StatefulWidget {
  /// Creates a search field.
  const new({
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// Controls the text; when null the field keeps its own.
  final TextEditingController? controller;

  /// Shown in the empty field and announced as its name ("Search tenants");
  /// defaults to `MmLocalizations.search`.
  final String? hint;

  /// Called with the text after every change, and with the empty text when
  /// the clear button empties the field.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the landlord submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// The field's focus node; when null the field keeps its own.
  final FocusNode? focusNode;

  @override
  State<MmSearchField> createState() => _MmSearchFieldState();
}

class _MmSearchFieldState extends State<MmSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  /// Whether the field is empty, and whether its text has Urdu letters:
  /// the only things the field's look depends on.
  late bool _empty;
  late bool _arabic;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'MmSearchField'));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _read();
  }

  @override
  void didUpdateWidget(MmSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(
        _handleTextChanged,
      );
      _controller.addListener(_handleTextChanged);
      // build() follows, so no setState.
      _read();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _read() {
    final text = _controller.text;
    _empty = text.isEmpty;
    _arabic = MmSemantics.hasArabicScript(text);
  }

  void _handleTextChanged() {
    final text = _controller.text;
    final empty = text.isEmpty;
    final arabic = MmSemantics.hasArabicScript(text);
    if (empty != _empty || arabic != _arabic) setState(_read);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    // The clear button goes away with the text; keep focus in the field.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final strings = MmLocalizations.of(context);
    final hint = widget.hint ?? strings.search;
    final body = Theme.of(context).textTheme.bodyLarge!;
    // Latin text typed in the Urdu UI (a name in English) is set in
    // Atkinson; Urdu stays in the Urdu face.
    final style = mm.styleFor(_controller.text, body);
    const radius = BorderRadius.all(Radius.circular(MmRadius.sm));
    // The well's tone is within 1.1:1 of the page in dark and high-contrast
    // modes, so there the outline marks where it is.
    final framed =
        Theme.of(context).brightness == Brightness.dark || mm.highContrast;
    final atRest = OutlineInputBorder(
      borderRadius: radius,
      borderSide: framed ? BorderSide(color: colors.outline) : BorderSide.none,
    );
    return Semantics(
      label: hint,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        inputFormatters: const [MmCleanTextFormatter()],
        style: style,
        decoration: InputDecoration(
          // The hint is the field's name, given once above; shown here,
          // it may wrap rather than be cut short at large text sizes.
          hint: ExcludeSemantics(
            child: Text(
              hint,
              style: Theme.of(context).inputDecorationTheme.hintStyle,
            ),
          ),
          filled: true,
          fillColor: colors.surfaceSunken,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: MmSpace.s4,
            vertical: MmSpace.s3,
          ),
          border: atRest,
          enabledBorder: atRest,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: colors.focus,
              width: MmSize.focusRing,
            ),
          ),
          prefixIcon: Icon(
            MmIcons.search,
            size: MmIconLabel.scaledSize(context, MmSize.iconLg),
            color: colors.inkMuted,
          ),
          suffixIcon: _empty
              ? null
              : IconButton(
                  tooltip: strings.clearText,
                  iconSize: MmIconLabel.scaledSize(context, MmSize.iconLg),
                  onPressed: _clear,
                  icon: const Icon(MmIcons.close),
                ),
        ),
      ),
    );
  }
}
