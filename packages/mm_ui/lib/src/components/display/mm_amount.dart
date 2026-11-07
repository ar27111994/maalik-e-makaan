import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How large an [MmAmount] is set.
enum MmAmountSize {
  /// The Latin body-small size (14 px): amounts in captions and dense rows.
  small,

  /// The amount style (16 px, semibold): amounts in lists, chips and forms.
  regular,

  /// The large amount style (32 px, bold): the one big figure of a screen,
  /// such as the total due.
  large,
}

/// The colour an [MmAmount] is set in. A tone adds emphasis to an amount
/// whose status is said elsewhere (an `MmStatusBadge`, a row's words): it
/// never carries the status alone.
enum MmAmountTone {
  /// Ink: the default for amounts.
  ink,

  /// Muted ink: amounts that are context, not the point ("of Rs 45,000").
  muted,

  /// The paid colour: settled amounts.
  paid,

  /// The overdue colour: amounts past their grace period.
  overdue,

  /// The credit colour: a tenant's advance.
  credit;

  /// The colour of this tone in [colors].
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmAmountTone.ink => colors.ink,
    MmAmountTone.muted => colors.inkMuted,
    MmAmountTone.paid => colors.paid,
    MmAmountTone.overdue => colors.overdue,
    MmAmountTone.credit => colors.credit,
  };
}

/// A rupee amount, formatted the way the landlord chose (Western or
/// lakh/crore grouping, set once with `MmFormats`) in the Latin face with
/// tabular figures, in both languages.
///
/// An amount never breaks inside its number: it stays on one line. It grows
/// with the text size like other text, and when its space is too narrow at
/// a larger text size it scales back down to fit, but never below its size
/// at 100% text, so a figure does not end up smaller than the words around
/// it. A layout that leaves an amount less room than its 100% size needs
/// (two stat tiles side by side on a phone at 200% text, a narrow column)
/// is a layout bug: debug builds report it, as they report an overflow, and
/// release builds keep scaling the amount down rather than clip a digit.
///
/// A negative amount shows a minus sign, unless [creditLabel] is given:
/// then it shows the absolute amount followed by that word ("Rs 5,000
/// credit") in the credit colour, because a tenant's advance should read as
/// credit, not as a minus sign alone.
///
/// Screen readers hear the plain number and the currency ("125000 rupees",
/// "5000 rupees credit"), since grouped figures such as 1,25,000 are read
/// out unreliably.
///
/// Don't use it for an amount the landlord types (use `MmMoneyField`).
///
/// ```dart
/// MmAmount(
///   amount: tenant.balance,
///   size: MmAmountSize.large,
///   creditLabel: l10n.credit,
/// )
/// ```
class MmAmount extends StatelessWidget {
  /// Shows [amount].
  const new({
    required this.amount,
    this.size = MmAmountSize.regular,
    this.tone = MmAmountTone.ink,
    this.creditLabel,
    this.textAlign,
    super.key,
  });

  /// The amount shown.
  final Money amount;

  /// How large the amount is set.
  final MmAmountSize size;

  /// The colour of the amount. A credit shown with [creditLabel] always
  /// takes the credit tone.
  final MmAmountTone tone;

  /// The word that follows a negative amount in place of its minus sign
  /// ("credit", "advance"), from the app's localisations. When null a
  /// negative amount shows a minus sign.
  final String? creditLabel;

  /// Where the amount sits when it is given more width than it needs.
  /// Defaults to the start edge; lists of money align amounts to the end.
  final TextAlign? textAlign;

  /// How a screen reader says [amount], as [MmAmount] says it: the plain
  /// number and the currency ("45000 rupees"), followed by [creditLabel]
  /// for a negative amount when it is given ("5000 rupees credit").
  ///
  /// Use it for the label of a node that shows an amount among other
  /// things, as `MmDetailRow.amount` does.
  static String spokenLabel(
    BuildContext context,
    Money amount, {
    String? creditLabel,
  }) {
    final credit = creditLabel != null && amount.isNegative;
    final spoken = MmFormats.spokenMoney(
      context,
      credit ? amount.abs() : amount,
    );
    return credit ? '$spoken $creditLabel' : spoken;
  }

  @override
  Widget build(BuildContext context) {
    final format = MmFormats.moneyOf(context);
    final creditLabel = this.creditLabel;
    final credit = creditLabel != null && amount.isNegative;
    final shown = credit ? amount.abs() : amount;
    final words = credit ? ' $creditLabel' : '';
    final colors = context.mm.colors;
    // The Latin face, which falls back to Nastaliq for the Urdu currency
    // word and credit label.
    final style = _style(context)
        .copyWith(color: (credit ? MmAmountTone.credit : tone).colorIn(colors));
    // A negative amount comes with a left-to-right mark before its minus
    // sign, so the sign stays before the digits in Urdu.
    final text = '${format.format(shown)}$words';
    final fontSize = style.fontSize!;
    return Semantics(
      container: true,
      label: spokenLabel(context, amount, creditLabel: creditLabel),
      excludeSemantics: true,
      child: _AmountFit(
        alignment: _alignment(textAlign ?? TextAlign.start),
        // The scale at which the amount is at its size at 100% text.
        floor: math.min(
          1,
          fontSize / MediaQuery.textScalerOf(context).scale(fontSize),
        ),
        text: text,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }

  /// The style of [size]: always the Latin face with tabular figures.
  TextStyle _style(BuildContext context) => switch (size) {
    MmAmountSize.large => context.mm.amountLarge,
    MmAmountSize.regular => context.mm.amount,
    MmAmountSize.small => MmSemantics.withUrduFallback(
      MmSemantics.withTabularFigures(MmTypeScale.latinBodySmall),
    ),
  };

  /// Where the amount sits for [align] when it is narrower than its box.
  static AlignmentGeometry _alignment(TextAlign align) => switch (align) {
    TextAlign.start || TextAlign.justify => AlignmentDirectional.centerStart,
    TextAlign.end => AlignmentDirectional.centerEnd,
    TextAlign.center => Alignment.center,
    // The caller asked for a physical side; honour it.
    TextAlign.left =>
      Alignment.centerLeft, // design-lint: allow explicit TextAlign.left
    TextAlign.right =>
      Alignment.centerRight, // design-lint: allow explicit TextAlign.right
  };
}

/// Scales the amount down to fit its width, and reports in debug builds a
/// fit that takes it below [floor].
class _AmountFit extends SingleChildRenderObjectWidget {
  const new({
    required this.alignment,
    required this.floor,
    required this.text,
    required super.child,
  });

  final AlignmentGeometry alignment;

  /// The smallest scale the amount should be drawn at: its size at 100%
  /// text, relative to its size at the current text size.
  final double floor;

  /// The amount as shown, for the report.
  final String text;

  @override
  _RenderAmountFit createRenderObject(BuildContext context) => _RenderAmountFit(
    alignment: alignment,
    textDirection: Directionality.of(context),
    floor: floor,
    text: text,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderAmountFit renderObject) {
    renderObject
      ..alignment = alignment
      ..textDirection = Directionality.of(context)
      ..floor = floor
      ..text = text;
  }
}

class _RenderAmountFit extends RenderFittedBox {
  new({
    required super.alignment,
    required super.textDirection,
    required this._floor,
    required this.text,
  }) : super(fit: BoxFit.scaleDown);

  double get floor => _floor;
  double _floor;
  set floor(double value) {
    if (value == _floor) return;
    _floor = value;
    markNeedsLayout();
  }

  String text;

  /// Whether the squeeze now in place has been reported, so it is reported
  /// once rather than on every layout.
  bool _reported = false;

  /// How far below [floor] a fit may go unreported: a hundredth, too little
  /// to see, so rounding never reports.
  static const _tolerance = 0.99;

  @override
  void performLayout() {
    super.performLayout();
    assert(_debugCheckFloor(), 'the check reports a squeeze, never fails');
  }

  bool _debugCheckFloor() {
    final natural = child!.size;
    final scale = natural.isEmpty
        ? 1.0
        : math
              .min(size.width / natural.width, size.height / natural.height)
              .clamp(0.0, 1.0);
    if (scale >= floor * _tolerance) {
      _reported = false;
      return true;
    }
    if (_reported) return true;
    _reported = true;
    final needed = natural.width * floor;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts([
          ErrorSummary('An MmAmount was squeezed below its size at 100% text.'),
          ErrorDescription(
            'It needs ${needed.toStringAsFixed(1)} px to show "$text" at '
            'its size at 100% text, but has ${size.width.toStringAsFixed(1)} '
            'px, so it was scaled to ${(scale * 100).round()}% of its size at '
            'this text size. An amount scales down to fit at larger text '
            'sizes, but not below its 100% size, so it never ends up smaller '
            'than the words around it. Release builds keep scaling it down '
            'rather than clip a digit.',
          ),
          ErrorHint(
            'Give the amount more room: put stat tiles one to a row at large '
            'text, let the amount move under its label (MmListTile and '
            'MmDetailRow do), or use a smaller MmAmountSize.',
          ),
        ]),
        library: 'mm_ui',
        context: ErrorDescription('during layout of an MmAmount'),
      ),
    );
    return true;
  }
}
