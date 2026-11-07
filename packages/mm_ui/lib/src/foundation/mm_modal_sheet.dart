import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/theme/mm_theme.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Opens [builder]'s content as a modal bottom sheet the way every mm_ui
/// sheet opens, and completes with the value it is closed with (null when
/// it is dismissed).
///
/// The sheet grows with its content up to the height of the window, keeps
/// clear of the system bars, is at most [MmSize.sheetMax] wide (centred on
/// wide windows), slides in over [MmDuration.standard] (at once when the
/// platform asks for reduced motion), and has the edge of overlays in dark
/// and high-contrast modes ([MmTheme.overlayEdge]), where it would
/// otherwise melt into the dimmed page. Start the content with an
/// [MmSheetHeader], and keep it clear of the on-screen keyboard with
/// `MediaQuery.viewInsetsOf(context).bottom`.
///
/// Internal to mm_ui: the sheets of every family open through it.
Future<T?> showMmModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final theme = Theme.of(context);
  final mm = context.mm;
  final duration = MmMotion.of(context, MmDuration.standard);
  final edge = MmTheme.overlayEdge(
    mm.colors,
    brightness: theme.brightness,
    highContrast: mm.highContrast,
  );
  final shape = theme.bottomSheetTheme.shape;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: MmSize.sheetMax),
    shape: shape is OutlinedBorder ? shape.copyWith(side: edge) : shape,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
    ),
    builder: builder,
  );
}

/// The top of a sheet: its [title] as a heading, and a close button
/// ("Close" for screen readers, from `MmLocalizations`) at the end. A long
/// title wraps beside the button.
///
/// Internal to mm_ui: the sheets of every family start with it.
class MmSheetHeader extends StatelessWidget {
  /// Shows [title] with a close button.
  const new({required this.title, super.key});

  /// What the sheet is for ("Property", "Record payment").
  final String title;

  @override
  Widget build(BuildContext context) {
    final close = MmLocalizations.of(context).close;
    return Padding(
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
          // The tooltip's words are already the label; announcing them
          // again as a tooltip would make screen readers say them twice.
          Tooltip(
            message: close,
            excludeFromSemantics: true,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Semantics(label: close, child: const Icon(MmIcons.close)),
            ),
          ),
        ],
      ),
    );
  }
}
