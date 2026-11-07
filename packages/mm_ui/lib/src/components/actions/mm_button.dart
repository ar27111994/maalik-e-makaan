import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/actions/mm_action_icon.dart';
import 'package:mm_ui/src/foundation/mm_button_styles.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
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
/// its size, shows a progress indicator in place of its icon, ignores
/// further presses, and screen readers hear "Record payment, Loading".
/// Without an icon the indicator takes the label's place, centred: beside
/// the label it would widen the button and move what is around it, while
/// the landlord has just read the label to press it.
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

  /// An icon shown before the label (after it in right-to-left layouts). It
  /// grows with the text size, up to half as large again.
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
    final style = _style(Theme.of(context).colorScheme);
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
  /// labels and the icon size ([MmButtonStyles.labelled]), the destructive
  /// colours, and a press that does nothing visible while busy. The theme
  /// draws the focus ring, outside the button when it is filled.
  ButtonStyle _style(ColorScheme scheme) {
    final base = variant == MmButtonVariant.destructive
        ? MmButtonStyles.destructive(scheme)
        : MmButtonStyles.labelled;
    if (!busy) return base;
    return base.copyWith(
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      enableFeedback: false,
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.progress),
    );
  }
}

/// The inside of an [MmButton]: its icon and label, or the busy indicator.
class _ButtonContent extends StatelessWidget {
  const new({required this.label, required this.icon, required this.busy});

  final String label;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // As wide as its longest line, so a wrapped label stays beside its icon
    // instead of centring its lines across the whole button.
    final text = Text(
      label,
      textAlign: TextAlign.center,
      textWidthBasis: TextWidthBasis.longestLine,
    );
    final icon = this.icon;
    if (!busy) {
      if (icon == null) return text;
      return _withLeading(MmActionIcon(icon), text);
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

/// A small progress ring in the button's icon colour and size (grown with
/// the text, as the icon it replaces would be). When the platform asks for
/// reduced motion it stands still as an open ring.
class _BusyIndicator extends StatelessWidget {
  const new();

  /// The share of the ring drawn when it does not spin.
  static const _stillValue = 0.75;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    return SizedBox.square(
      dimension: MmActionIcon.sizeIn(context),
      child: Padding(
        padding: const EdgeInsets.all(MmSpace.sHalf),
        child: CircularProgressIndicator(
          value: MediaQuery.disableAnimationsOf(context) ? _stillValue : null,
          strokeWidth: MmSize.stroke,
          color: color,
          backgroundColor: color?.withValues(alpha: 0.24),
        ),
      ),
    );
  }
}
