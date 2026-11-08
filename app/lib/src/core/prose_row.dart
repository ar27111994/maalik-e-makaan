import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

/// A passage of the landlord's own words (a description, notes, what was
/// done) under its label, for the end of a details card.
///
/// `MmDetailRow` keeps every value on the end edge so a card's figures
/// share one edge, which suits a name, a date or an amount; a paragraph of
/// several lines set that way reads as a ragged, end-aligned block. Until
/// mm_ui has a prose variant of the row (a gap reported to it: label above,
/// value full width at the start edge), passages use this: the label in
/// the row's muted label style, the words under it in the row's value
/// style, from the start edge across the whole width, in their script's
/// face and in their own order. It is one node for screen readers, "Notes,
/// Paid before the deadline", as a detail row is.
class ProseRow extends StatelessWidget {
  const new({required this.label, required this.text, super.key});

  /// What the passage is ("Notes"), from the app's localisations.
  final String label;

  /// The landlord's words.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final theme = Theme.of(context).textTheme;
    // Isolated, so English words keep their own order (a closing full stop
    // at their end) in a paragraph laid out right to left.
    final shown = MmSemantics.isolated(text, Directionality.of(context));
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: theme.bodyMedium!.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: MmSpace.s1),
            Text(
              shown,
              // Words typed in English in the Urdu UI in the Latin face.
              style: context.mm.styleFor(
                text,
                theme.bodyLarge!.copyWith(color: colors.ink),
              ),
              textAlign: TextAlign.start,
              semanticsLabel: shown == text ? null : text,
            ),
          ],
        ),
      ),
    );
  }
}
