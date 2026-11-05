import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How much emphasis an [MmButton] carries.
enum MmButtonVariant {
  /// The one main action of a view, filled in cobalt ("Record payment").
  primary,

  /// The alternative to the main action, outlined ("Send reminder").
  secondary,

  /// A low-emphasis action, text only ("View ledger").
  tertiary,

  /// An action that removes or destroys a record, filled in the overdue
  /// colour ("Remove tenant"). Ask for confirmation before acting on it.
  destructive,
}

/// A labelled button: the way a landlord does something on a screen.
///
/// Use [MmButtonVariant.primary] for the one main action of a view,
/// [MmButtonVariant.secondary] for its alternative,
/// [MmButtonVariant.tertiary] for low-emphasis actions and
/// [MmButtonVariant.destructive] for an action that removes a record. The
/// label is a verb the app supplies from its own localisations ("Record
/// payment", never "OK"). Long labels wrap and the button grows taller; it
/// never truncates them.
///
/// Set [busy] while the action's work runs: the button keeps its colours and
/// its size, shows a progress indicator in place of its icon (or, without an
/// icon, in place of its label), ignores further presses, and screen readers
/// hear "Record payment, Loading".
///
/// Don't use it for an icon on its own (use `MmIconButton`), for the screen's
/// floating action (use `MmFab`) or to choose between options (use
/// `MmSegmentedControl`).
///
/// ```dart
/// MmButton(
///   label: l10n.recordPayment,
///   icon: MmIcons.payment,
///   busy: saving,
///   onPressed: recordPayment,
/// )
/// ```
class MmButton extends StatelessWidget {
  /// Creates a button that calls [onPressed] when activated.
  const new({
    required this.label,
    required this.onPressed,
    this.variant = MmButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.expand = false,
    super.key,
  });

  /// What the button does, as a verb ("Record payment").
  final String label;

  /// Called when the button is tapped or activated from the keyboard. When
  /// null the button is disabled.
  final VoidCallback? onPressed;

  /// The emphasis of the button.
  final MmButtonVariant variant;

  /// An icon shown before the label (after it in right-to-left layouts).
  final IconData? icon;

  /// Whether the button's action is running: it shows a progress indicator,
  /// ignores presses and keyboard activation, and keeps its colours, size
  /// and keyboard focus.
  final bool busy;

  /// Whether the button fills the width of its parent, which must be
  /// bounded. Otherwise it is as wide as its label.
  final bool expand;

  /// Stands in for [onPressed] while busy, so the button keeps its enabled
  /// colours and its keyboard focus but does nothing when activated.
  static void _ignorePress() {}

  @override
  Widget build(BuildContext context) {
    final callback = busy && onPressed != null ? _ignorePress : onPressed;
    final style = _style(context.mm.colors);
    final content = _ButtonContent(label: label, icon: icon, busy: busy);
    final Widget button = switch (variant) {
      MmButtonVariant.primary || MmButtonVariant.destructive => FilledButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      MmButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      MmButtonVariant.tertiary => TextButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
    };
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  /// What this button adds to the theme's button styles: room for wrapped
  /// labels, the icon size, the destructive colours, a focus ring that shows
  /// on a filled button, and a press that does nothing visible while busy.
  ButtonStyle _style(MmColorTokens colors) {
    // The fill and text colours of a filled button. The theme draws its
    // focus ring in the focus colour, which is the cobalt of the primary
    // fill itself; a filled button draws its ring in its text colour.
    final (fill, ink) = switch (variant) {
      MmButtonVariant.primary => (colors.primary, colors.onPrimary),
      MmButtonVariant.destructive => (colors.overdue, onOverdue(colors)),
      MmButtonVariant.secondary || MmButtonVariant.tertiary => (null, null),
    };
    final destructive = variant == MmButtonVariant.destructive;
    return ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s4,
          vertical: MmSpace.s2,
        ),
      ),
      iconSize: const WidgetStatePropertyAll(MmSize.iconMd),
      backgroundColor: destructive ? _whileEnabled(fill) : null,
      foregroundColor: destructive ? _whileEnabled(ink) : null,
      side: ink == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: ink, width: MmSize.focusRing)
                  : null,
            ),
      overlayColor: busy
          ? const WidgetStatePropertyAll(Colors.transparent)
          : null,
      splashFactory: busy ? NoSplash.splashFactory : null,
      enableFeedback: busy ? false : null,
      mouseCursor: busy
          ? const WidgetStatePropertyAll(SystemMouseCursors.progress)
          : null,
    );
  }

  /// The text colour on the overdue fill of a destructive button: whichever
  /// of the surface and ink roles contrasts more with it. The token build
  /// checks the surface on overdue at 4.5:1 or better in every mode.
  static Color onOverdue(MmColorTokens colors) {
    final fill = colors.overdue.computeLuminance();
    double contrast(Color color) {
      final other = color.computeLuminance();
      return (math.max(fill, other) + 0.05) / (math.min(fill, other) + 0.05);
    }

    return contrast(colors.surface) >= contrast(colors.ink)
        ? colors.surface
        : colors.ink;
  }

  /// [color] while the button is enabled; the theme's disabled colours
  /// otherwise.
  static WidgetStateProperty<Color?> _whileEnabled(Color? color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : color,
      );
}

/// The inside of an [MmButton]: its icon and label, or the busy indicator.
class _ButtonContent extends StatelessWidget {
  const new({required this.label, required this.icon, required this.busy});

  final String label;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    final icon = this.icon;
    if (!busy) {
      if (icon == null) return text;
      return _withLeading(Icon(icon), text);
    }
    const indicator = _BusyIndicator();
    final content = icon == null
        // Without an icon, the indicator takes the label's place; the label
        // still sizes the button so it keeps its width.
        ? Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: text,
              ),
              indicator,
            ],
          )
        : _withLeading(indicator, text);
    return Semantics(
      label: '$label, ${MmLocalizations.of(context).loading}',
      child: ExcludeSemantics(child: content),
    );
  }

  /// [leading] then [text], which wraps when space runs out.
  static Widget _withLeading(Widget leading, Widget text) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: MmSpace.s2,
    children: [
      leading,
      Flexible(child: text),
    ],
  );
}

/// A small progress ring in the button's icon colour and size. When the
/// platform asks for reduced motion it stands still as an open ring.
class _BusyIndicator extends StatelessWidget {
  const new();

  /// The share of the ring drawn when it does not spin.
  static const _stillValue = 0.75;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? MmSize.iconMd;
    final color = icon.color ?? DefaultTextStyle.of(context).style.color;
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(MmSpace.sHalf),
        child: CircularProgressIndicator(
          value: MediaQuery.disableAnimationsOf(context) ? _stillValue : null,
          strokeWidth: MmSpace.sHalf,
          color: color,
          backgroundColor: color?.withValues(alpha: 0.24),
        ),
      ),
    );
  }
}
