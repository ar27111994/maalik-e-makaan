import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_line_icon.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// What kind of notice an [MmBanner] (or a snackbar) gives. Each tone has
/// its own colours and icon, and is always shown with words: the colour
/// never carries the meaning alone.
enum MmBannerTone {
  /// Neutral information ("Reminders go out on the 1st"): the credit
  /// colours and the info icon.
  info(MmIcons.info),

  /// Something went through ("Payment recorded"): the paid colours and the
  /// success icon.
  success(MmIcons.success),

  /// Something needs attention soon ("Lease ends in 14 days"): the due-soon
  /// colours and the warning icon. Announced as soon as it appears.
  warning(MmIcons.warning),

  /// Something failed or is overdue ("Rent reminders could not be sent"):
  /// the overdue colours and the error icon. Announced as soon as it
  /// appears.
  error(MmIcons.error);

  new(this.icon);

  /// The tone's default icon.
  final IconData icon;

  /// Whether notices of this tone are announced as soon as they appear (a
  /// live region): warnings and errors.
  bool get urgent => this == warning || this == error;

  /// The fill of a notice of this tone in [colors].
  Color containerOf(MmColorTokens colors) => switch (this) {
    info => colors.creditContainer,
    success => colors.paidContainer,
    warning => colors.dueSoonContainer,
    error => colors.overdueContainer,
  };

  /// The text and icon colour on [containerOf] in [colors].
  Color onContainerOf(MmColorTokens colors) => switch (this) {
    info => colors.onCreditContainer,
    success => colors.onPaidContainer,
    warning => colors.onDueSoonContainer,
    error => colors.onOverdueContainer,
  };

  /// The tone's own colour in [colors], for an icon on a plain surface.
  Color colorOf(MmColorTokens colors) => switch (this) {
    info => colors.credit,
    success => colors.paid,
    warning => colors.dueSoon,
    error => colors.overdue,
  };
}

/// An inline notice inside a screen: a lease about to end, reminders that
/// could not be sent, a sync that finished.
///
/// A flat panel in the [tone]'s container colour with the tone's icon (or
/// [icon]) before an optional [title] and the [message]. With
/// [actionLabel] a text button under the message calls [onAction] (and is
/// disabled while it is null); with [onDismiss] a close button at the end
/// ("Dismiss" for screen readers) removes it. Warning and error banners are
/// announced as soon as they appear. Text wraps at any size.
///
/// Use it for a lasting condition the landlord should know about while
/// using the screen. For a passing confirmation, use `showMmSnackbar`;
/// when the whole screen failed to load, use `MmErrorState`.
///
/// ```dart
/// MmBanner(
///   tone: MmBannerTone.warning,
///   title: l10n.leaseEndingTitle,
///   message: l10n.leaseEndingMessage(tenant.name, days),
///   actionLabel: l10n.renewLease,
///   onAction: renewLease,
///   onDismiss: hideBanner,
/// )
/// ```
class MmBanner extends StatelessWidget {
  /// Creates a banner of [tone] that says [message].
  const new({
    required this.tone,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.icon,
    super.key,
  }) : assert(
         onAction == null || actionLabel != null,
         'An action needs a label.',
       );

  /// The kind of notice: its colours, default icon and urgency.
  final MmBannerTone tone;

  /// What the landlord should know, in a sentence or two.
  final String message;

  /// A short heading above the message ("Lease ending").
  final String? title;

  /// The label of the banner's action ("Renew lease"). Without it no
  /// action is shown.
  final String? actionLabel;

  /// Called when the action is activated. When null the action is shown
  /// disabled.
  final VoidCallback? onAction;

  /// Called when the dismiss button is activated. Without it the banner has
  /// no dismiss button.
  final VoidCallback? onDismiss;

  /// An icon in place of the tone's default one.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final ink = tone.onContainerOf(colors);
    final title = this.title;
    final actionLabel = this.actionLabel;
    final onDismiss = this.onDismiss;
    final titleStyle = text.titleMedium!.copyWith(color: ink);
    final messageStyle = text.bodyLarge!.copyWith(color: ink);
    final firstLine = title == null ? messageStyle : titleStyle;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title, style: titleStyle),
        Text(message, style: messageStyle),
        if (actionLabel != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onAction, child: Text(actionLabel)),
          ),
      ],
    );

    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: MmSpace.s4,
        top: MmSpace.s3,
        bottom: actionLabel == null ? MmSpace.s3 : MmSpace.s1,
        end: onDismiss == null ? MmSpace.s4 : MmSpace.s0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          MmLineIcon(icon: icon ?? tone.icon, color: ink, style: firstLine),
          Expanded(child: body),
        ],
      ),
    );

    return Semantics(
      container: true,
      liveRegion: tone.urgent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.containerOf(colors),
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.md)),
        ),
        child: onDismiss == null
            ? content
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  _DismissButton(
                    color: ink,
                    onPressed: onDismiss,
                    // Centres the button on the first line of text.
                    top: math.max<double>(
                      0,
                      MmSpace.s3 +
                          MmLineIcon.lineHeightOf(context, firstLine) / 2 -
                          MmSize.minTarget / 2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The close button at the end of a dismissible banner.
class _DismissButton extends StatelessWidget {
  const new({required this.color, required this.onPressed, required this.top});

  final Color color;
  final VoidCallback onPressed;
  final double top;

  @override
  Widget build(BuildContext context) {
    final label = MmLocalizations.of(context).dismiss;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: top, end: MmSpace.s1),
      // The tooltip's words are already the label; announcing them again as
      // a tooltip would make screen readers say them twice.
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          color: color,
          icon: Semantics(label: label, child: const Icon(MmIcons.close)),
        ),
      ),
    );
  }
}
