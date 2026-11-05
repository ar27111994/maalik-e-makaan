import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_banner.dart';
import 'package:mm_ui/src/components/feedback/mm_line_icon.dart';
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
/// it closes after four. The action sits at the end of the message's row,
/// or under the message when its label is long or the text is large.
/// Screen readers announce the message as it appears. When the platform
/// asks for reduced motion it appears and disappears without animating.
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
  // The snackbar is drawn in the opposite mode's surface and ink, so its
  // icon takes the opposite mode's status colour.
  final inverse = MmTheme.tokensFor(
    Theme.of(context).brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light,
    highContrast: mm.highContrast,
  );
  final hasAction = actionLabel != null && onAction != null;

  final snackBar = SnackBar(
    content: _Content(
      message: message,
      icon: tone?.icon,
      iconColor: tone?.colorOf(inverse),
      action: hasAction
          ? _Action(label: actionLabel, onPressed: onAction)
          : null,
    ),
    padding: EdgeInsetsDirectional.only(
      start: MmSpace.s4,
      end: hasAction ? MmSpace.s2 : MmSpace.s4,
    ),
    duration: hasAction ? _actionDuration : _messageDuration,
    persist: false,
    // On wide windows the snackbar keeps to the reading column's width.
    width: width > MmSize.contentMax + 2 * MmSpace.s4
        ? MmSize.contentMax
        : null,
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

/// The inside of a snackbar: the tone's icon and the message, with the
/// action at the end of the row, or under the message at the end edge when
/// its label would take more than a quarter of the width (Material's rule,
/// here measured at the real text size, and without Material's habit of
/// keeping 40% of the width free beside a message moved off the action's
/// row, which squeezes it at large text).
class _Content extends StatelessWidget {
  const new({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.action,
  });

  /// The share of the width an action's label may take beside the message.
  static const double actionShare = 0.25;

  final String message;
  final IconData? icon;
  final Color? iconColor;
  final _Action? action;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final action = this.action;
    final text = Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          if (icon != null)
            MmLineIcon(
              icon: icon,
              color: iconColor!,
              style: DefaultTextStyle.of(context).style,
            ),
          Expanded(child: Text(message)),
        ],
      ),
    );
    if (action == null) return text;
    final label = TextPainter(
      text: TextSpan(
        text: action.label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final labelWidth = label.width;
    label.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (labelWidth + MmSpace.s2 <= constraints.maxWidth * actionShare) {
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
            text,
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}

/// A snackbar's action: a text button in the snackbar's action colour that
/// calls [onPressed] once and closes the snackbar.
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
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).snackBarTheme.actionTextColor,
      ),
      onPressed: _press,
      child: Text(widget.label),
    );
  }
}
