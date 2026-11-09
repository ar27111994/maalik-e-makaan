import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
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

  /// The icon of this direction. Every trend arrow points along the
  /// reading direction, as time runs from the start edge, so it mirrors in
  /// Urdu.
  IconData get icon => switch (this) {
    MmTrendDirection.up => MmIcons.trendUp,
    MmTrendDirection.down => MmIcons.trendDown,
    MmTrendDirection.flat => MmIcons.trendFlat,
  };
}

/// How a figure on an [MmStatTile] changed, in words.
///
/// Whether a change is good depends on the figure: collections going up is
/// [favourable], overdue rent going up is not, and no change is neither. A
/// favourable trend is set in the paid colour, an unfavourable one in the
/// overdue colour and a neutral one in muted ink, and each carries an icon
/// and the [label], so colour never carries it alone.
@immutable
final class MmTrend {
  /// A trend in [direction], said by [label].
  const new({required this.direction, required this.label, this.favourable});

  /// Which way the figure moved.
  final MmTrendDirection direction;

  /// The change in words, from the app's localisations ("Up 12% from
  /// September").
  final String label;

  /// Whether the change is good news for the landlord: true or false, or
  /// null when it is neither (the figure stayed the same).
  final bool? favourable;

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
      '${switch (favourable) {
        true => 'favourable',
        false => 'unfavourable',
        null => 'neutral',
      }})';
}

/// One figure of a dashboard: what it is ([label]), the figure ([value],
/// usually an `MmAmount`), an optional [caption] that gives it context and
/// an optional [trend].
///
/// On the page it is its own flat surface with the card's border; inside an
/// `MmCard` it drops that border and becomes a region of the card, so it
/// never reads as a card inside a card. Screen readers read it as one node:
/// label, value, caption and trend. With [onTap] it is a button that opens
/// the figure's detail, with the outline colour for its border, ink, a
/// focus ring and Enter or Space activation; like any button it holds no
/// other controls.
///
/// Its words wrap and its figure scales down to fit, but a tile needs room:
/// at 200% text two tiles side by side on a phone break their words
/// mid-letter and shrink the figure below its 100% size (which debug builds
/// report). Lay tiles out with `MmResponsiveGrid`, scaling its
/// `minItemWidth` with the text, so that large text gets one tile to a row
/// and the page's one large figure gets the width it needs:
///
/// ```dart
/// MmResponsiveGrid(
///   minItemWidth: MediaQuery.textScalerOf(context).scale(200),
///   children: [
///     MmStatTile(
///       label: l10n.collectedThisMonth,
///       value: MmAmount(amount: collected, size: MmAmountSize.large),
///       caption: Text(l10n.ofDue(formattedDue)),
///       trend: MmTrend(
///         direction: MmTrendDirection.up,
///         label: l10n.upFromLastMonth('12%'),
///         favourable: true,
///       ),
///       onTap: openCollections,
///     ),
///     MmStatTile(
///       label: l10n.occupiedUnits,
///       value: Text(l10n.unitsOf(12, 14)),
///     ),
///   ],
/// )
/// ```
///
/// Don't use it for a list of records (use `MmListTile`) or for a figure
/// that is part of a receipt (use `MmDetailRow`).
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

  /// Context for the figure ("of Rs 1,25,000 due"), usually a [Text];
  /// text without its own style is set in muted ink. An amount in it can
  /// be an `MmAmount` between the words of a [Wrap], so it never breaks
  /// inside its number and is read as rupees:
  ///
  /// ```dart
  /// Wrap(
  ///   spacing: MediaQuery.textScalerOf(context).scale(MmSpace.s1),
  ///   crossAxisAlignment: WrapCrossAlignment.center,
  ///   children: [
  ///     Text(l10n.of),
  ///     MmAmount(
  ///       amount: due,
  ///       size: MmAmountSize.small,
  ///       tone: MmAmountTone.muted,
  ///     ),
  ///     Text(l10n.due),
  ///   ],
  /// )
  /// ```
  ///
  /// (Not a `WidgetSpan` in a `Text.rich`: the tile reads its parts as one
  /// node, and text around a widget span is lost from that node.)
  final Widget? caption;

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
          owner: 'MmStatTile',
          onTap: onTap,
          outlined: !MmCardScope.isIn(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(MmSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MmSpace.s1,
              // Each part is its own node, and so is each piece of a part
              // (the words and the amount of a caption), so the tile, which
              // merges them, reads them in this order.
              children: [
                for (final part in [
                  Text(
                    label,
                    style: text.labelLarge!.copyWith(color: colors.inkMuted),
                  ),
                  DefaultTextStyle(style: text.headlineSmall!, child: value),
                  if (caption != null)
                    DefaultTextStyle(style: muted, child: caption),
                  if (trend != null) _TrendLine(trend),
                ])
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: part,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A trend's icon and words in the paid, overdue or muted colour.
class _TrendLine extends StatelessWidget {
  const new(this.trend);

  final MmTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final color = switch (trend.favourable) {
      true => colors.paid,
      false => colors.overdue,
      null => colors.inkMuted,
    };
    return MmIconLabel(
      icon: trend.direction.icon,
      label: trend.label,
      iconColor: color,
      iconSize: MmSize.iconMd,
      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
    );
  }
}
