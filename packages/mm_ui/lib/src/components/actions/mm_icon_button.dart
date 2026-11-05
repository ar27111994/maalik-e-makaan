import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How much emphasis an [MmIconButton] carries.
enum MmIconButtonVariant {
  /// The icon alone, for toolbars and rows of actions.
  standard,

  /// Filled in cobalt, for the main action of a compact area.
  filled,

  /// A tonal cobalt fill, between filled and standard.
  tonal,

  /// Outlined, for an alternative action beside a filled one.
  outlined,
}

/// A button that shows only an icon, with a 48 dp touch target.
///
/// The [tooltip] names the action: it shows on long press and hover and is
/// what screen readers announce. Give [selected] to make the button a toggle
/// (rent reminders on or off, a pinned property): it then reads as toggled
/// on or off, fills when selected, and shows [selectedIcon] if one is given,
/// so the state never rests on colour alone.
///
/// Use it where the icon is unmistakable (edit, share, close). When the
/// action needs words to be understood, use `MmButton`; for the screen's
/// floating action, use `MmFab`.
///
/// ```dart
/// MmIconButton(
///   icon: MmIcons.notificationsOff,
///   selectedIcon: MmIcons.notifications,
///   tooltip: l10n.rentReminders,
///   selected: remindersOn,
///   onPressed: toggleReminders,
/// )
/// ```
class MmIconButton extends StatelessWidget {
  /// Creates an icon button that calls [onPressed] when activated.
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = MmIconButtonVariant.standard,
    this.selected,
    this.selectedIcon,
    super.key,
  });

  /// The icon shown (while not [selected], for a toggle).
  final IconData icon;

  /// What the button does ("Edit tenant"): shown on long press and hover,
  /// and the button's label for screen readers.
  final String tooltip;

  /// Called when the button is tapped or activated from the keyboard. When
  /// null the button is disabled.
  final VoidCallback? onPressed;

  /// The emphasis of the button.
  final MmIconButtonVariant variant;

  /// Whether a toggle button is on. Null for a plain action button.
  final bool? selected;

  /// The icon shown while [selected] is true; [icon] when null.
  final IconData? selectedIcon;

  @override
  Widget build(BuildContext context) {
    final on = selected ?? false;
    final glyph = Semantics(
      label: tooltip,
      toggled: selected,
      child: Icon(on ? selectedIcon ?? icon : icon),
    );
    final style = _style(context.mm.colors);
    final button = switch (variant) {
      MmIconButtonVariant.standard => IconButton(
        onPressed: onPressed,
        style: style,
        icon: glyph,
      ),
      MmIconButtonVariant.filled => IconButton.filled(
        onPressed: onPressed,
        style: style,
        icon: glyph,
      ),
      MmIconButtonVariant.tonal => IconButton.filledTonal(
        onPressed: onPressed,
        style: style,
        icon: glyph,
      ),
      MmIconButtonVariant.outlined => IconButton.outlined(
        onPressed: onPressed,
        style: style,
        icon: glyph,
      ),
    };
    // The tooltip's words are already the label; announcing them again as
    // a tooltip would make screen readers say them twice.
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }

  /// The enabled colours of each variant and toggle state, the outline of
  /// the outlined variant (the theme draws none by default), and a focus
  /// ring that shows on a cobalt fill. Disabled buttons keep the variant's
  /// own disabled colours.
  ButtonStyle _style(MmColorTokens colors) {
    final on = selected ?? false;
    final outlined = variant == MmIconButtonVariant.outlined;
    // The enabled fill and icon colour for the variant and toggle state
    // (null: not a toggle). A null colour keeps the variant's default and,
    // for a standard button, lets an app bar choose its icon colour.
    final (Color? fill, Color? ink) = switch ((variant, selected)) {
      (MmIconButtonVariant.standard || MmIconButtonVariant.outlined, null) => (
        null,
        null,
      ),
      (MmIconButtonVariant.standard || MmIconButtonVariant.outlined, false) => (
        null,
        colors.inkMuted,
      ),
      (MmIconButtonVariant.standard, true) => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      (MmIconButtonVariant.outlined, true) => (
        colors.primary,
        colors.onPrimary,
      ),
      (MmIconButtonVariant.filled, false) => (
        colors.surfaceSunken,
        colors.primary,
      ),
      (MmIconButtonVariant.filled, null || true) => (
        colors.primary,
        colors.onPrimary,
      ),
      (MmIconButtonVariant.tonal, false) => (
        colors.surfaceSunken,
        colors.inkMuted,
      ),
      (MmIconButtonVariant.tonal, null || true) => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
    };
    // The theme's focus ring is cobalt, invisible on a cobalt fill; there
    // the ring takes the icon colour instead.
    final ring = fill == colors.primary && ink != null ? ink : colors.focus;
    return ButtonStyle(
      iconSize: const WidgetStatePropertyAll(MmSize.iconLg),
      backgroundColor: fill == null ? null : _whileEnabled(fill),
      foregroundColor: ink == null ? null : _whileEnabled(ink),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return outlined ? BorderSide(color: colors.rule) : null;
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: ring, width: MmSize.focusRing);
        }
        return outlined && !on ? BorderSide(color: colors.outline) : null;
      }),
    );
  }

  /// [color] while the button is enabled; the variant's disabled colours
  /// otherwise.
  static WidgetStateProperty<Color?> _whileEnabled(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : color,
      );
}
