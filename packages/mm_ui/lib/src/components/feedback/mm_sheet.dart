import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The widest a sheet grows; on wider windows it is centred.
const double _maxSheetWidth = 640;

/// Shows a modal bottom sheet titled [title] with [builder]'s content, and
/// completes with the value the sheet is closed with (null when it is
/// dismissed).
///
/// The sheet has a header row with the [title] (a heading) and a close
/// button ("Close" for screen readers, from `MmLocalizations`); the content
/// below it scrolls when it is taller than the space. The sheet grows with
/// its content up to the height of the window, keeps clear of the system
/// bars and of the on-screen keyboard (so a form's fields stay visible),
/// and is at most 640 dp wide, centred on wide windows. The drag handle,
/// a tap outside, the back button and Escape also close it.
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
}) {
  final duration = MmMotion.of(context, MmDuration.standard);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: _maxSheetWidth),
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
    ),
    builder: (context) => _MmSheet(title: title, builder: builder),
  );
}

/// The inside of a sheet: the header row and the scrolling content.
class _MmSheet extends StatelessWidget {
  const new({required this.title, required this.builder});

  final String title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final close = MmLocalizations.of(context).close;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: MmSpace.s4,
                end: MmSpace.s1,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MmSpace.s2,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: MmSpace.s2,
                      ),
                      child: Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                  // The tooltip's words are already the label; announcing
                  // them again as a tooltip would make screen readers say
                  // them twice.
                  Tooltip(
                    message: close,
                    excludeFromSemantics: true,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Semantics(
                        label: close,
                        child: const Icon(MmIcons.close),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MmSpace.s4,
                  MmSpace.s2,
                  MmSpace.s4,
                  MmSpace.s4,
                ),
                child: Builder(builder: builder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
