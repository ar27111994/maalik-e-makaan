import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The icon beside a control's label (a button's, an extended floating
/// action button's, a segment's). It grows with the label's text, at most
/// [MmIconLabel.maxIconScale] times, as every icon beside words in mm_ui
/// does: large enough to keep its place beside 200% text, never so large
/// that it crowds the words.
///
/// Its size at 100% text is the ambient [IconTheme]'s, which the control's
/// style sets; it grows as the ambient [DefaultTextStyle] grows.
///
/// Internal to the actions family.
class MmActionIcon extends StatelessWidget {
  /// Shows [icon] at the ambient icon size, grown with the ambient text.
  const new(this.icon, {super.key});

  /// The icon.
  final IconData icon;

  /// The ambient icon size, grown as the ambient text grows.
  static double sizeIn(BuildContext context) => grown(
    IconTheme.of(context).size ?? MmSize.iconMd,
    textScaler: MediaQuery.textScalerOf(context),
    fontSize: DefaultTextStyle.of(context).style.fontSize ?? kDefaultFontSize,
  );

  /// [size] grown as text of [fontSize] grows under [textScaler], at most
  /// [MmIconLabel.maxIconScale] times.
  static double grown(
    double size, {
    required TextScaler textScaler,
    required double fontSize,
  }) =>
      size *
      textScaler
          .clamp(maxScaleFactor: MmIconLabel.maxIconScale)
          .scale(fontSize) /
      fontSize;

  @override
  Widget build(BuildContext context) => Icon(icon, size: sizeIn(context));
}
