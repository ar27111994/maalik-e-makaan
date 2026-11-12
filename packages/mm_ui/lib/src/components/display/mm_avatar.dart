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
/// their line: Urdu letters sit on the baseline, hang below it or carry
/// dots and marks above it, each differently (ب, ع, ٹ), so Urdu initials
/// sit in the middle of the circle as Latin capitals do.
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

  /// The size of the initials, as a share of [size], in both scripts:
  /// Noto Sans Arabic's alif stands about as tall as Atkinson's capitals
  /// (0.73 and 0.68 em), so Urdu initials take the size Latin ones do.
  static const _share = 0.4;

  /// The share of [size] an icon takes.
  static const _iconShare = 0.5;

  /// The most of [size] the initials' ink spans, across and down.
  static const _fillShare = 0.7;

  /// How far a Latin capital's ink reaches above and below the baseline, in
  /// ems of Atkinson Hyperlegible Next.
  static const _latinInk = (0.68, 0.01);

  /// How far each Urdu letter's ink reaches above and below the baseline,
  /// in ems of the bundled Noto Sans Arabic at the initials' weight (600),
  /// standing alone as an initial does. Measured from the rendered font;
  /// the avatar's tests check the centring against the pixels.
  static const _arabicInk = <String, (double, double)>{
    'ا': (0.73, 0.00),
    'آ': (0.86, 0.00),
    'أ': (0.97, 0.00),
    'إ': (0.66, 0.31),
    'ب': (0.43, 0.24),
    'پ': (0.43, 0.35),
    'ت': (0.55, 0.02),
    'ٹ': (0.71, 0.02),
    'ث': (0.66, 0.02),
    'ج': (0.47, 0.40),
    'چ': (0.47, 0.40),
    'ح': (0.47, 0.40),
    'خ': (0.70, 0.40),
    'د': (0.50, 0.01),
    'ڈ': (0.87, 0.01),
    'ذ': (0.71, 0.01),
    'ر': (0.37, 0.23),
    'ڑ': (0.76, 0.23),
    'ز': (0.60, 0.23),
    'ژ': (0.71, 0.23),
    'س': (0.45, 0.23),
    'ش': (0.71, 0.23),
    'ص': (0.42, 0.23),
    'ض': (0.64, 0.23),
    'ط': (0.73, 0.01),
    'ظ': (0.73, 0.01),
    'ع': (0.54, 0.40),
    'غ': (0.76, 0.40),
    'ف': (0.78, 0.02),
    'ق': (0.66, 0.19),
    'ک': (0.71, 0.02),
    'ك': (0.73, 0.02),
    'گ': (0.85, 0.02),
    'ل': (0.73, 0.23),
    'م': (0.42, 0.39),
    'ن': (0.54, 0.23),
    'ں': (0.35, 0.23),
    'و': (0.38, 0.23),
    'ؤ': (0.68, 0.23),
    'ہ': (0.52, 0.00),
    'ه': (0.53, 0.01),
    'ۂ': (0.81, 0.00),
    'ۃ': (0.72, 0.00),
    'ھ': (0.53, 0.01),
    'ء': (0.41, 0.06),
    'ی': (0.46, 0.23),
    'ي': (0.46, 0.45),
    'ئ': (0.50, 0.23),
    'ے': (0.49, 0.02),
    // Sindhi, Pashto and Arabic letters that Pakistani names also use.
    'ٻ': (0.43, 0.39),
    'ڀ': (0.43, 0.36),
    'ٺ': (0.70, 0.02),
    'ٽ': (0.66, 0.02),
    'ٿ': (0.67, 0.02),
    'ټ': (0.55, 0.15),
    'ڃ': (0.47, 0.40),
    'ڄ': (0.47, 0.40),
    'ڇ': (0.47, 0.40),
    'ځ': (0.78, 0.40),
    'څ': (0.81, 0.40),
    'ڊ': (0.50, 0.22),
    'ڌ': (0.71, 0.01),
    'ڍ': (0.50, 0.22),
    'ڎ': (0.82, 0.01),
    'ڏ': (0.82, 0.01),
    'ډ': (0.50, 0.14),
    'ڙ': (0.72, 0.23),
    'ړ': (0.37, 0.23),
    'ږ': (0.37, 0.43),
    'ښ': (0.60, 0.23),
    'ڦ': (0.89, 0.02),
    'ڪ': (0.61, 0.02),
    'ګ': (0.71, 0.02),
    'ڱ': (0.98, 0.02),
    'ڳ': (0.85, 0.38),
    'ڻ': (0.69, 0.23),
    'ڼ': (0.54, 0.38),
    'ې': (0.46, 0.59),
    'ۍ': (0.46, 0.23),
    'ى': (0.46, 0.23),
    'ة': (0.72, 0.00),
  };

  /// The reach of an Arabic-script letter missing from [_arabicInk]: that
  /// of ع, a letter of middling height with a tail below the baseline.
  static const _arabicDefaultInk = (0.54, 0.40);

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
          ? _arabicInk[letter] ?? _arabicDefaultInk
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
      final (above, below) = _inkOf(initials);
      final room = size * _fillShare;
      final width = _inkWidth(context, initials, style);
      final fontSize = [
        size * _share,
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
