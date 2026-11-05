import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';
import 'package:mm_ui/src/components/feedback/mm_state_layout.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// What a screen shows when there is nothing to list yet: no tenants, no
/// payments this month, no search results.
///
/// A centred block, at most 400 dp wide: a 48 dp [icon] in muted ink (no
/// tile behind it), the [title] as a heading, a one-sentence [message] that
/// says what to do next, and at most one filled action. Text wraps at any
/// size; in a screen's body the block is centred and scrolls when large
/// text makes it taller than the screen.
///
/// Give [actionLabel] to show the action; it calls [onAction], and is
/// disabled while [onAction] is null. Use it for a real absence of data.
/// When loading failed, use `MmErrorState`; while loading, use
/// `MmSkeletonList`.
///
/// ```dart
/// MmEmptyState(
///   icon: MmIcons.tenants,
///   title: l10n.noTenantsTitle,
///   message: l10n.noTenantsMessage,
///   actionLabel: l10n.addTenant,
///   onAction: addTenant,
/// )
/// ```
class MmEmptyState extends StatelessWidget {
  /// Creates an empty state titled [title].
  const new({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         onAction == null || actionLabel != null,
         'An action needs a label.',
       );

  /// The icon above the title, related to what is missing ("tenants").
  /// It is decorative and hidden from assistive technology.
  final IconData icon;

  /// What is empty ("No tenants yet"), announced as a heading.
  final String title;

  /// What to do next, in one sentence ("Add your first tenant to start
  /// tracking rent.").
  final String message;

  /// The label of the one action ("Add tenant"). Without it no action is
  /// shown.
  final String? actionLabel;

  /// Called when the action is activated. When null the action is shown
  /// disabled.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return MmStateLayout(
      icon: icon,
      iconColor: context.mm.colors.inkMuted,
      title: title,
      message: message,
      action: actionLabel == null
          ? null
          : MmFilledAction(label: actionLabel, onPressed: onAction),
    );
  }
}
