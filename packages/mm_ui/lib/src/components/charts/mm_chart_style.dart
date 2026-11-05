import 'package:flutter/painting.dart';
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

  /// The side of a legend swatch.
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
