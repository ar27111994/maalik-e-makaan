import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:mm_ui/src/components/feedback/mm_skeleton.dart';
import 'package:mm_ui/src/components/feedback/mm_skeleton_pulse.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The placeholder for a list while it loads: [itemCount] skeleton rows
/// shaped like list tiles (an avatar, a title and a subtitle line, an
/// amount at the end), grouped on a card and separated by rules, as a
/// loaded list of `MmListTile`s is.
///
/// All rows pulse together, and stay still when the platform asks for
/// reduced motion. Screen readers meet one node that says "Loading" (from
/// `MmLocalizations`) and announce it when it appears. Given a bounded
/// height, rows that do not fit are cut off at the bottom edge, as a
/// list's would be, rather than overflowing.
///
/// Show it in place of the list while the first page loads; replace it
/// with the list, an `MmEmptyState` or an `MmErrorState` when loading ends.
/// Use skeletons, not spinners, for lists.
///
/// ```dart
/// tenants.when(
///   loading: () => const MmSkeletonList(),
///   data: (tenants) => TenantList(tenants),
///   error: (error, _) => MmErrorState(message: l10n.loadFailed),
/// )
/// ```
class MmSkeletonList extends StatelessWidget {
  /// Creates a skeleton list of [itemCount] rows.
  const new({this.itemCount = 6, super.key})
    : assert(itemCount > 0, 'A skeleton list needs at least one row.');

  /// How many rows the placeholder shows.
  final int itemCount;

  /// The diameter of a row's avatar: the default avatar's, [MmSize.avatar].
  static const double avatarSize = MmSize.avatar;

  /// The width of a row's amount at the end.
  static const double amountWidth = MmSpace.s16;

  /// The share of the text column the title and subtitle lines take, by
  /// row, so the rows look like different tenants rather than copies.
  static const List<(double, double)> lineShares = [
    (0.7, 0.45),
    (0.55, 0.6),
    (0.8, 0.4),
    (0.6, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: MmLocalizations.of(context).loading,
      child: ExcludeSemantics(
        child: MmSkeletonPulse(
          child: ClipRect(
            child: OverflowBox(
              maxHeight: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              alignment: AlignmentDirectional.topCenter,
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < itemCount; row++) ...[
                      if (row > 0) const Divider(),
                      _Row(shares: lineShares[row % lineShares.length]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One skeleton row, laid out as `MmListTile` lays out a tenant.
class _Row extends StatelessWidget {
  const new({required this.shares});

  /// The shares of the width the title and subtitle lines take.
  final (double, double) shares;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = shares;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MmSpace.s4,
        vertical: MmSpace.s3,
      ),
      child: Row(
        spacing: MmSpace.s3,
        children: [
          const MmSkeleton.circle(diameter: MmSkeletonList.avatarSize),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: title,
                  alignment: AlignmentDirectional.centerStart,
                  child: const MmSkeleton.text(),
                ),
                FractionallySizedBox(
                  widthFactor: subtitle,
                  alignment: AlignmentDirectional.centerStart,
                  child: const MmSkeleton.text(),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: MmSkeletonList.amountWidth,
            child: MmSkeleton.text(),
          ),
        ],
      ),
    );
  }
}
