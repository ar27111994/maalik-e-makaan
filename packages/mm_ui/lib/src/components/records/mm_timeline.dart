import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/records/mm_record_style.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The colour of an [MmTimelineItem]'s marker. The tone echoes what the
/// item's words say ("Payment received", "Rent overdue"); it never carries
/// a status alone.
enum MmTimelineTone {
  /// No particular state: a tenant moved in, a note was added.
  neutral,

  /// Cobalt: an event the landlord started, such as a lease signed.
  primary,

  /// The paid colour: a payment received, a bill settled.
  paid,

  /// The due-soon colour: rent or a bill falling due.
  dueSoon,

  /// The overdue colour: rent or a bill past its grace period.
  overdue,

  /// The credit colour: an advance or a refund.
  credit;

  /// The strong colour of this tone in [colors]: a dot, or the ring of an
  /// icon marker.
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmTimelineTone.neutral => colors.outline,
    MmTimelineTone.primary => colors.primary,
    MmTimelineTone.paid => colors.paid,
    MmTimelineTone.dueSoon => colors.dueSoon,
    MmTimelineTone.overdue => colors.overdue,
    MmTimelineTone.credit => colors.credit,
  };

  /// The fill of an icon marker in [colors].
  Color containerIn(MmColorTokens colors) => switch (this) {
    MmTimelineTone.neutral => colors.surfaceSunken,
    MmTimelineTone.primary => colors.primaryContainer,
    MmTimelineTone.paid => colors.paidContainer,
    MmTimelineTone.dueSoon => colors.dueSoonContainer,
    MmTimelineTone.overdue => colors.overdueContainer,
    MmTimelineTone.credit => colors.creditContainer,
  };

  /// The colour of the icon on [containerIn] in [colors].
  Color onContainerIn(MmColorTokens colors) => switch (this) {
    MmTimelineTone.neutral => colors.ink,
    MmTimelineTone.primary => colors.onPrimaryContainer,
    MmTimelineTone.paid => colors.onPaidContainer,
    MmTimelineTone.dueSoon => colors.onDueSoonContainer,
    MmTimelineTone.overdue => colors.onOverdueContainer,
    MmTimelineTone.credit => colors.onCreditContainer,
  };
}

/// One event of an [MmTimeline]: when it happened, what happened and,
/// optionally, a detail line.
@immutable
final class MmTimelineItem {
  /// Describes an event on [dateLabel] titled [title].
  const new({
    required this.dateLabel,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = MmTimelineTone.neutral,
  });

  /// When it happened, formatted by the app ("5 Oct 2026"), shown in muted
  /// caption above the title.
  final String dateLabel;

  /// What happened ("Payment received").
  final String title;

  /// An optional detail ("Rs 45,000 by bank transfer").
  final String? subtitle;

  /// An icon that says what kind of event it is (a payment, a lease). When
  /// null the marker is a dot.
  final IconData? icon;

  /// The colour of the marker.
  final MmTimelineTone tone;

  @override
  bool operator ==(Object other) =>
      other is MmTimelineItem &&
      other.dateLabel == dateLabel &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.icon == icon &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(dateLabel, title, subtitle, icon, tone);
}

/// A record's history as a vertical timeline: a rail on the start side
/// with a dot or an icon for each event, and beside it the date in muted
/// caption, the title and an optional detail line.
///
/// Items are shown in the order given (usually newest first). Long titles
/// and large text wrap; the rail grows with them. Each item is one node
/// for screen readers, reading the date, the title and the detail, and the
/// timeline is announced as a list.
///
/// Use it for the history of one tenant, lease or property: rent falling
/// due, payments, renewals, notices. Don't use it for a list the landlord
/// acts on (use list tiles) or for a ledger of amounts (use a table).
///
/// ```dart
/// MmTimeline(
///   items: [
///     MmTimelineItem(
///       dateLabel: dates.format(payment.date),
///       title: l10n.paymentReceived,
///       subtitle: format.format(payment.amount),
///       icon: MmIcons.payment,
///       tone: MmTimelineTone.paid,
///     ),
///   ],
/// )
/// ```
class MmTimeline extends StatelessWidget {
  /// Creates a timeline of [items].
  const new({required this.items, super.key});

  /// The events, in the order they are shown.
  final List<MmTimelineItem> items;

  /// The width of the marker column on the start side.
  static const double markerColumn = MmSpace.s8;

  /// The diameter of an icon marker.
  static const double iconMarker = MmSpace.s8;

  /// The diameter of a dot marker.
  static const double dotMarker = MmSpace.s3;

  /// The thickness of the rail.
  static const double railWidth = MmSpace.sHalf;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.list,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed)
            _TimelineEntry(
              item: item,
              first: index == 0,
              last: index == items.length - 1,
            ),
        ],
      ),
    );
  }
}

/// One item of a timeline with its marker and its stretch of the rail.
class _TimelineEntry extends StatelessWidget {
  const new({required this.item, required this.first, required this.last});

  final MmTimelineItem item;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final subtitle = item.subtitle;
    final icon = item.icon;
    final dateStyle = text.bodySmall!.copyWith(color: colors.inkMuted);

    // The marker is centred on the date line; whichever of the two is
    // smaller moves down to meet the other's centre.
    final dateLine =
        MediaQuery.textScalerOf(context).scale(dateStyle.fontSize!) *
        dateStyle.height!;
    final marker = icon == null ? MmTimeline.dotMarker : MmTimeline.iconMarker;
    final markerTop = math.max(0, dateLine - marker) / 2;
    final contentTop = math.max(0, marker - dateLine) / 2;
    final markerBottom = markerTop + marker;
    const railStart = (MmTimeline.markerColumn - MmTimeline.railWidth) / 2;
    final rail = ColoredBox(color: colors.rule);

    return Semantics(
      container: true,
      role: SemanticsRole.listItem,
      label: [item.dateLabel, item.title, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Stack(
        children: [
          if (!first)
            PositionedDirectional(
              start: railStart,
              width: MmTimeline.railWidth,
              top: 0,
              height: markerTop,
              child: rail,
            ),
          if (!last)
            PositionedDirectional(
              start: railStart,
              width: MmTimeline.railWidth,
              top: markerBottom,
              bottom: 0,
              child: rail,
            ),
          PositionedDirectional(
            start: (MmTimeline.markerColumn - marker) / 2,
            top: markerTop,
            child: _Marker(tone: item.tone, icon: icon, size: marker),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: MmTimeline.markerColumn + MmSpace.s3,
              top: contentTop,
              bottom: last ? 0 : MmSpace.s4,
            ),
            child: ConstrainedBox(
              // The rail below the marker never has a negative length.
              constraints: BoxConstraints(minHeight: markerBottom - contentTop),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateLabel,
                    style: mm.dataStyleFor(item.dateLabel, dateStyle),
                  ),
                  Text(
                    item.title,
                    style: mm.dataStyleFor(
                      item.title,
                      text.titleMedium!.copyWith(color: colors.ink),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: mm.dataStyleFor(
                        subtitle,
                        text.bodyMedium!.copyWith(color: colors.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A timeline marker: a dot, or an icon in a ringed circle.
class _Marker extends StatelessWidget {
  const new({required this.tone, required this.icon, required this.size});

  final MmTimelineTone tone;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final icon = this.icon;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: icon == null
            ? BoxDecoration(color: tone.colorIn(colors), shape: BoxShape.circle)
            : BoxDecoration(
                color: tone.containerIn(colors),
                shape: BoxShape.circle,
                border: Border.all(color: tone.colorIn(colors)),
              ),
        child: icon == null
            ? null
            : Icon(
                icon,
                size: MmSize.iconSm,
                color: tone.onContainerIn(colors),
              ),
      ),
    );
  }
}
