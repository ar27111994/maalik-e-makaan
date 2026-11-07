import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One line of an [MmReceipt] below its amount: a label and its value
/// ("Tenant ... Ali Raza").
@immutable
final class MmReceiptRow {
  /// Describes a row showing [value] for [label].
  const new({required this.label, required this.value, this.semanticValue});

  /// What the value is ("Tenant", "Period"), from the app's localisations.
  final String label;

  /// The value ("Ali Raza", "October 2026", "Rs 45,000"). It wraps when it
  /// does not fit: join the parts of an amount with a no-break space
  /// (`Rs\u00A045,000`) so a currency never ends a line apart from its
  /// number.
  final String value;

  /// How a screen reader says [value] when that differs from how it looks:
  /// a grouped amount as "45000 rupees", an abbreviated date in words.
  final String? semanticValue;

  @override
  bool operator ==(Object other) =>
      other is MmReceiptRow &&
      other.label == label &&
      other.value == value &&
      other.semanticValue == semanticValue;

  @override
  int get hashCode => Object.hash(label, value, semanticValue);
}

/// The raseed: a rent or bill receipt on paper with a perforated top edge,
/// the issuer's name, a brass seal carrying the receipt number, the amount
/// received, its details and an optional footer.
///
/// The receipt is flat paper (no shadow, straight edges) so the same layout
/// prints to PDF. The amount is formatted with `MmFormats` in the Latin
/// face with tabular figures and never breaks inside its number: when its
/// space is narrow it scales down. Rows reflow: a value that does not fit
/// beside its label moves under it.
///
/// A cancelled receipt keeps its content for the record: set [voidedLabel]
/// ("VOID: cancelled on 12 Oct 2026") to show it on a banner in the overdue
/// colours with an icon and the words, and to strike the amount through.
///
/// Screen readers hear the issuer (as a header), the receipt number, the
/// voided state when there is one, the amount ("Amount received, 45000
/// rupees"), each row and the footer, in that order: the order they are
/// shown in, so a cancelled receipt is known to be void before its amount
/// is heard.
///
/// Use it to show or share a receipt for a payment. Don't use it for a
/// list of payments (use list tiles) or for a payment still being entered
/// (use a form). Brass appears once per screen: don't show a receipt and a
/// nameplate together.
///
/// ```dart
/// MmReceipt(
///   issuer: landlord.name,
///   numberLabel: l10n.receiptNumber,
///   receiptNumber: receipt.number,
///   amountLabel: l10n.amountReceived,
///   amount: receipt.amount,
///   rows: [
///     MmReceiptRow(label: l10n.tenant, value: tenant.name),
///     MmReceiptRow(label: l10n.period, value: months.format(receipt.period)),
///   ],
///   footer: l10n.receiptFooter,
/// )
/// ```
class MmReceipt extends StatelessWidget {
  /// Creates a receipt numbered [receiptNumber] from [issuer] for [amount].
  const new({
    required this.issuer,
    required this.numberLabel,
    required this.receiptNumber,
    required this.amountLabel,
    required this.amount,
    required this.rows,
    this.footer,
    this.voidedLabel,
    super.key,
  });

  /// Who issued the receipt: the landlord's or the business's name.
  final String issuer;

  /// The label above the receipt number on the seal ("Receipt no."), from
  /// the app's localisations.
  final String numberLabel;

  /// The receipt number ("R-2026-0142").
  final String receiptNumber;

  /// What the amount is ("Amount received"), from the app's localisations.
  final String amountLabel;

  /// The amount received.
  final Money amount;

  /// The details under the amount: tenant, property, period, method.
  final List<MmReceiptRow> rows;

  /// An optional closing note in small print ("Thank you. Keep this
  /// receipt for your records.").
  final String? footer;

  /// When set, the receipt is void: this text ("VOID: cancelled on 12 Oct
  /// 2026") is shown on an overdue banner and the amount is struck through.
  final String? voidedLabel;

  /// The radius of the notches along the perforated top edge.
  static const double notchRadius = MmSpace.s1;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final format = MmFormats.moneyOf(context);
    final strings = MmLocalizations.of(context);
    final footer = this.footer;
    final voidedLabel = this.voidedLabel;

    // Every part carries its place in the reading order, which follows the
    // order the parts are made in: the issuer, the number, the voided
    // state (so a receipt is known to be void before its amount is heard),
    // the amount, the rows and the footer.
    var order = 0;
    Widget part(Widget child, {String? label, bool header = false}) =>
        Semantics(
          container: true,
          sortKey: OrdinalSortKey((order++).toDouble()),
          header: header,
          label: label,
          excludeSemantics: label != null,
          child: child,
        );

    final issuerPart = part(
      MmUserText(issuer, style: text.titleMedium!.copyWith(color: colors.ink)),
      header: true,
    );
    final sealPart = part(
      _Seal(numberLabel: numberLabel, receiptNumber: receiptNumber),
      label: '$numberLabel $receiptNumber',
    );
    final voidPart = voidedLabel == null
        ? null
        : part(_VoidBanner(label: voidedLabel), label: voidedLabel);
    final spokenAmount = MmFormats.spokenMoney(context, amount, format: format);
    final amountPart = part(
      _AmountBlock(
        label: amountLabel,
        amount: amount,
        format: format,
        voided: voidedLabel != null,
      ),
      label: strings.joined([amountLabel, spokenAmount]),
    );
    final rowParts = [
      for (final row in rows)
        part(
          _Row(row: row),
          label: strings.joined([row.label, row.semanticValue ?? row.value]),
        ),
    ];
    final footerPart = footer == null
        ? null
        : part(
            MmScriptText(
              footer,
              style: text.bodySmall!.copyWith(color: colors.inkMuted),
            ),
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: CustomPaint(
        painter: _PaperPainter(
          paper: colors.surface,
          edge: colors.rule,
          notchRadius: notchRadius,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MmSpace.s4,
            MmSpace.s4 + notchRadius,
            MmSpace.s4,
            MmSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmReflow(
                start: issuerPart,
                end: sealPart,
                alignment: MmReflowAlignment.top,
                stackedAtEnd: true,
              ),
              if (voidPart != null) ...[
                const SizedBox(height: MmSpace.s3),
                voidPart,
              ],
              const SizedBox(height: MmSpace.s4),
              amountPart,
              if (rowParts.isNotEmpty) ...[
                const SizedBox(height: MmSpace.s3),
                _DashedRule(color: colors.rule),
                const SizedBox(height: MmSpace.s2),
                ...rowParts,
              ],
              if (footerPart != null) ...[
                const SizedBox(height: MmSpace.s3),
                _DashedRule(color: colors.rule),
                const SizedBox(height: MmSpace.s3),
                footerPart,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The brass seal at the top end of a receipt, carrying its number.
class _Seal extends StatelessWidget {
  const new({required this.numberLabel, required this.receiptNumber});

  final String numberLabel;
  final String receiptNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final on = colors.onBrassContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brassContainer,
        border: Border.all(color: colors.brass, width: MmSize.frame),
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.sm)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s3,
          vertical: MmSpace.s1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numberLabel,
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: on),
            ),
            MmUserText(
              receiptNumber,
              textAlign: TextAlign.center,
              style: MmSemantics.withTabularFigures(
                text.labelLarge!.copyWith(color: on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The amount label and the amount, struck through when the receipt is
/// void.
class _AmountBlock extends StatelessWidget {
  const new({
    required this.label,
    required this.amount,
    required this.format,
    required this.voided,
  });

  final String label;
  final Money amount;
  final MoneyFormat format;
  final bool voided;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    // The Latin face, which falls back to Nastaliq for the Urdu currency
    // word.
    final style = mm.amountLarge.copyWith(
      decoration: voided ? TextDecoration.lineThrough : null,
      decorationColor: colors.overdue,
      decorationThickness: 2,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyMedium!.copyWith(color: colors.inkMuted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            // A negative amount comes with a left-to-right mark before its
            // minus sign, so the sign stays before the digits in Urdu.
            format.format(amount),
            style: style,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

/// A label and its value on a receipt.
class _Row extends StatelessWidget {
  const new({required this.row});

  final MmReceiptRow row;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s1),
      child: MmReflow(
        alignment: MmReflowAlignment.baseline,
        start: Text(
          row.label,
          style: text.bodyMedium!.copyWith(color: colors.inkMuted),
        ),
        end: MmUserText(
          row.value,
          style: MmSemantics.withTabularFigures(
            text.bodyLarge!.copyWith(color: colors.ink),
          ),
        ),
      ),
    );
  }
}

/// The banner of a void receipt: an icon and the words on the overdue
/// container, framed in the overdue colour like a stamp.
class _VoidBanner extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final on = colors.onOverdueContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.overdueContainer,
        border: Border.all(color: colors.overdue, width: MmSize.frame),
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s3,
          vertical: MmSpace.s2,
        ),
        child: MmIconLabel(
          icon: MmIcons.error,
          label: label,
          style: text.labelLarge!.copyWith(color: on),
          iconColor: on,
        ),
      ),
    );
  }
}

/// A dashed tear line across the receipt.
class _DashedRule extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MmSize.hairline,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color: color)),
  );
}

/// Paints evenly spaced dashes across its width, starting and ending with
/// a dash, so the rule reads the same in both directions.
class _DashPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  static const double _dash = MmSpace.s1;
  static const double _gap = MmSpace.s1;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_dash + _gap)).floor();
    if (count < 2) return;
    final gap = (size.width - count * _dash) / (count - 1);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final left = i * (_dash + gap);
      canvas.drawRect(Rect.fromLTWH(left, 0, _dash, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}

/// Paints the receipt's paper: a flat sheet with straight edges whose top
/// edge is perforated by a row of semicircular notches, outlined with a
/// hairline rule.
class _PaperPainter extends CustomPainter {
  const new({
    required this.paper,
    required this.edge,
    required this.notchRadius,
  });

  final Color paper;
  final Color edge;
  final double notchRadius;

  /// The paper's outline in [size], notches included.
  Path _outline(Size size) {
    final diameter = notchRadius * 2;
    final pitch = diameter * 2;
    final count = ((size.width - diameter) / pitch).floor();
    final span = count * pitch - diameter;
    final first = (size.width - span) / 2;
    final path = Path()..moveTo(0, 0);
    for (var i = 0; i < count; i++) {
      final centre = first + i * pitch + notchRadius;
      path
        ..lineTo(centre - notchRadius, 0)
        ..arcToPoint(
          Offset(centre + notchRadius, 0),
          radius: Radius.circular(notchRadius),
          clockwise: false,
        );
    }
    return path
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _outline(size);
    canvas
      ..drawPath(outline, Paint()..color = paper)
      ..drawPath(
        outline,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = MmSize.hairline,
      );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) =>
      paper != oldDelegate.paper ||
      edge != oldDelegate.edge ||
      notchRadius != oldDelegate.notchRadius;
}
