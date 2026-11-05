import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// An icon followed by words, set as one paragraph: the words wrap under
/// the icon instead of overflowing, the icon stays on the first line and
/// grows with the text size.
///
/// The icon is decorative: assistive technology reads only [label].
///
/// Internal to the records family: the receipt's void banner and the score
/// gauge's band.
class MmRecordIconLabel extends StatelessWidget {
  /// Shows [icon] in [iconColor] before [label] in [style].
  const new({
    required this.icon,
    required this.label,
    required this.style,
    required this.iconColor,
    this.textAlign = TextAlign.start,
    super.key,
  });

  /// The icon before the words.
  final IconData icon;

  /// The words, which carry the meaning.
  final String label;

  /// The style of the words.
  final TextStyle style;

  /// The colour of the icon.
  final Color iconColor;

  /// How the lines of the words are aligned.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: MmSpace.s1),
              child: Icon(icon, size: MmSize.iconSm, color: iconColor),
            ),
          ),
          TextSpan(text: label),
        ],
      ),
      style: style,
      textAlign: textAlign,
    ),
  );
}
