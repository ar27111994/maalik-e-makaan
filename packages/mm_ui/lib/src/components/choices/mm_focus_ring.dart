import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Tells a [State] whether keyboard focus should be drawn: only while the
/// user drives the app from a keyboard (Flutter's traditional focus
/// highlight mode), as Material does for its own focus highlights, so a
/// tap never leaves a ring behind on a phone.
///
/// Internal to the choices family.
mixin MmFocusHighlight<T extends StatefulWidget> on State<T> {
  late bool _keyboard;

  /// Whether focus is currently drawn: the last input came from a keyboard.
  bool get showsFocusHighlights => _keyboard;

  @override
  void initState() {
    super.initState();
    _keyboard = _isKeyboard(FocusManager.instance.highlightMode);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    final keyboard = _isKeyboard(mode);
    if (keyboard != _keyboard) setState(() => _keyboard = keyboard);
  }

  static bool _isKeyboard(FocusHighlightMode mode) =>
      mode == FocusHighlightMode.traditional;
}

/// Draws the 2 dp focus ring of the design system around [child] while any
/// control inside it has keyboard focus.
///
/// Material tiles only tint themselves when focused; the ring makes the
/// focused row as plain as a focused button. It adds no focus stop and no
/// semantics of its own. [child] is set on a transparent [Material] of its
/// own, so a tile's hover, focus and splash ink show on whatever surface
/// the row sits on (a card, a coloured page).
///
/// Internal to the choices family.
class MmFocusRing extends StatefulWidget {
  /// Rings [child] with corners of [radius].
  const new({required this.child, this.radius = MmRadius.sm, super.key});

  /// The control (a tile) to ring.
  final Widget child;

  /// The corner radius of the ring.
  final double radius;

  @override
  State<MmFocusRing> createState() => _MmFocusRingState();
}

class _MmFocusRingState extends State<MmFocusRing>
    with MmFocusHighlight<MmFocusRing> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final ring = _focused && showsFocusHighlights;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _handleFocusChange,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ring
            ? BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
                border: Border.all(
                  color: context.mm.colors.focus,
                  width: MmSize.focusRing,
                ),
              )
            : const BoxDecoration(),
        child: Material(type: MaterialType.transparency, child: widget.child),
      ),
    );
  }
}
