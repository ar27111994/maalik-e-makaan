import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The anatomy the empty and error states share: a centred block, at most
/// [MmSize.stateMax] wide, of a large decorative icon, an optional title (a
/// heading), a one-sentence message in muted ink, an optional action and
/// optional extra content below it.
///
/// There is no tile behind the icon (DESIGN.md: no big rounded icon tiles
/// above headings). Text wraps at any size and is never truncated; figures
/// and Latin words in Urdu text are set in the Latin face. Given a
/// bounded height (the body of a screen), the block is centred in it and
/// scrolls when large text makes it taller than the space; otherwise it is
/// as tall as its content.
///
/// Internal to the feedback family.
class MmStateLayout extends StatelessWidget {
  /// Lays out a state block around [message].
  const new({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.title,
    this.liveMessage = false,
    this.action,
    this.extra,
    super.key,
  });

  /// The icon above the text, hidden from assistive technology.
  final IconData icon;

  /// The colour of [icon].
  final Color iconColor;

  /// The heading of the state, if any.
  final String? title;

  /// What happened and what to do next, in one sentence.
  final String message;

  /// Whether [message] is announced as soon as it appears (a live region).
  final bool liveMessage;

  /// The one action, if any.
  final Widget? action;

  /// Content below the action, stretched to the block's width.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final title = this.title;
    final action = this.action;
    final extra = this.extra;
    final block = Center(
      child: Padding(
        padding: const EdgeInsets.all(MmSpace.s4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MmSize.stateMax),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: MmSize.iconXl, color: iconColor),
              ),
              const SizedBox(height: MmSpace.s4),
              if (title != null) ...[
                Semantics(
                  container: true,
                  header: true,
                  child: MmScriptText(
                    title,
                    style: text.titleLarge!,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: MmSpace.s2),
              ],
              Semantics(
                container: true,
                liveRegion: liveMessage,
                child: MmScriptText(
                  message,
                  style: text.bodyLarge!.copyWith(color: colors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: MmSpace.s6),
                action,
              ],
              if (extra != null) ...[
                const SizedBox(height: MmSpace.s4),
                SizedBox(width: double.infinity, child: extra),
              ],
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return block;
        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: block,
          ),
        );
      },
    );
  }
}
