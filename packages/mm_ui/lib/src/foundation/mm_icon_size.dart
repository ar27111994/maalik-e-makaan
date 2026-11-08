import 'package:flutter/widgets.dart';

/// How large an icon that stands beside words is drawn: grown with the
/// reader's text size, as the words are, up to [maxScale] times its size.
///
/// mm_ui's own icons beside words (a field's leading icon, a list row's
/// icon and chevron, a sheet's close button) already grow this way; use
/// [withText] for an icon the app sets beside words of its own, so it
/// keeps pace with them as mm_ui's do:
///
/// ```dart
/// Icon(MmIcons.receiptText, size: MmIconSize.withText(context, MmSize.iconLg))
/// ```
abstract final class MmIconSize {
  /// The most an icon grows with the text size: beyond it a large icon
  /// would crowd the words it only illustrates.
  static const double maxScale = 1.5;

  /// [size] grown with the ambient text size, up to [maxScale] times.
  static double withText(BuildContext context, double size) =>
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: maxScale)
          .scale(size);
}
