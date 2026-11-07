import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_modal_sheet.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Shows a modal bottom sheet titled [title] with [builder]'s content, and
/// completes with the value the sheet is closed with (null when it is
/// dismissed).
///
/// The sheet has a header row with the [title] (a heading) and a close
/// button ("Close" for screen readers, from `MmLocalizations`); the content
/// below it scrolls when it is taller than the space, and a rule appears
/// under the header once it has scrolled under it. The sheet grows with its
/// content up to the height of the window, keeps clear of the system bars
/// and of the on-screen keyboard (so a form's fields stay visible), and is
/// at most [MmSize.sheetMax] (640 dp) wide, centred on wide windows. In
/// dark and high-contrast modes it has the outline of overlays, where it
/// would otherwise melt into the dimmed page. The drag handle, a tap
/// outside, the back button and Escape also close it.
///
/// Use it for a short task in the context of a screen: recording a
/// payment, choosing a filter, sharing a receipt. For a yes or no question,
/// use `showMmConfirmDialog`. Close it with a value from inside with
/// `Navigator.pop(context, value)`.
///
/// ```dart
/// final payment = await showMmSheet<Payment>(
///   context,
///   title: l10n.recordPayment,
///   builder: (context) => PaymentForm(
///     onSaved: (payment) => Navigator.pop(context, payment),
///   ),
/// );
/// ```
Future<T?> showMmSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) => showMmModalSheet<T>(
  context,
  builder: (context) => _MmSheet(title: title, builder: builder),
);

/// The inside of a sheet: the header row and the scrolling content.
class _MmSheet extends StatefulWidget {
  const new({required this.title, required this.builder});

  final String title;
  final WidgetBuilder builder;

  @override
  State<_MmSheet> createState() => _MmSheetState();
}

class _MmSheetState extends State<_MmSheet> {
  /// Whether the content has scrolled under the header.
  bool _scrolled = false;

  /// Follows the content's scroll position as it scrolls
  /// ([ScrollNotification]) and as its size changes
  /// ([ScrollMetricsNotification]), ignoring scrollables inside it.
  bool _onScroll(Notification notification) {
    final metrics = switch (notification) {
      ScrollNotification(depth: 0, :final metrics) => metrics,
      ScrollMetricsNotification(depth: 0, :final metrics) => metrics,
      _ => null,
    };
    if (metrics != null) {
      final scrolled = metrics.extentBefore > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmSheetHeader(title: widget.title),
            // A rule under the header once content has scrolled under it,
            // so the fixed header and the moving content stay apart. It
            // always takes its hairline, so the content does not jump.
            Divider(
              height: MmSize.hairline,
              thickness: MmSize.hairline,
              color: _scrolled ? null : Colors.transparent,
            ),
            Flexible(
              child: NotificationListener<Notification>(
                onNotification: _onScroll,
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    MmSpace.s4,
                    MmSpace.s2,
                    MmSpace.s4,
                    MmSpace.s4,
                  ),
                  child: Builder(builder: widget.builder),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
