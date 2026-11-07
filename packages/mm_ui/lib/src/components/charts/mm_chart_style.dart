import 'package:flutter/painting.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Measures shared by the charts.
///
/// Internal to the charts family.
abstract final class MmChartMetrics {
  /// The surface-coloured gap between touching marks: the segments of a
  /// proportion bar and the bars of one group. Marks separate by this gap,
  /// never by a border drawn around them.
  static const double gap = MmSpace.sHalf;

  /// The side of a legend swatch at 100% text: a chart-specific size with
  /// no token, a little smaller than a small icon so it keys the words
  /// beside it without outweighing them.
  static const double swatch = 12;
}

/// Text styles for the charts.
///
/// Internal to the charts family.
extension MmChartText on MmSemantics {
  /// [style] in the Latin face with tabular figures, for amounts and
  /// percentages, in both languages, so figures line up and stay
  /// unambiguous. The Urdu currency and unit words ("روپے", "لاکھ") fall
  /// back to Nastaliq.
  TextStyle figures(TextStyle style, Color color) =>
      MmSemantics.withUrduFallback(
        style.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

/// [text] with the grouping commas between digits removed ("Rs 1,25,000"
/// becomes "Rs 125000"), so a screen reader says the number as one figure.
String mmUngrouped(String text) =>
    text.replaceAllMapped(_groupedDigits, (match) => match[1]!);

final RegExp _groupedDigits = RegExp(r'(?<=\d),(\d)');

/// The direction [text] reads in on its own: right to left when it has an
/// Arabic-script letter (Urdu), left to right otherwise. Latin-script data
/// and plain figures ("0300 1234567", "Shop 4") keep their order in the
/// Urdu UI, where the paragraph's own direction would reorder their runs.
TextDirection mmDirectionOf(String text) =>
    MmSemantics.hasArabicScript(text) ? TextDirection.rtl : TextDirection.ltr;

/// The words [format] writes around an amount of one [unit] in compact
/// notation ("Rs" for a rupee, "Rs lakh" for a lakh, "لاکھ روپے" in Urdu),
/// without the number:
/// the unit a column or an axis of plain figures is in, said once in its
/// header or caption. Empty when [format] writes no currency and [unit] is
/// a rupee.
String mmUnitWords(MoneyFormat format, Money unit) {
  final whole = format.copyWith(notation: MoneyNotation.compact).format(unit);
  final one = format
      .copyWith(notation: MoneyNotation.standard)
      .formatNumber(const Money.fromRupees(1));
  return whole.replaceFirst(one, '').trim().replaceAll(_spaces, ' ');
}

final RegExp _spaces = RegExp(r'\s+');
