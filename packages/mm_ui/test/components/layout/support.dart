import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// [rupees] as the app shows an amount: lakh grouping, the amount style
/// (the Latin face with tabular figures, the Urdu currency word in
/// Nastaliq), and on one line, scaled down rather than wrapped when it does
/// not fit.
Widget moneyText(BuildContext context, int rupees, {bool large = false}) {
  final format = MmFormats.moneyOf(context)
      .copyWith(grouping: DigitGrouping.southAsian);
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      format.format(Money.fromRupees(rupees)),
      style: large ? context.mm.amountLarge : context.mm.amount,
    ),
  );
}
