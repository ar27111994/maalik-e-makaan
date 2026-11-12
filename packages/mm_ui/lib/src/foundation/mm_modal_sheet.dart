import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_line_icon.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
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
/// and high-contrast modes (the theme's bottom-sheet shape carries
/// [MmTheme.overlayEdge]), where it would otherwise melt into the dimmed
/// page. Start the content with an
/// [MmSheetHeader], and keep it clear of the on-screen keyboard with
/// `MediaQuery.viewInsetsOf(context).bottom`.
///
/// Internal to mm_ui: the sheets of every family open through it.
Future<T?> showMmModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final duration = MmMotion.of(context, MmDuration.standard);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: MmSize.sheetMax),
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
/// The button is centred on the title's first line, in both scripts (an
/// Urdu line is taller than a Latin one), and its glyph
/// grows with the text, as every icon beside words in mm_ui does, up to
/// [MmIconLabel.maxIconScale] times; it stays at least a touch target.
///
/// A [userTitle] (a member's name, a document's name) is set as the
/// landlord's data: in its own script's face and its own direction.
///
/// Internal to mm_ui: the sheets of every family start with it.
class MmSheetHeader extends StatelessWidget {
  /// Shows [title] with a close button.
  const new({required this.title, this.userTitle = false, super.key});

  /// What the sheet is for ("Property", "Record payment").
  final String title;

  /// Whether [title] is the landlord's data rather than words from the
  /// app's localisations.
  final bool userTitle;

  @override
  Widget build(BuildContext context) {
    final close = MmLocalizations.of(context).close;
    final style = Theme.of(context).textTheme.titleLarge!;
    final iconSize = MmIconLabel.scaledSize(context, MmSize.iconLg);
    // An icon button is its glyph in an 8 dp padding, and at least a touch
    // target.
    final button = math.max(MmSize.minTarget, iconSize + 2 * MmSpace.s2);
    final line = MmLineIcon.lineHeightOf(context, style);
    // The title keeps at least 8 dp above it; the button's middle and the
    // first line's middle meet, whichever of the two has to move down.
    final middle = math.max(MmSpace.s2 + line / 2, button / 2);
    final titleTop = middle - line / 2;
    final buttonTop = middle - button / 2;
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
              padding: EdgeInsetsDirectional.only(
                top: titleTop,
                bottom: MmSpace.s2,
              ),
              child: Semantics(
                container: true,
                header: true,
                child: userTitle
                    ? MmUserText(title, style: style)
                    : Text(title, style: style),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(top: buttonTop),
            // The tooltip's words are already the label; announcing them
            // again as a tooltip would make screen readers say them twice.
            child: Tooltip(
              message: close,
              excludeFromSemantics: true,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                iconSize: iconSize,
                icon: Semantics(label: close, child: const Icon(MmIcons.close)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
