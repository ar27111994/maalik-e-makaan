import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The window size classes the layout changes at (the Material 3 classes,
/// at the breakpoints in the design tokens).
enum MmWindowSize {
  /// Under 600 dp: phones in portrait. One column, a bottom navigation bar,
  /// the primary action within thumb reach.
  compact,

  /// 600 to 839 dp: small tablets and phones in landscape. A navigation
  /// rail replaces the bottom bar.
  medium,

  /// 840 to 1199 dp: a list and its details sit side by side.
  expanded,

  /// 1200 dp and wider: desktop web. The navigation rail shows its labels
  /// beside the icons.
  large;

  /// The size class of a window [width] dp wide.
  static MmWindowSize forWidth(double width) {
    if (width >= MmBreakpoint.large) return large;
    if (width >= MmBreakpoint.expanded) return expanded;
    if (width >= MmBreakpoint.medium) return medium;
    return compact;
  }

  /// The size class of the window [context] is shown in.
  static MmWindowSize of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  /// Whether this class is at least [other] (`medium.atLeast(compact)`).
  bool atLeast(MmWindowSize other) => index >= other.index;
}
