import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_icon_label.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Which way a figure moved since the period it is compared with.
enum MmTrendDirection {
  /// The figure went up.
  up,

  /// The figure went down.
  down,

  /// The figure stayed the same.
  flat;

  /// The icon of this direction. A flat trend points forward along the
  /// reading direction.
  IconData get icon => switch (this) {
    MmTrendDirection.up => MmIcons.trendUp,
    MmTrendDirection.down => MmIcons.trendDown,
    MmTrendDirection.flat => MmIcons.forward,
  };
}

/// How a figure on an [MmStatTile] changed, in words.
///
/// Whether a change is good depends on the figure: collections going up is
/// [favourable], overdue rent going up is not. A favourable trend is set in
/// the paid colour, an unfavourable one in the overdue colour, and both
/// carry an icon and the [label], so colour never carries it alone.
@immutable
final class MmTrend {
  /// A trend in [direction], said by [label].
  const new({
    required this.direction,
    required this.label,
    required this.favourable,
  });

  /// Which way the figure moved.
  final MmTrendDirection direction;

  /// The change in words, from the app's localisations ("Up 12% from
  /// September").
  final String label;

  /// Whether the change is good news for the landlord.
  final bool favourable;

  @override
  bool operator ==(Object other) =>
      other is MmTrend &&
      other.direction == direction &&
      other.label == label &&
      other.favourable == favourable;

  @override
  int get hashCode => Object.hash(direction, label, favourable);

  @override
  String toString() =>
      'MmTrend(${direction.name}, "$label", '
      '${favourable ? 'favourable' : 'unfavourable'})';
}

/// One figure of a dashboard: what it is ([label]), the figure ([value],
/// usually an `MmAmount`), an optional [caption] that gives it context and
/// an optional [trend].
///
/// It is its own flat surface with the card's rule border, so stat tiles can
/// sit in a grid on the page or inside a card without nesting cards. Screen
/// readers read it as one node: label, value, caption and trend. With
/// [onTap] it is a button that opens the figure's detail, with ink, a focus
/// ring and Enter or Space activation.
///
/// Don't use it for a list of records (use `MmListTile`) or for a figure
/// that is part of a receipt (use `MmDetailRow`).
///
/// ```dart
/// MmStatTile(
///   label: l10n.collectedThisMonth,
///   value: MmAmount(amount: collected, size: MmAmountSize.large),
///   caption: l10n.ofDue(formattedDue),
///   trend: MmTrend(
///     direction: MmTrendDirection.up,
///     label: l10n.upFromLastMonth('12%'),
///     favourable: true,
///   ),
///   onTap: openCollections,
/// )
/// ```
class MmStatTile extends StatelessWidget {
  /// Creates a tile showing [value] under [label].
  const new({
    required this.label,
    required this.value,
    this.caption,
    this.trend,
    this.onTap,
    super.key,
  });

  /// What the figure is ("Collected in October").
  final String label;

  /// The figure, usually an `MmAmount` or a [Text]; text without its own
  /// style is set in the headline style.
  final Widget value;

  /// Context for the figure in muted ink ("of Rs 1,25,000 due").
  final String? caption;

  /// How the figure changed since the last period.
  final MmTrend? trend;

  /// Called when the tile is tapped or activated from the keyboard. When
  /// null the tile is static: not a button and not focusable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final caption = this.caption;
    final trend = this.trend;
    final muted = text.bodyMedium!.copyWith(color: colors.inkMuted);
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: MmSurface(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(MmSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MmSpace.s1,
              // Each part is its own node so the tile, which merges them,
              // reads them in this order.
              children: [
                for (final part in [
                  Text(
                    label,
                    style: text.labelLarge!.copyWith(color: colors.inkMuted),
                  ),
                  DefaultTextStyle(style: text.headlineSmall!, child: value),
                  if (caption != null) Text(caption, style: muted),
                  if (trend != null) _TrendLine(trend),
                ])
                  Semantics(container: true, child: part),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A trend's icon and words in the paid or overdue colour.
class _TrendLine extends StatelessWidget {
  const new(this.trend);

  final MmTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final color = trend.favourable ? colors.paid : colors.overdue;
    return MmIconLabel(
      icon: trend.direction.icon,
      label: trend.label,
      iconColor: color,
      iconSize: MmSize.iconMd,
      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
    );
  }
}
