import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One stretch of an [MmScriptText]'s text, and whether it is set in the
/// Latin face.
typedef MmScriptRun = ({String text, bool latin});

/// Text the landlord's data runs through (an amount in an Urdu sentence,
/// an address with "Gulberg III" in it), with each run in its own script's
/// face.
///
/// Nastaliq draws Latin letters in its own serif and figures in its own
/// plain shapes, so in the Urdu UI the figures of "45,000 روپے" would not
/// match the same amount anywhere else. DESIGN.md sets amounts and
/// Latin-script data in Atkinson in both languages: this sets each run of
/// Latin letters and figures inside Arabic-script text in the Latin face,
/// on the Urdu style's own lines, so a line with figures is as tall as one
/// without. Text with no Arabic-script letter is set as a whole, through
/// `MmSemantics.styleFor`. The English UI needs nothing more: its Latin
/// styles fall back to Nastaliq for Urdu letters.
///
/// Screen readers get the text as written.
///
/// Internal to mm_ui: any component family may use it.
class MmScriptText extends StatelessWidget {
  /// Shows [text] in [style], its Latin runs in the Latin face.
  const new(this.text, {required this.style, this.textAlign, super.key});

  /// The text, in whatever scripts it was written.
  final String text;

  /// The style for text in the UI's script.
  final TextStyle style;

  /// How the lines of [text] are aligned.
  final TextAlign? textAlign;

  /// [text] cut into runs, each marked whether it is set in the Latin face.
  ///
  /// A Latin run reaches from a Latin letter or a figure (0 to 9) to the
  /// last one before the next Arabic-script letter, taking in the spaces
  /// and punctuation between them ("Rs 45,000", "1,25,000"). Spaces and
  /// punctuation beside Arabic-script letters stay with them, as do Urdu's
  /// own figures and punctuation (۴۵, ، and ۔).
  static List<MmScriptRun> runsOf(String text) {
    final runes = text.runes.toList();
    final runs = <MmScriptRun>[];
    var done = 0;
    int? latinStart;
    var latinEnd = 0;

    void add(int start, int end, {required bool latin}) {
      if (end > start) {
        runs.add((
          text: String.fromCharCodes(runes.sublist(start, end)),
          latin: latin,
        ));
      }
    }

    void closeLatin() {
      final start = latinStart;
      if (start == null) return;
      add(done, start, latin: false);
      add(start, latinEnd, latin: true);
      done = latinEnd;
      latinStart = null;
    }

    for (var i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      if (_latin.hasMatch(char)) {
        latinStart ??= i;
        latinEnd = i + 1;
      } else if (MmSemantics.hasArabicScript(char)) {
        closeLatin();
      }
    }
    closeLatin();
    add(done, runes.length, latin: false);
    return runs;
  }

  static final _latin = RegExp(r'[\p{Script=Latin}0-9]', unicode: true);

  static const _latinFace = TextStyle(
    fontFamily: MmFontFamily.latin,
    package: 'mm_ui',
  );

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final runs = mm.script == MmScript.urdu && MmSemantics.hasArabicScript(text)
        ? runsOf(text)
        : null;
    if (runs == null || runs.length == 1) {
      return Text(text, style: mm.styleFor(text, style), textAlign: textAlign);
    }
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(
        children: [
          for (final run in runs)
            TextSpan(text: run.text, style: run.latin ? _latinFace : null),
        ],
      ),
      style: style,
      textAlign: textAlign,
      // Every line keeps the Urdu style's height and baseline: the Latin
      // face's metrics would otherwise make a line with figures taller.
      strutStyle: StrutStyle.fromTextStyle(effective, forceStrutHeight: true),
    );
  }
}
