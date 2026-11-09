import 'package:flutter/widgets.dart';

/// Calls [onShown] each time [child] is shown again after it was kept alive
/// out of sight: in a navigation-shell tab the user left, or under a page
/// pushed over it. Both turn its [TickerMode] off.
///
/// A screen kept alive that way still shows what it last fetched, so a
/// change made elsewhere meanwhile (another member accepting an invitation
/// on their phone) would stay hidden until the screen is opened afresh
/// (docs/uat.md, D4). [onShown] runs after the frame, so it may refresh a
/// provider.
class RefreshWhenShown extends StatefulWidget {
  const new({required this.onShown, required this.child, super.key});

  final VoidCallback onShown;
  final Widget child;

  @override
  State<RefreshWhenShown> createState() => _RefreshWhenShownState();
}

class _RefreshWhenShownState extends State<RefreshWhenShown> {
  bool? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.valuesOf(context).enabled;
    if (_shown == false && shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onShown();
      });
    }
    _shown = shown;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
