import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_wrap.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A saved CNIC, masked by default (`35202-•••••••-1`: only the first five
/// digits and the last one show), with a button that reveals the full
/// number and masks it again ("Show full CNIC" / "Hide CNIC", which is also
/// the button's accessible label).
///
/// Use it wherever a tenant's CNIC is shown, so it is not exposed on a
/// shared screen or in a screenshot by accident. A screen reader spells the
/// digit groups out digit by digit; while masked, it hears only the digits
/// that show and how many are hidden ("3 5 2 0 2, 7 hidden digits, 1"),
/// never the hidden ones themselves. The number is set in the Latin face in
/// both languages; when it does not fit on one line it wraps only between
/// its digit groups, and copying it gives the number as written.
///
/// To enter a CNIC, use `MmCnicField`.
///
/// ```dart
/// MmCnicText(cnic: tenant.cnic)
/// ```
class MmCnicText extends StatefulWidget {
  /// Shows [cnic], masked unless [initiallyMasked] is false.
  const new({
    required this.cnic,
    this.initiallyMasked = true,
    this.style,
    super.key,
  });

  /// The CNIC shown.
  final Cnic cnic;

  /// Whether the number starts masked. A different [cnic] starts masked
  /// again by this rule.
  final bool initiallyMasked;

  /// The text style; the body style by default.
  final TextStyle? style;

  @override
  State<MmCnicText> createState() => _MmCnicTextState();
}

class _MmCnicTextState extends State<MmCnicText> {
  late bool _masked;

  @override
  void initState() {
    super.initState();
    _masked = widget.initiallyMasked;
  }

  @override
  void didUpdateWidget(MmCnicText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cnic != oldWidget.cnic) _masked = widget.initiallyMasked;
  }

  /// What a screen reader says for [groups]: each group of digits spelled
  /// out, and in place of a masked group how many digits it hides, with a
  /// pause between them.
  AttributedString _spoken(BuildContext context, List<String> groups) {
    final strings = MmLocalizations.of(context);
    // The comma of the language: a pause in both.
    final pause = strings.listSeparator;
    final words = StringBuffer();
    final attributes = <StringAttribute>[];
    for (final (index, group) in groups.indexed) {
      if (index > 0) words.write(pause);
      if (group.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39)) {
        final start = words.length;
        words.write(group);
        attributes.add(
          SpellOutStringAttribute(
            range: TextRange(start: start, end: words.length),
          ),
        );
      } else {
        words.write(strings.hiddenDigits(group.length));
      }
    }
    return AttributedString(words.toString(), attributes: attributes);
  }

  @override
  Widget build(BuildContext context) {
    final strings = MmLocalizations.of(context);
    final cnic = widget.cnic;
    final shown = _masked ? cnic.masked : cnic.formatted;
    // The groups between the dashes, as mm_core writes them: digits, or the
    // mask of the hidden ones.
    final groups = shown.split('-');
    final style = context.mm.styleFor(
      shown,
      widget.style ?? Theme.of(context).textTheme.bodyLarge!,
    );
    final last = groups.length - 1;
    return MmWrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MmSpace.s1,
      children: [
        Semantics(
          container: true,
          attributedLabel: _spoken(context, groups),
          excludeSemantics: true,
          // One piece per group, each ending in its dash: a line breaks
          // only between groups, never inside one.
          child: Wrap(
            textDirection: TextDirection.ltr,
            children: [
              for (final (index, group) in groups.indexed)
                Text(
                  index < last ? '$group-' : group,
                  style: style,
                  textDirection: TextDirection.ltr,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _masked = !_masked),
          tooltip: _masked ? strings.showFullCnic : strings.hideFullCnic,
          iconSize: MmIconLabel.scaledSize(context, MmSize.iconLg),
          icon: Icon(_masked ? MmIcons.show : MmIcons.hide),
        ),
      ],
    );
  }
}
