import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_no_controls.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A flat sheet of paper that may be tapped: the body of cards, stat tiles
/// and list rows.
///
/// [outlined] surfaces take the theme's card shape and colour (a hairline
/// border, `md` corners, no shadow); the others are square and transparent
/// unless given a [color]. A static outlined surface is bounded by the
/// decorative rule; a tappable one by the outline colour, because the rule
/// is never the only boundary of a control.
///
/// When [onTap] is set the whole surface is an ink well that the keyboard
/// can focus and activate. While the surface itself has keyboard focus its
/// border becomes the 2 dp focus ring, as a focused outlined button's does;
/// focus on anything inside it rings that, not the surface. A tap never
/// leaves a ring behind. A tappable surface is one button, so it holds no
/// controls: in debug builds one inside it is reported.
///
/// Internal to the display family. It adds no semantics of its own beyond
/// the ink well's tap and focus actions; its users say what it is.
class MmSurface extends StatefulWidget {
  /// Creates the surface of [owner] around [child] that calls [onTap] when
  /// activated.
  const new({
    required this.child,
    required this.onTap,
    required this.owner,
    this.outlined = true,
    this.color,
    super.key,
  });

  /// The content, already padded.
  final Widget child;

  /// Called when the surface is tapped or activated from the keyboard. When
  /// null the surface is static: not focusable and without ink.
  final VoidCallback? onTap;

  /// The component this surface is the body of ("MmCard"), named when a
  /// control inside a tappable surface is reported.
  final String owner;

  /// Whether the surface has the card's border and corners.
  final bool outlined;

  /// The fill. Defaults to the card colour when [outlined], otherwise none.
  final Color? color;

  @override
  State<MmSurface> createState() => _MmSurfaceState();
}

class _MmSurfaceState extends State<MmSurface>
    with MmFocusHighlight<MmSurface> {
  late final FocusNode _focusNode = FocusNode(debugLabel: widget.owner)
    ..addListener(_handleFocusChange);

  /// Whether the surface itself, not something inside it, has focus.
  bool _focused = false;

  void _handleFocusChange() {
    final focused = _focusNode.hasPrimaryFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final card = Theme.of(context).cardTheme;
    final owner = widget.owner;
    final tappable = widget.onTap != null;
    final resting = widget.outlined
        ? card.shape ?? _cardShape
        : const RoundedRectangleBorder();
    final shape = switch (resting) {
      final OutlinedBorder border
          when tappable && _focused && showsFocusHighlights =>
        border.copyWith(
          side: BorderSide(color: colors.focus, width: MmSize.focusRing),
        ),
      final OutlinedBorder border when tappable && widget.outlined =>
        border.copyWith(side: border.side.copyWith(color: colors.outline)),
      _ => resting,
    };
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
        focusNode: _focusNode,
        customBorder: shape,
        child: MmSurfaceFill(
          color: fill,
          child: MmNoControls(
            enabled: tappable,
            focusNode: _focusNode,
            summary: 'A tappable $owner holds a control.',
            description:
                'A tappable $owner is one button: screen readers read '
                'everything in it as that button, so a button, field or '
                'switch inside it cannot be reached, and a tap on it is '
                'easily mistaken for a tap on the $owner.',
            hint:
                'Leave onTap null and give the $owner its own buttons, or '
                'move the control out of the $owner.',
            child: widget.child,
          ),
        ),
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

/// Marks the subtree inside an `MmCard`: a nested card reports itself, and
/// a stat tile drops its own border so it does not read as a card inside a
/// card.
///
/// Internal to the display family.
class MmCardScope extends InheritedWidget {
  /// Marks [child] as inside a card.
  const new({required super.child, super.key});

  /// Whether [context] is inside an `MmCard`.
  static bool isIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MmCardScope>() != null;

  @override
  bool updateShouldNotify(MmCardScope oldWidget) => false;
}
