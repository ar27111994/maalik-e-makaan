import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The slow pulse that tells a sighted reader skeletons stand for content
/// on its way: their opacity breathes between full and [faintest], one
/// fade in or out every [MmDuration.pulse].
///
/// Every skeleton under one pulse breathes in step from a single
/// animation: `MmSkeletonList` puts one around all of its rows, and an
/// `MmSkeleton` on its own runs its own. A pulse inside another pulse adds
/// nothing. When the platform asks for reduced motion the pulse stops and
/// skeletons stay at full opacity.
///
/// Internal to the feedback family.
class MmSkeletonPulse extends StatefulWidget {
  /// Pulses the skeletons in [child].
  const new({required this.child, super.key});

  /// The opacity the pulse fades skeletons to before they return.
  static const double faintest = 0.5;

  /// The subtree whose skeletons pulse.
  final Widget child;

  /// The opacity of the skeletons at [context]: the nearest pulse's, or
  /// full opacity when there is none.
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PulseScope>()?.opacity ??
      kAlwaysCompleteAnimation;

  @override
  State<MmSkeletonPulse> createState() => _MmSkeletonPulseState();
}

class _MmSkeletonPulseState extends State<MmSkeletonPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  /// Whether an outer pulse already drives this subtree.
  bool _nested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nested = context.getInheritedWidgetOfExactType<_PulseScope>() != null;
    final duration = MmMotion.of(context, MmDuration.pulse);
    if (_nested || duration == Duration.zero) {
      _controller?.stop();
      _controller?.value = 0;
      return;
    }
    final controller = _controller ??= AnimationController(vsync: this);
    _opacity ??= controller.drive(
      Tween<double>(
        begin: 1,
        end: MmSkeletonPulse.faintest,
      ).chain(CurveTween(curve: MmEasing.standard)),
    );
    controller.duration = duration;
    if (!controller.isAnimating) controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nested) return widget.child;
    final controller = _controller;
    final animating = controller != null && controller.isAnimating;
    return _PulseScope(
      opacity: animating ? _opacity! : kAlwaysCompleteAnimation,
      child: widget.child,
    );
  }
}

/// Hands a pulse's opacity to the skeletons below it.
class _PulseScope extends InheritedWidget {
  const new({required this.opacity, required super.child});

  final Animation<double> opacity;

  @override
  bool updateShouldNotify(_PulseScope oldWidget) =>
      opacity != oldWidget.opacity;
}
