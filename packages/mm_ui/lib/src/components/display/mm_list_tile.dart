import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_reflow.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/components/display/mm_user_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One row of a list: a tenant, a property, a payment.
///
/// A [title] (wrapped, never truncated), an optional [subtitle] in muted ink
/// that ends with an ellipsis after [subtitleMaxLines] lines, an optional
/// [leading] widget (an `MmAvatar` or an icon) and an optional [trailing]
/// widget (an `MmAmount` or an `MmStatusBadge`). The title and subtitle are
/// the landlord's data: in the Urdu UI a name typed in English is set in the
/// Latin face, and in the English UI a name typed in Urdu in Nastaliq.
///
/// When the trailing widget and the title do not fit side by side (a narrow
/// screen or large text), the trailing widget moves under the text, at the
/// start edge, instead of squeezing the title. The row is at least 56 dp
/// tall and is one node for screen readers, reading the title, subtitle and
/// trailing widget together.
///
/// With [onTap] the row is a button: it shows ink when pressed, a focus ring
/// while it has keyboard focus and activates with Enter or Space. [selected]
/// tints it (in list-and-detail layouts) and sets the title in a heavier
/// weight, so the selection does not rely on colour alone.
///
/// Group rows inside an `MmCard` with zero padding, separated by dividers.
/// Don't use it for a label and value pair on a receipt (use
/// `MmDetailRow`) or for a setting with a switch (use `MmSwitchTile`).
///
/// ```dart
/// MmListTile(
///   leading: MmAvatar(name: tenant.name),
///   title: tenant.name,
///   subtitle: tenant.unitName,
///   trailing: MmAmount(amount: tenant.balance),
///   onTap: () => openTenant(tenant),
/// )
/// ```
class MmListTile extends StatelessWidget {
  /// Creates a list row titled [title].
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.subtitleMaxLines = 2,
    super.key,
  });

  /// The main line ("Ali Raza"). It wraps and is never truncated.
  final String title;

  /// A secondary line under the title ("Flat 3, Gulberg III, Lahore").
  final String? subtitle;

  /// A widget before the text, such as an `MmAvatar` or an [Icon]. Icons
  /// take the muted ink colour and the 24 dp size.
  final Widget? leading;

  /// A widget at the end edge, such as an `MmAmount` or an `MmStatusBadge`.
  /// It moves under the text when it does not fit beside the title.
  final Widget? trailing;

  /// Called when the row is tapped or activated from the keyboard. When
  /// null the row only shows information: not a button and not focusable.
  final VoidCallback? onTap;

  /// Whether this row is the one shown in the detail pane.
  final bool selected;

  /// The most lines the subtitle takes before it ends with an ellipsis.
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final ink = selected ? colors.onPrimaryContainer : colors.ink;
    final muted = selected ? colors.onPrimaryContainer : colors.inkMuted;
    final titleStyle = text.bodyLarge!.copyWith(
      color: ink,
      fontWeight: selected ? FontWeight.w600 : null,
    );
    final subtitleStyle = text.bodyMedium!.copyWith(color: muted);
    final subtitle = this.subtitle;
    final leading = this.leading;
    final trailing = this.trailing;

    final body = MmReflow(
      start: Text(title, style: mm.userStyleFor(title, titleStyle)),
      below: subtitle == null
          ? null
          : Text(
              subtitle,
              style: mm.userStyleFor(subtitle, subtitleStyle),
              maxLines: subtitleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
      end: trailing == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: muted, size: MmSize.iconLg),
              child: DefaultTextStyle(style: subtitleStyle, child: trailing),
            ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        selected: selected,
        child: MmSurface(
          onTap: onTap,
          outlined: false,
          color: selected ? colors.primaryContainer : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MmSize.fieldHeight),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MmSpace.s4,
                vertical: MmSpace.s3,
              ),
              child: Row(
                spacing: MmSpace.s4,
                children: [
                  if (leading != null)
                    IconTheme.merge(
                      data: IconThemeData(color: muted, size: MmSize.iconLg),
                      child: leading,
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
