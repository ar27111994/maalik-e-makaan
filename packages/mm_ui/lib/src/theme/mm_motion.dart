import 'package:flutter/widgets.dart';

/// Motion that honours the platform's reduced-motion setting: every
/// duration becomes zero, so changes cross-fade or cut instead of moving.
abstract final class MmMotion {
  /// [duration], or [Duration.zero] when animations are disabled.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
