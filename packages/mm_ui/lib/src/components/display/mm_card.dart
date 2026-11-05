import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A card: a flat paper surface that groups one thing on a page, such as a
/// tenant's summary, a property's dues or a group of list rows.
///
/// It takes the theme's card look: surface colour, a hairline rule border,
/// `md` corners and no shadow (paper does not float). With [onTap] the whole
/// card is one button: it shows ink when pressed, a 2 dp focus ring while it
/// has keyboard focus, activates with Enter or Space, and screen readers
/// read its contents (or [semanticLabel]) as that button's label. Without
/// [onTap] it is static: one group whose text is read together, while any
/// controls inside it stay separate.
///
/// Cards never nest: in debug builds an [MmCard] inside another throws a
/// [FlutterError]. Inside a card, group with `MmDetailRow`, `MmListTile`,
/// `MmSectionHeader` and dividers instead. Don't use it for a single figure
/// (use `MmStatTile`) or for something on top of the page (use a sheet or a
/// dialog).
///
/// ```dart
/// MmCard(
///   onTap: () => openTenant(tenant),
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: [
///       Text(tenant.name),
///       MmAmount(amount: tenant.balance),
///     ],
///   ),
/// )
/// ```
class MmCard extends StatelessWidget {
  /// Creates a card around [child].
  const new({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(MmSpace.s4),
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  /// The card's content.
  final Widget child;

  /// The space between the card's edge and [child]. Pass
  /// [EdgeInsets.zero] for a group of list rows, which pad themselves.
  final EdgeInsetsGeometry padding;

  /// Called when the card is tapped or activated from the keyboard. When
  /// null the card is static: not a button and not focusable.
  final VoidCallback? onTap;

  /// What a screen reader says for the card instead of reading its contents
  /// ("Ali Raza, Flat 3, Rs 45,000 due"). Leave it null when the card holds
  /// its own buttons or fields: they would be hidden behind the label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(_debugCheckNotNested(context), 'MmCard nested in an MmCard');
    final semanticLabel = this.semanticLabel;
    final tappable = onTap != null;
    final Widget card = Semantics(
      container: true,
      button: tappable,
      label: semanticLabel,
      child: MmSurface(
        onTap: onTap,
        child: _MmCardScope(
          child: Padding(
            padding: padding,
            child: semanticLabel == null
                ? child
                : ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
    return tappable ? MergeSemantics(child: card) : card;
  }

  /// Throws when [context] is already inside an [MmCard].
  static bool _debugCheckNotNested(BuildContext context) {
    if (context.getInheritedWidgetOfExactType<_MmCardScope>() != null) {
      throw FlutterError.fromParts([
        ErrorSummary('An MmCard was placed inside another MmCard.'),
        ErrorDescription(
          'Cards never nest: a card is one sheet of paper that groups one '
          'thing on the page, and a card inside a card reads as clutter.',
        ),
        ErrorHint(
          'Inside a card, group content with MmDetailRow, MmListTile, '
          'MmSectionHeader and dividers, or place the cards one after the '
          'other on the page.',
        ),
        context.describeElement('The nested MmCard was'),
      ]);
    }
    return true;
  }
}

/// Marks the subtree inside an [MmCard], so a nested card can tell.
class _MmCardScope extends InheritedWidget {
  const new({required super.child});

  @override
  bool updateShouldNotify(_MmCardScope oldWidget) => false;
}
