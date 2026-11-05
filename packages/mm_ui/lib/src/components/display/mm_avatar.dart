import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// A round badge with a person's initials (or an icon) on the cobalt tonal
/// fill: the leading mark of a tenant's list row or header. On a selected
/// row, whose tint is that same tone, it takes the strong cobalt instead.
///
/// The initials are the first letter of the first two words of [name], in
/// English or Urdu ("Ali Raza" shows AR, "علی رضا" shows ع ر). Pass [icon]
/// to show an icon instead (a property, an unknown caller); a name with no
/// letters shows the person icon. The avatar keeps its [size] at every text
/// size and is hidden from screen readers: the row or header around it says
/// the name.
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
  const new({required this.name, this.size = 40, this.icon, super.key});

  /// The person's or place's name, as the landlord wrote it.
  final String name;

  /// The diameter, in logical pixels.
  final double size;

  /// An icon shown in place of the initials.
  final IconData? icon;

  /// The share of [size] the initials' text takes.
  static const _textShare = 0.4;

  /// The share of [size] an icon takes.
  static const _iconShare = 0.5;

  /// The space kept between the initials and the edge, as a share of
  /// [size].
  static const _insetShare = 0.15;

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
      initials.any(MmSemantics.hasArabicScript) ? '\u200C' : '',
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
      content = Icon(
        icon ?? MmIcons.person,
        size: size * _iconShare,
        color: color,
      );
    } else {
      final style = Theme.of(context).textTheme.titleMedium!
          .copyWith(fontSize: size * _textShare, color: color);
      content = Padding(
        padding: EdgeInsets.all(size * _insetShare),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            style: mm.styleFor(initials, style),
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
          child: Center(child: content),
        ),
      ),
    );
  }
}
