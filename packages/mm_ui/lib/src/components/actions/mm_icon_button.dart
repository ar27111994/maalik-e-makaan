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
/// on or off, and while on it fills with cobalt whatever its variant, so on
/// and off differ by far more than a tint (3:1 or better against the off
/// look in every mode) and never by colour alone. A [selectedIcon], if
/// given, also swaps the glyph. Disabled, its icon is muted ink, and a
/// toggle that is on keeps a fill (in the rule colour of disabled edges), so
/// it still reads as on.
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

  /// The colours and edge of each variant and toggle state. The theme draws
  /// the focus ring (outside the button, so it shows on a cobalt fill).
  ///
  /// Enabled, a toggle that is on is cobalt in every variant; off, it keeps
  /// its variant's look (a filled or tonal one on the tonal fill, not on
  /// sunken paper, which is the disabled fill). Disabled, every icon is
  /// muted ink: a filled or tonal button sits on sunken paper inside the
  /// rule border, an outlined one keeps a rule outline, a standard one has
  /// no edge, and a toggle that is on is filled in the rule colour, so it
  /// still reads as on (a sunken fill would vanish on the page, and a ring
  /// would read as an outlined toggle that is off).
  ButtonStyle _style(MmColorTokens colors) {
    final on = selected ?? false;
    // The enabled fill and icon colour for the variant and toggle state
    // (null: not a toggle). A null colour keeps the variant's default and,
    // for a standard button, lets an app bar choose its icon colour.
    final (Color? fill, Color? ink) = switch ((variant, selected)) {
      (_, true) => (colors.primary, colors.onPrimary),
      (MmIconButtonVariant.standard || MmIconButtonVariant.outlined, null) => (
        null,
        null,
      ),
      (MmIconButtonVariant.standard || MmIconButtonVariant.outlined, false) => (
        null,
        colors.inkMuted,
      ),
      (MmIconButtonVariant.filled, null) => (colors.primary, colors.onPrimary),
      (MmIconButtonVariant.filled, false) => (
        colors.primaryContainer,
        colors.primary,
      ),
      (MmIconButtonVariant.tonal, null || false) => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
    };
    final (Color disabledFill, BorderSide disabledEdge) = switch (variant) {
      _ when on => (colors.rule, BorderSide.none),
      MmIconButtonVariant.filled || MmIconButtonVariant.tonal => (
        colors.surfaceSunken,
        BorderSide(color: colors.rule),
      ),
      MmIconButtonVariant.outlined => (
        Colors.transparent,
        BorderSide(color: colors.rule),
      ),
      MmIconButtonVariant.standard => (Colors.transparent, BorderSide.none),
    };
    bool disabled(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled);
    return ButtonStyle(
      iconSize: const WidgetStatePropertyAll(MmSize.iconLg),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => disabled(states) ? disabledFill : fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => disabled(states) ? colors.inkMuted : ink,
      ),
      // Enabled, an outlined button keeps Material's outline until it is
      // on (then it is filled); the other variants have no edge.
      side: WidgetStateProperty.resolveWith((states) {
        if (disabled(states)) return disabledEdge;
        return on ? BorderSide.none : null;
      }),
    );
  }
}
