import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A flat sheet of paper that may be tapped: the body of cards, stat tiles
/// and list rows.
///
/// [outlined] surfaces take the theme's card shape and colour (a hairline
/// rule border, `md` corners, no shadow); the others are square and
/// transparent unless given a [color]. When [onTap] is set the whole surface
/// is an ink well that the keyboard can focus and activate; while it has
/// keyboard focus its border becomes the 2 dp focus ring, as a focused
/// outlined button's does. A tap never leaves a ring behind.
///
/// Internal to the display family. It adds no semantics of its own beyond
/// the ink well's tap and focus actions; its users say what it is.
class MmSurface extends StatefulWidget {
  /// Creates a surface around [child] that calls [onTap] when activated.
  const new({
    required this.child,
    required this.onTap,
    this.outlined = true,
    this.color,
    super.key,
  });

  /// The content, already padded.
  final Widget child;

  /// Called when the surface is tapped or activated from the keyboard. When
  /// null the surface is static: not focusable and without ink.
  final VoidCallback? onTap;

  /// Whether the surface has the card's border and corners.
  final bool outlined;

  /// The fill. Defaults to the card colour when [outlined], otherwise none.
  final Color? color;

  @override
  State<MmSurface> createState() => _MmSurfaceState();
}

class _MmSurfaceState extends State<MmSurface> {
  bool _focused = false;
  late bool _keyboard;

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

  void _handleHighlightMode(FocusHighlightMode mode) =>
      setState(() => _keyboard = _isKeyboard(mode));

  void _handleFocusChange(bool focused) => setState(() => _focused = focused);

  /// Whether focus should be drawn: only while the user drives the app from
  /// a keyboard, as Material does for its own focus highlights.
  static bool _isKeyboard(FocusHighlightMode mode) =>
      mode == FocusHighlightMode.traditional;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final card = Theme.of(context).cardTheme;
    final resting = widget.outlined
        ? card.shape ?? _cardShape
        : const RoundedRectangleBorder();
    final shape = _focused && _keyboard && resting is OutlinedBorder
        ? resting.copyWith(
            side: BorderSide(color: colors.focus, width: MmSize.focusRing),
          )
        : resting;
    final fill =
        widget.color ??
        (widget.outlined ? card.color ?? colors.surface : Colors.transparent);
    return Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      animationDuration: MmMotion.of(context, MmDuration.quick),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: _handleFocusChange,
        customBorder: shape,
        child: MmSurfaceFill(color: fill, child: widget.child),
      ),
    );
  }

  /// The card shape when the theme has none.
  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(MmRadius.md)),
  );
}

/// The fill of the nearest [MmSurface], so content drawn in a tonal colour
/// (an avatar's circle) can stay visible on a surface of the same tone (a
/// selected row).
///
/// Internal to the display family.
class MmSurfaceFill extends InheritedWidget {
  /// Tells [child] that it sits on [color].
  const new({required this.color, required super.child, super.key});

  /// The colour the surface is filled with.
  final Color color;

  /// The fill of the nearest surface around [context], or null outside one.
  static Color? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MmSurfaceFill>()?.color;

  @override
  bool updateShouldNotify(MmSurfaceFill oldWidget) => color != oldWidget.color;
}
