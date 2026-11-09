import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports, in debug builds, a control inside [child]: anything that can
/// take keyboard focus, such as a button, a field or a switch.
///
/// Some display components are one node for screen readers (a detail row)
/// or one button (a tappable card, row or stat tile). A control inside one
/// of them is merged into it, out of reach of screen readers, and its taps
/// are easily mistaken for the component's own. The part that must stay
/// free of controls is wrapped in this widget, which checks after every
/// frame it is built in and reports a control once, as an overflow is
/// reported. It looks under [focusNode], the node of a focusable widget
/// already around [child] (a tappable surface's ink well); without one it
/// adds a focus node that takes no focus itself, in release builds too, so
/// the tree does not change shape.
///
/// Internal to the display family.
class MmNoControls extends StatefulWidget {
  /// Checks [child] for controls while [enabled].
  const new({
    required this.child,
    required this.summary,
    required this.description,
    required this.hint,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  /// The content to check.
  final Widget child;

  /// What is wrong, in one sentence naming the component.
  final String summary;

  /// Why a control cannot sit there.
  final String description;

  /// What to do instead.
  final String hint;

  /// Whether [child] must be free of controls. A static card may hold
  /// buttons; a tappable one may not.
  final bool enabled;

  /// The focus node of a widget right around [child] whose descendants are
  /// [child]'s, or null to add a node of its own.
  final FocusNode? focusNode;

  @override
  State<MmNoControls> createState() => _MmNoControlsState();
}

class _MmNoControlsState extends State<MmNoControls> {
  final _node = FocusNode(
    debugLabel: 'MmNoControls',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Whether the control now inside has been reported, so it is reported
  /// once rather than on every frame.
  bool _reported = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _check() {
    if (!mounted || !widget.enabled) return;
    final node = widget.focusNode ?? _node;
    final controls = node.descendants.where((node) => node.canRequestFocus);
    if (controls.isEmpty) {
      _reported = false;
      return;
    }
    if (_reported) return;
    _reported = true;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts([
          ErrorSummary(widget.summary),
          ErrorDescription(widget.description),
          ErrorHint(widget.hint),
          DiagnosticsProperty<FocusNode>(
            'The control has the focus node',
            controls.first,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          context.describeElement('The content was'),
        ]),
        library: 'mm_ui',
        context: ErrorDescription('while checking for controls'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      if (widget.enabled) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _check());
      }
      return true;
    }(), 'the check reports a control, never fails');
    if (widget.focusNode != null) return widget.child;
    return Focus(
      focusNode: _node,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      child: widget.child,
    );
  }
}
