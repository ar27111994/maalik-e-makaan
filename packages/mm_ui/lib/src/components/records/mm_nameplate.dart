import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_line_icon.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The brass house nameplate: a property's name engraved on a
/// brass-bordered plate, with an optional address under it and an icon for
/// the kind of property at the start.
///
/// The plate is as wide as its words, up to the width it is given; longer
/// names and addresses wrap rather than being cut short. Names written in
/// English are set in the Latin face in the Urdu UI. Screen readers hear
/// the name as a header, then the address; the icon is decorative.
///
/// Use it once, at the top of a property's screen: it is the one brass
/// element there. Don't use it for lists of properties (use list tiles) or
/// for anything that is not a property's or a unit's own name.
///
/// ```dart
/// MmNameplate(
///   name: property.name,
///   subtitle: property.address,
///   icon: MmIcons.home,
/// )
/// ```
class MmNameplate extends StatelessWidget {
  /// Creates a nameplate for [name].
  const new({required this.name, this.subtitle, this.icon, super.key});

  /// The property's name ("Raza Manzil"), as the landlord wrote it.
  final String name;

  /// An optional line under the name, usually the address ("House 12,
  /// Street 4, Gulberg III, Lahore").
  final String? subtitle;

  /// An optional icon at the start for the kind of property (a house, a
  /// shop, a flat).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final on = colors.onBrassContainer;
    final subtitle = this.subtitle;
    final icon = this.icon;
    final nameStyle = text.titleLarge!.copyWith(color: on);
    // An engraved hairline runs inside the brass frame, as on a cast
    // plate: the frame, a gap as wide as the frame, then the hairline.
    const engraving = MmSize.frame * 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brassContainer,
        border: Border.all(color: colors.brass, width: MmSize.frame),
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(engraving),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: colors.brass)),
          child: Padding(
            // The words sit 12 dp inside the plate's outer edge.
            padding: const EdgeInsetsDirectional.all(MmSpace.s3 - engraving),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  // The icon grows with the text, up to half as large again,
                  // and is centred on the name's first line.
                  MmLineIcon(icon: icon, color: on, style: nameStyle),
                  const SizedBox(width: MmSpace.s3),
                ],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: MmUserText(name, style: nameStyle),
                      ),
                      if (subtitle != null)
                        Semantics(
                          container: true,
                          child: MmUserText(
                            subtitle,
                            style: text.bodyMedium!.copyWith(color: on),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
