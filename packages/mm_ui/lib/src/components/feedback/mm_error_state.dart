import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';
import 'package:mm_ui/src/components/feedback/mm_state_layout.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// What a screen shows when its content could not be loaded: the ledger
/// did not sync, the receipts could not be fetched.
///
/// Laid out like `MmEmptyState`: the error icon in the overdue colour, an
/// optional [title] as a heading, and the [message], which says what
/// happened and what to do next in one sentence and is announced as soon as
/// it appears (a live region). With [onRetry] a filled "Try again" button
/// follows (the word comes from `MmLocalizations`).
///
/// Give [details] (an error code, a server message) for support: they sit
/// in a collapsed section labelled [detailsLabel] ("Technical details"),
/// shown in a sunken well when expanded, and can be selected and copied.
/// Technical details written in Latin script read left to right in both
/// languages.
///
/// Use it when loading failed. For an error on one field, the field shows
/// it; for a passing problem on a screen that still works, use `MmBanner`.
///
/// ```dart
/// MmErrorState(
///   title: l10n.ledgerUnavailableTitle,
///   message: l10n.ledgerUnavailableMessage,
///   onRetry: reload,
///   details: error.toString(),
///   detailsLabel: l10n.technicalDetails,
/// )
/// ```
class MmErrorState extends StatelessWidget {
  /// Creates an error state that says [message].
  const new({
    required this.message,
    this.title,
    this.onRetry,
    this.details,
    this.detailsLabel,
    super.key,
  }) : assert(
         details == null || detailsLabel != null,
         'Details need a label for the section that shows them.',
       );

  /// What happened and what to do next, in one sentence ("Your ledger
  /// could not be loaded. Check your connection and try again.").
  final String message;

  /// A heading above the message ("Ledger unavailable").
  final String? title;

  /// Called when the retry button is activated. Without it no retry button
  /// is shown.
  final VoidCallback? onRetry;

  /// Technical details of the failure, shown on request.
  final String? details;

  /// The label of the section that shows [details] ("Technical details").
  /// Required when [details] is given.
  final String? detailsLabel;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    final details = this.details;
    return MmStateLayout(
      icon: MmIcons.error,
      iconColor: context.mm.colors.overdue,
      title: title,
      message: message,
      liveMessage: true,
      action: onRetry == null
          ? null
          : MmFilledAction(
              label: MmLocalizations.of(context).retry,
              icon: MmIcons.refresh,
              onPressed: onRetry,
            ),
      extra: details == null
          ? null
          : _Details(label: detailsLabel!, details: details),
    );
  }
}

/// The collapsible section that shows the technical details of an error.
class _Details extends StatefulWidget {
  const new({required this.label, required this.details});

  final String label;
  final String details;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final style = mm.styleFor(
      widget.details,
      Theme.of(context).textTheme.bodyMedium!,
    );
    final latin = !MmSemantics.hasArabicScript(widget.details);
    // With reduced motion the section opens at once (an AnimatedSize with
    // no duration would re-lay itself out while laying out).
    final duration = MmMotion.of(context, MmDuration.standard);
    final well = !_open
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsetsDirectional.only(top: MmSpace.s2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mm.colors.surfaceSunken,
                // A hairline rule in the high-contrast modes, where the
                // sunken tone alone barely differs from the page.
                border: mm.highContrast
                    ? Border.all(color: mm.colors.rule)
                    : null,
                borderRadius: const BorderRadius.all(
                  Radius.circular(MmRadius.sm),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MmSpace.s3),
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    widget.details,
                    style: style,
                    textDirection: latin ? TextDirection.ltr : null,
                  ),
                ),
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _toggle,
          style: const ButtonStyle(
            iconSize: WidgetStatePropertyAll(MmSize.iconMd),
          ),
          icon: Icon(_open ? MmIcons.collapse : MmIcons.expand),
          iconAlignment: IconAlignment.end,
          label: Semantics(
            expanded: _open,
            child: Text(widget.label, textAlign: TextAlign.center),
          ),
        ),
        if (duration == Duration.zero)
          well
        else
          AnimatedSize(
            duration: duration,
            curve: MmEasing.standard,
            alignment: AlignmentDirectional.topCenter,
            child: well,
          ),
      ],
    );
  }
}
