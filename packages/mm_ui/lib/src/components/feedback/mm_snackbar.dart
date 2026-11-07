import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_banner.dart';
import 'package:mm_ui/src/components/feedback/mm_dismiss_button.dart';
import 'package:mm_ui/src/components/feedback/mm_line_icon.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/theme/mm_theme.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How long a snackbar without an action stays: Material's usual time.
const Duration _messageDuration = Duration(seconds: 4);

/// How long a snackbar with an action stays: at least ten seconds, so the
/// landlord has time to read it and reach the action (WCAG 2.2.1).
const Duration _actionDuration = Duration(seconds: 10);

/// Shows a short message at the bottom of the screen, floating above the
/// content, and completes when it closes.
///
/// Use it for a passing confirmation ("Payment recorded", "Receipt
/// shared"), optionally with one action ("Undo"). It replaces any snackbar
/// already showing instead of queueing behind it. With a [tone], the tone's
/// icon precedes the message (the words still say what happened). With an
/// action, [actionLabel] is a real button that calls [onAction] once and
/// closes the snackbar, and the snackbar stays for ten seconds; without one
/// it closes after four. When a screen reader is on, a snackbar with an
/// action stays until the landlord uses the action or its "Dismiss" button,
/// so it cannot vanish before they reach it. The action sits at the end of
/// the message's row, or under the message when it would take more than a
/// third of the row or squeeze the message past two lines. Screen
/// readers announce the message as it appears. When the platform asks for
/// reduced motion it appears and disappears without animating.
///
/// The snackbar is drawn in the opposite mode (a dark bar on the light
/// theme, a light one on the dark theme), and everything in it, its focus
/// rings included, takes that mode's colours. It lines up with the page's
/// 16 dp gutter.
///
/// Don't use it for errors the landlord must act on or for anything they
/// need to read again: use an `MmBanner`, which stays on the screen. Needs
/// a `ScaffoldMessenger` with a `Scaffold` below it, as `MaterialApp`
/// provides.
///
/// ```dart
/// await showMmSnackbar(
///   context,
///   message: l10n.paymentRecorded,
///   tone: MmBannerTone.success,
///   actionLabel: l10n.undo,
///   onAction: undoPayment,
/// );
/// ```
Future<void> showMmSnackbar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  MmBannerTone? tone,
}) async {
  assert(
    (actionLabel == null) == (onAction == null),
    'A snackbar action needs both a label and a callback.',
  );
  final messenger = ScaffoldMessenger.of(context);
  final still = MediaQuery.disableAnimationsOf(context);
  final width = MediaQuery.sizeOf(context).width;
  final mm = context.mm;
  // The snackbar is drawn in the opposite mode's surface and ink, so what
  // is inside it (the icon, the action and the focus rings) takes the
  // opposite mode's theme.
  final inverse = MmTheme.data(
    brightness: Theme.of(context).brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light,
    script: mm.script,
    highContrast: mm.highContrast,
  );
  final hasAction = actionLabel != null && onAction != null;
  // A screen reader user moves to the action one element at a time and may
  // not reach it in ten seconds: the snackbar then stays until it is used
  // or dismissed (WCAG 2.2.1).
  final persist = hasAction && MediaQuery.accessibleNavigationOf(context);
  final wide = width > MmSize.contentMax + 2 * MmSpace.s4;

  final snackBar = SnackBar(
    content: Theme(
      data: inverse,
      child: _Content(
        message: message,
        tone: tone,
        action: hasAction
            ? _Action(label: actionLabel, onPressed: onAction)
            : null,
        dismissible: persist,
      ),
    ),
    padding: EdgeInsetsDirectional.only(
      start: MmSpace.s4,
      end: hasAction ? MmSpace.s2 : MmSpace.s4,
    ),
    duration: hasAction ? _actionDuration : _messageDuration,
    persist: persist,
    // On wide windows the snackbar keeps to the reading column's width;
    // otherwise it keeps the page's gutter at the sides and the bottom.
    width: wide ? MmSize.contentMax : null,
    margin: wide ? null : const EdgeInsets.all(MmSpace.s4),
  );

  // Reduced motion: the current snackbar goes at once and the new one
  // arrives without animating. Otherwise the current one animates out and
  // the new one follows. (The messenger keeps one animation controller for
  // every snackbar, so the animation style is only changed once nothing is
  // animating with the old one.)
  if (still) {
    messenger.removeCurrentSnackBar();
  } else {
    messenger.hideCurrentSnackBar();
  }
  final controller = messenger.showSnackBar(
    snackBar,
    snackBarAnimationStyle: still ? AnimationStyle.noAnimation : null,
  );
  await controller.closed;
}

/// The inside of a snackbar: the tone's icon and the message, the dismiss
/// button at the end of the first line when the snackbar stays, and the
/// action at the end of the row, or under the message at the end edge.
///
/// The action moves under the message when its button would take more than
/// a third of the row, or when the message beside it would wrap past two
/// lines. Material's rule is a quarter of the bar for the label's text
/// alone; with the button's padding counted, as here at the real text size,
/// that is about a third of the row. There is no Material habit of keeping
/// 40% of the width free beside a message moved off the action's row,
/// which squeezes it at large text.
class _Content extends StatelessWidget {
  const new({
    required this.message,
    required this.tone,
    required this.action,
    required this.dismissible,
  });

  /// The share of the row an action's button may take beside the message.
  static const double actionShare = 1 / 3;

  /// The most lines the message may wrap to beside the action.
  static const int linesBesideAction = 2;

  /// The space above and below the message.
  static const double textPadding = MmSpace.s3;

  final String message;
  final MmBannerTone? tone;
  final _Action? action;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    final action = this.action;
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final iconWidth = tone == null
        ? 0.0
        : MmLineIcon.sizeOf(context) + MmSpace.s3;
    final text = Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: textPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          if (tone != null)
            MmLineIcon(
              icon: tone.icon,
              color: tone.colorOf(context.mm.colors),
              style: style,
            ),
          Expanded(child: MmScriptText(message, style: style)),
        ],
      ),
    );
    final dismiss = dismissible
        ? MmDismissButton(
            color: style.color!,
            onPressed: () =>
                ScaffoldMessenger.of(context)
                    .hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
            style: style,
            textTop: textPadding,
          )
        : null;
    final firstRow = dismiss == null
        ? text
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              dismiss,
            ],
          );
    if (action == null) return firstRow;

    final label = TextPainter(
      text: TextSpan(
        text: action.label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    // A text button is its label inside the theme's padding, and at least
    // a touch target wide.
    final actionWidth = (label.width + 2 * MmSpace.s4).clamp(
      MmSize.minTarget,
      double.infinity,
    );
    label.dispose();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Without a dismiss button the row is the message and the action;
        // a snackbar that stays puts the action under the message, so the
        // message keeps the width beside the dismiss button.
        var beside =
            !dismissible && actionWidth + MmSpace.s2 <= width * actionShare;
        if (beside) {
          final lines = TextPainter(
            text: TextSpan(text: message, style: style),
            textScaler: scaler,
            textDirection: direction,
          )..layout(maxWidth: width - actionWidth - MmSpace.s2 - iconWidth);
          beside = lines.computeLineMetrics().length <= linesBesideAction;
          lines.dispose();
        }
        if (beside) {
          return Row(
            spacing: MmSpace.s2,
            children: [
              Expanded(child: text),
              action,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            firstRow,
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}

/// A snackbar's action: a text button in the snackbar's own theme (the
/// opposite mode's cobalt and focus ring) that calls [onPressed] once and
/// closes the snackbar.
class _Action extends StatefulWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  /// Whether the action ran; a second press while the snackbar leaves does
  /// nothing. The button stays enabled so its colours do not change.
  bool _done = false;

  void _press() {
    if (_done) return;
    _done = true;
    widget.onPressed();
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar(reason: SnackBarClosedReason.action);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: _press, child: Text(widget.label));
  }
}
