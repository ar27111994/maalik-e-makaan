import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_user_text.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The heading of a section of a page ("Tenants", "October dues"), with an
/// optional [subtitle] and an optional text action at the end ("See all").
///
/// The title is set in the title style, in sentence case, never in tracked
/// capitals, and screen readers announce it as a heading so people can jump
/// between sections. It wraps at large text sizes; when the action does not
/// fit beside the title it moves under the text, at the start edge. The
/// action's words line up with the edge of the content (the end edge beside
/// the title, the start edge under it): its button's padding hangs into the
/// page's margin, as far as keeps a 48 dp target inside the column.
///
/// Don't use it for the screen's own title (the app bar has it) or for a
/// label above a form field (fields carry their labels).
///
/// ```dart
/// MmSectionHeader(
///   title: l10n.tenants,
///   subtitle: l10n.overdueCount(3),
///   actionLabel: l10n.seeAll,
///   onAction: openTenants,
/// )
/// ```
class MmSectionHeader extends StatelessWidget {
  /// Creates a section header titled [title].
  const new({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         onAction == null || actionLabel != null,
         'An action needs an actionLabel that says what it does.',
       );

  /// The section's name ("Tenants"). It may be the landlord's data (a
  /// property's name), so it is set in its own script's face and keeps its
  /// own direction: in the Urdu UI a name in English is set in the Latin
  /// face.
  final String title;

  /// A line of context under the title in muted ink ("3 overdue this
  /// month").
  final String? subtitle;

  /// The words of the action at the end ("See all"). Without it there is no
  /// action.
  final String? actionLabel;

  /// Called when the action is activated. When null the action is shown
  /// disabled.
  final VoidCallback? onAction;

  /// The horizontal padding of the action's button, which hangs past the
  /// edge of the content so the action's words line up with it.
  static const double _actionPadding = MmSpace.s4;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    final actionLabel = this.actionLabel;
    return MmReflow(
      endOverhang: _actionPadding,
      start: Semantics(
        container: true,
        header: true,
        child: MmUserText(title, style: text.titleLarge!),
      ),
      below: subtitle == null
          ? null
          : Text(
              subtitle,
              style: text.bodyMedium!.copyWith(color: mm.colors.inkMuted),
            ),
      end: actionLabel == null
          ? null
          : TextButton(
              onPressed: onAction,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsetsDirectional.symmetric(horizontal: _actionPadding),
                ),
              ),
              child: Text(actionLabel),
            ),
    );
  }
}
