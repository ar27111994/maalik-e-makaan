import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A legend's key: a small square drawn with the same [mark] as what it
/// names, so the legend matches its marks by fill, outline and hatching as
/// well as by colour. It grows with the text up to [maxScale]. It is
/// decoration: the word beside it says what it is, so it adds no semantics.
///
/// Internal to the charts family.
class MmChartSwatch extends StatelessWidget {
  /// A swatch of [mark].
  const new(this.mark, {super.key});

  /// The mark the swatch shows.
  final MmChartMark mark;

  /// The corner radius of a swatch: half a chip's, so the small square
  /// still reads as a square.
  static const double radius = MmRadius.xs / 2;

  /// The most a swatch grows with the text size, like an icon beside words
  /// (`MmIconLabel.maxIconScale`): enough to stay easy to match with its
  /// mark at large text, without crowding the words it keys.
  static const double maxScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: maxScale)
        .scale(MmChartMetrics.swatch);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: MmChartMarkPainter(mark, radius: radius),
      ),
    );
  }
}
