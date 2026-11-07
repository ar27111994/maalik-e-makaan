import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/foundation/mm_tone.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The colour of an [MmTimelineItem]'s marker. The tone echoes what the
/// item's words say ("Payment received", "Rent overdue"); it never carries
/// a status alone.
enum MmTimelineTone {
  /// No particular state: a tenant moved in, a note was added.
  neutral(MmTone.neutral),

  /// Cobalt: an event the landlord started, such as a lease signed.
  primary(MmTone.primary),

  /// The paid colour: a payment received, a bill settled.
  paid(MmTone.paid),

  /// The due-soon colour: rent or a bill falling due.
  dueSoon(MmTone.dueSoon),

  /// The overdue colour: rent or a bill past its grace period.
  overdue(MmTone.overdue),

  /// The credit colour: an advance or a refund.
  credit(MmTone.credit);

  new(this._tone);

  /// The design system's colour family this tone takes its roles from.
  final MmTone _tone;

  /// The strong colour of this tone in [colors]: a dot, or the ring of an
  /// icon marker.
  Color colorIn(MmColorTokens colors) => _tone.colorIn(colors);

  /// The fill of an icon marker in [colors].
  Color containerIn(MmColorTokens colors) => _tone.containerIn(colors);

  /// The colour of the icon on [containerIn] in [colors].
  Color onContainerIn(MmColorTokens colors) => _tone.onContainerIn(colors);
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
    this.semanticLabel,
  });

  /// When it happened, formatted by the app ("5 Oct 2026"), shown in muted
  /// caption above the title.
  final String dateLabel;

  /// What happened ("Payment received"). It wraps when it does not fit:
  /// join the parts of an amount with a no-break space (`Rs\u00A045,000`)
  /// so a currency never ends a line apart from its number.
  final String title;

  /// An optional detail ("Rs 45,000 by bank transfer"). It wraps like
  /// [title]: join the parts of an amount with a no-break space.
  final String? subtitle;

  /// An icon that says what kind of event it is (a payment, a lease). When
  /// null the marker is a dot.
  final IconData? icon;

  /// The colour of the marker.
  final MmTimelineTone tone;

  /// What a screen reader says for the item instead of its date, title and
  /// detail, when that differs from how they look. Grouped figures such as
  /// 1,25,000 are read out unreliably, so give amounts as plain numbers
  /// ("7 Oct 2026, Payment received, 45000 rupees by bank transfer", from
  /// `MmFormats.spokenMoney`). When null, the date, the title and the detail
  /// are read, in that order.
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is MmTimelineItem &&
      other.dateLabel == dateLabel &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.icon == icon &&
      other.tone == tone &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode =>
      Object.hash(dateLabel, title, subtitle, icon, tone, semanticLabel);
}

/// A record's history as a vertical timeline: a rail on the start side
/// with a dot or an icon for each event, and beside it the date in muted
/// caption, the title and an optional detail line.
///
/// Items are shown in the order given (usually newest first). Long titles
/// and large text wrap; the rail grows with them, and the markers grow
/// with the text up to half as large again. Each item is one node for
/// screen readers, reading the date, the title and the detail (or the
/// item's `semanticLabel`), and the timeline is announced as a list.
///
/// Use it for the history of one tenant, lease or property: rent falling
/// due, payments, renewals, notices. Don't use it for a list the landlord
/// acts on (use list tiles) or for a ledger of amounts (use a table).
///
/// ```dart
/// final date = dates.format(payment.date);
/// MmTimeline(
///   items: [
///     MmTimelineItem(
///       dateLabel: date,
///       title: l10n.paymentReceived,
///       subtitle: format.format(payment.amount),
///       semanticLabel: [
///         date,
///         l10n.paymentReceived,
///         MmFormats.spokenMoney(context, payment.amount),
///       ].join(', '),
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

  /// The width of the marker column on the start side at 100% text size.
  /// It grows with the text, as the markers do.
  static const double markerColumn = MmSpace.s8;

  /// The diameter of an icon marker at 100% text size.
  static const double iconMarker = MmSpace.s8;

  /// The diameter of a dot marker at 100% text size.
  static const double dotMarker = MmSpace.s3;

  /// The thickness of the rail.
  static const double railWidth = MmSize.stroke;

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
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final subtitle = item.subtitle;
    final icon = item.icon;
    final dateStyle = text.bodySmall!.copyWith(color: colors.inkMuted);

    // The markers grow with the text as icons beside words do, up to half
    // as large again, so a marker still reads beside 200% text.
    final grow = MmIconLabel.scaledSize(context, MmSize.iconSm) / MmSize.iconSm;
    final column = MmTimeline.markerColumn * grow;
    final marker =
        (icon == null ? MmTimeline.dotMarker : MmTimeline.iconMarker) * grow;

    // The marker is centred on the date line; whichever of the two is
    // smaller moves down to meet the other's centre.
    final dateLine =
        MediaQuery.textScalerOf(context).scale(dateStyle.fontSize!) *
        dateStyle.height!;
    final markerTop = math.max(0, dateLine - marker) / 2;
    final contentTop = math.max(0, marker - dateLine) / 2;
    final markerBottom = markerTop + marker;
    final railStart = (column - MmTimeline.railWidth) / 2;
    final rail = ColoredBox(color: colors.rule);

    return Semantics(
      container: true,
      role: SemanticsRole.listItem,
      label:
          item.semanticLabel ??
          MmLocalizations.of(context)
              .joined([item.dateLabel, item.title, ?subtitle]),
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
            start: (column - marker) / 2,
            top: markerTop,
            child: _Marker(
              tone: item.tone,
              icon: icon,
              size: marker,
              iconSize: MmSize.iconSm * grow,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: column + MmSpace.s3,
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
                  MmScriptText(item.dateLabel, style: dateStyle),
                  MmScriptText(
                    item.title,
                    style: text.titleMedium!.copyWith(color: colors.ink),
                  ),
                  if (subtitle != null)
                    MmScriptText(
                      subtitle,
                      style: text.bodyMedium!.copyWith(color: colors.inkMuted),
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
  const new({
    required this.tone,
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final MmTimelineTone tone;
  final IconData? icon;
  final double size;
  final double iconSize;

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
            : Icon(icon, size: iconSize, color: tone.onContainerIn(colors)),
      ),
    );
  }
}
