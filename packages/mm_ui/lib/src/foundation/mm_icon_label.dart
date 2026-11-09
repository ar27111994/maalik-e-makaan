import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/foundation/mm_fit_words.dart';
import 'package:mm_ui/src/foundation/mm_icon_size.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// An icon followed by words, set as one paragraph so the words wrap under
/// the icon instead of overflowing, and the icon stays on the first line:
/// a status badge, a trend, a void stamp, an error line.
///
/// The icon grows with the text size, up to one and a half times its size,
/// and mirrors with the text direction when its glyph points. The words
/// are set as [MmScriptText] sets them: in the Urdu UI, figures and Latin
/// letters among Urdu words ("12 دن سے واجب") are in the Latin face, on
/// the Urdu style's lines, like amounts everywhere else. It is
/// decorative: assistive technology reads only [label], which joins the
/// semantics node of the nearest container or merging ancestor.
///
/// Internal to mm_ui: any component family may use it.
class MmIconLabel extends StatelessWidget {
  /// Shows [icon] in [iconColor] before [label] in [style].
  const new({
    required this.icon,
    required this.label,
    required this.style,
    required this.iconColor,
    this.iconSize = MmSize.iconSm,
    this.textAlign = TextAlign.start,
    this.textWidthBasis = TextWidthBasis.parent,
    this.fitWords = false,
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

  /// The size of the icon at 100% text size.
  final double iconSize;

  /// How the lines of the words are aligned.
  final TextAlign textAlign;

  /// How wide the paragraph is once its words wrap: the width it is given
  /// ([TextWidthBasis.parent]), or its longest line
  /// ([TextWidthBasis.longestLine]) for a label on a fill of its own, such
  /// as a badge, which would otherwise keep empty space after its lines.
  final TextWidthBasis textWidthBasis;

  /// Whether a word too wide for the line (an amount and its currency word
  /// at 200% text on a narrow badge) may break between the figures and the
  /// currency word, rather than being cut inside the figures
  /// (`MmFitWords`). Wherever it fits, it stays together.
  final bool fitWords;

  /// The most the icon grows with the text size: beyond it a large icon
  /// would crowd the words it only illustrates ([MmIconSize.maxScale]).
  static const double maxIconScale = MmIconSize.maxScale;

  /// [size] grown with the ambient text size, up to [maxIconScale] times:
  /// the size of an icon that stands beside words on its own (a field's
  /// leading icon, chevron or buttons), so it keeps pace with the text
  /// without crowding it ([MmIconSize.withText]).
  static double scaledSize(BuildContext context, double size) =>
      MmIconSize.withText(context, size);

  @override
  Widget build(BuildContext context) {
    // Neither face draws the narrow no-break space intl puts before AM.
    final label = MmSemantics.drawableSpaces(this.label);
    final loose = fitWords ? MmFitWords.loosened(label) : label;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: loose == label
          ? _paragraph(context, label)
          : MmFitWords(
              tight: _paragraph(context, label),
              loose: _paragraph(context, loose),
            ),
    );
  }

  /// [label] set beside the icon, in one paragraph.
  Widget _paragraph(BuildContext context, String label) {
    // Text scales the widget in a WidgetSpan along with its words. The icon
    // is sized so that, after that scaling, it has grown only up to
    // maxIconScale.
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize = style.fontSize ?? kDefaultFontSize;
    final scale = textScaler.scale(fontSize) / fontSize;
    final capped =
        textScaler.clamp(maxScaleFactor: maxIconScale).scale(fontSize) /
        fontSize;
    final mixed = MmScriptText.spansOf(context, label, style);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: MmSpace.s1),
              child: Icon(
                icon,
                size: iconSize * capped / scale,
                color: iconColor,
              ),
            ),
          ),
          if (mixed == null) TextSpan(text: label) else ...mixed.spans,
        ],
      ),
      style: mixed == null ? context.mm.styleFor(label, style) : style,
      strutStyle: mixed?.strut,
      textAlign: textAlign,
      textWidthBasis: textWidthBasis,
    );
  }
}
