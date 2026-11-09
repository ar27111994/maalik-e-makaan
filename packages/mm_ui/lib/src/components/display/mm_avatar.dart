import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A round badge with a person's initials (or an icon) on the cobalt tonal
/// fill: the leading mark of a tenant's list row or header. On a selected
/// row, whose tint is that same tone, it takes the strong cobalt instead.
///
/// The initials are the first letter of the first two words of [name], in
/// English or Urdu ("Ali Raza" shows AR, "علی رضا" shows ع ر). Pass [icon]
/// to show an icon instead (a property, an unknown caller); a name with no
/// letters shows the person icon. The initials are centred on their ink, not
/// their line: Nastaliq letters hang below the baseline and reach far above
/// it, and each differently, so Urdu initials sit in the middle of the
/// circle as Latin capitals do, set a size smaller to match their weight.
/// The avatar keeps its [size] at every text size and is hidden from screen
/// readers: the row or header around it says the name.
///
/// Don't use it as a button on its own, or for a photo of a document.
///
/// ```dart
/// MmListTile(
///   leading: MmAvatar(name: tenant.name),
///   title: tenant.name,
/// )
/// ```
class MmAvatar extends StatelessWidget {
  /// Creates an avatar for [name].
  const new({
    required this.name,
    this.size = MmSize.avatar,
    this.icon,
    super.key,
  });

  /// The person's or place's name, as the landlord wrote it.
  final String name;

  /// The diameter, in logical pixels: [MmSize.avatar] by default, the size
  /// of a list row's avatar.
  final double size;

  /// An icon shown in place of the initials.
  final IconData? icon;

  /// The size of Latin initials, as a share of [size].
  static const _latinShare = 0.4;

  /// The size of Arabic-script initials, as a share of [size]: Nastaliq is
  /// taller and heavier than Latin capitals at the same size.
  static const _arabicShare = 0.3;

  /// The share of [size] an icon takes.
  static const _iconShare = 0.5;

  /// The most of [size] the initials' ink spans, across and down.
  static const _fillShare = 0.7;

  /// How far a Latin capital's ink reaches above and below the baseline, in
  /// ems of Atkinson Hyperlegible Next.
  static const _latinInk = (0.68, 0.01);

  /// How far each Urdu letter's ink reaches above and below the baseline,
  /// in ems of the bundled Noto Nastaliq Urdu, standing alone as an initial
  /// does. Measured from the rendered font; the avatar's tests check the
  /// centring against the pixels.
  static const _nastaliqInk = <String, (double, double)>{
    'ا': (0.93, -0.10),
    'آ': (1.17, -0.10),
    'أ': (1.21, -0.10),
    'إ': (0.93, 0.20),
    'ب': (0.46, 0.35),
    'پ': (0.46, 0.50),
    'ت': (0.70, 0.02),
    'ٹ': (0.85, 0.02),
    'ث': (0.84, 0.02),
    'ج': (0.74, 0.36),
    'چ': (0.74, 0.36),
    'ح': (0.74, 0.36),
    'خ': (1.11, 0.36),
    'د': (0.51, 0.09),
    'ڈ': (0.99, 0.09),
    'ذ': (0.84, 0.09),
    'ر': (0.46, 0.07),
    'ڑ': (0.94, 0.07),
    'ز': (0.78, 0.07),
    'ژ': (0.92, 0.07),
    'س': (0.63, 0.36),
    'ش': (1.09, 0.36),
    'ص': (0.71, 0.36),
    'ض': (1.00, 0.36),
    'ط': (0.78, 0.02),
    'ظ': (0.78, 0.02),
    'ع': (0.80, 0.36),
    'غ': (1.09, 0.36),
    'ف': (1.00, 0.02),
    'ق': (0.90, 0.36),
    'ک': (1.43, 0.02),
    'ك': (1.43, 0.02),
    'گ': (1.50, 0.02),
    'ل': (1.13, 0.36),
    'م': (0.64, 0.66),
    'ن': (0.56, 0.36),
    'ں': (0.56, 0.36),
    'و': (0.49, 0.09),
    'ؤ': (0.84, 0.09),
    'ہ': (0.47, 0.01),
    'ه': (0.47, 0.01),
    'ۂ': (0.81, 0.01),
    'ۃ': (0.78, 0.01),
    'ھ': (0.40, 0.04),
    'ء': (0.56, -0.01),
    'ی': (0.67, 0.36),
    'ي': (0.67, 0.67),
    'ئ': (0.73, 0.36),
    'ے': (0.57, 0.07),
    // Sindhi, Pashto and Arabic letters that Pakistani names also use.
    'ٻ': (0.46, 0.51),
    'ڀ': (0.46, 0.45),
    'ٺ': (0.83, 0.02),
    'ٽ': (0.86, 0.02),
    'ٿ': (0.79, 0.02),
    'ټ': (0.70, 0.14),
    'ڃ': (0.74, 0.36),
    'ڄ': (0.74, 0.36),
    'ڇ': (0.74, 0.36),
    'ځ': (1.15, 0.36),
    'څ': (1.25, 0.36),
    'ڊ': (0.51, 0.35),
    'ڌ': (0.84, 0.09),
    'ڍ': (0.51, 0.37),
    'ڎ': (0.98, 0.09),
    'ڏ': (1.00, 0.09),
    'ډ': (0.51, 0.14),
    'ڙ': (0.86, 0.07),
    'ړ': (0.46, 0.12),
    'ږ': (0.46, 0.13),
    'ښ': (0.94, 0.36),
    'ڦ': (1.09, 0.02),
    'ڪ': (1.20, 0),
    'ګ': (1.43, 0.02),
    'ڱ': (1.50, 0.02),
    'ڳ': (1.50, 0.48),
    'ڻ': (0.96, 0.36),
    'ڼ': (0.56, 0.48),
    'ې': (0.67, 0.81),
    'ۍ': (0.67, 0.36),
    'ى': (0.67, 0.36),
    'ة': (0.78, 0.01),
  };

  /// The reach of an Arabic-script letter missing from [_nastaliqInk]: that
  /// of ع, a letter of middling height with a tail below the baseline.
  static const _nastaliqDefaultInk = (0.80, 0.36);

  /// The font size [_inkWidth] measures at, large enough to be exact.
  static const _measureSize = 100.0;

  /// How far the ink of [initials] reaches above and below the baseline, in
  /// ems: the most any of its letters reaches each way. A letter is looked
  /// up by its base character, without the non-joiner or a mark that the
  /// grapheme carries.
  static (double, double) _inkOf(String initials) {
    var above = 0.0;
    var below = 0.0;
    for (final grapheme in initials.characters) {
      final letter = String.fromCharCode(grapheme.runes.first);
      final (up, down) = MmSemantics.hasArabicScript(letter)
          ? _nastaliqInk[letter] ?? _nastaliqDefaultInk
          : _latinInk;
      above = math.max(above, up);
      below = math.max(below, down);
    }
    return (above, below);
  }

  /// How wide [initials] are in [style], in ems, as set in [context].
  static double _inkWidth(
    BuildContext context,
    String initials,
    TextStyle style,
  ) =>
      MmTextMetrics.of(
        context,
        initials,
        style.copyWith(fontSize: _measureSize),
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      ).size.width /
      _measureSize;

  static const _nonJoiner = '\u200C';

  /// The initials of [name]: the first character (grapheme) of each of its
  /// first two words, in capitals where the script has them. Arabic-script
  /// initials are kept apart with a zero-width non-joiner so they show as
  /// separate letters instead of joining into a word. Empty when [name] has
  /// no words.
  static String initialsOf(String name) {
    final words = removeUnsafeCharacters(name)
        .trim()
        .split(_spaces)
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials = [
      for (final word in words) word.characters.first.toUpperCase(),
    ];
    return initials.join(
      initials.any(MmSemantics.hasArabicScript) ? _nonJoiner : '',
    );
  }

  static final _spaces = RegExp(r'\s+');

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    // On a surface already in the cobalt tone (a selected row) the tonal
    // circle would vanish: the avatar takes the strong cobalt instead.
    final onTone = MmSurfaceFill.of(context) == colors.primaryContainer;
    final fill = onTone ? colors.primary : colors.primaryContainer;
    final color = onTone ? colors.onPrimary : colors.onPrimaryContainer;
    final initials = initialsOf(name);
    final icon = this.icon;
    final Widget content;
    if (icon != null || initials.isEmpty) {
      content = Center(
        child: Icon(
          icon ?? MmIcons.person,
          size: size * _iconShare,
          color: color,
        ),
      );
    } else {
      final style = mm.styleFor(
        initials,
        Theme.of(context).textTheme.titleMedium!
            .copyWith(color: color, height: 1),
      );
      final share = MmSemantics.hasArabicScript(initials)
          ? _arabicShare
          : _latinShare;
      final (above, below) = _inkOf(initials);
      final room = size * _fillShare;
      final width = _inkWidth(context, initials, style);
      final fontSize = [
        size * share,
        if (width > 0) room / width,
        room / (above + below),
      ].reduce(math.min);
      // The baseline goes where the middle of the ink lands on the middle
      // of the circle.
      content = Align(
        alignment: Alignment.topCenter,
        child: Baseline(
          baseline: size / 2 + (above - below) / 2 * fontSize,
          baselineType: TextBaseline.alphabetic,
          child: Text(
            initials,
            style: style.copyWith(fontSize: fontSize),
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: content,
        ),
      ),
    );
  }
}
