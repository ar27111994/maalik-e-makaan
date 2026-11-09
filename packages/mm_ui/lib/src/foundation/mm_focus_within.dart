import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Draws the design system's [MmSize.focusRing] focus ring around [child]
/// while any control inside it has keyboard focus (see
/// [MmFocusHighlight]): the ring of a whole row whose control is a
/// checkbox, a switch or a radio button.
///
/// Material tiles only tint themselves when focused; the ring makes the
/// focused row as plain as a focused button. It adds no focus stop and no
/// semantics of its own. [child] is set on a transparent [Material] of its
/// own, so a tile's hover, focus and splash ink show on whatever surface
/// the row sits on (a card, a coloured page).
///
/// Internal to mm_ui: any component family may use it.
class MmFocusWithin extends StatefulWidget {
  /// Rings [child] with corners of [radius] while something in it has
  /// keyboard focus.
  const new({required this.child, this.radius = MmRadius.sm, super.key});

  /// The row to ring.
  final Widget child;

  /// The corner radius of the ring.
  final double radius;

  @override
  State<MmFocusWithin> createState() => _MmFocusWithinState();
}

class _MmFocusWithinState extends State<MmFocusWithin>
    with MmFocusHighlight<MmFocusWithin> {
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
