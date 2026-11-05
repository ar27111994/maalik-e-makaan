import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
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
/// shared screen or in a screenshot by accident. While masked, a screen
/// reader hears only the digits that show and how many are hidden
/// ("35202, 7 hidden digits, 1"), never the hidden ones themselves. The
/// number is set in the Latin face in both languages.
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
  /// The digits [Cnic.masked] shows before and after the hidden ones.
  static const _shownAtStart = 5;
  static const _shownAtEnd = 1;

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

  @override
  Widget build(BuildContext context) {
    final strings = MmLocalizations.of(context);
    final cnic = widget.cnic;
    // A dash followed by digits does not allow a line break, so a large
    // style would break the number mid-group; a zero-width space after each
    // dash lets it wrap only between the groups.
    final shown = (_masked ? cnic.masked : cnic.formatted).replaceAll(
      '-',
      '-\u200B',
    );
    // While masked, only the digits on screen are spoken, and how many
    // are hidden between them: "35202, 7 hidden digits, 1".
    final first = cnic.digits.substring(0, _shownAtStart);
    final last = cnic.digits.substring(Cnic.length - _shownAtEnd);
    final hidden = strings.hiddenDigits(
      Cnic.length - _shownAtStart - _shownAtEnd,
    );
    final spoken = _masked ? '$first, $hidden, $last' : cnic.formatted;
    final style = widget.style ?? Theme.of(context).textTheme.bodyLarge!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MmSpace.s1,
      children: [
        Text(
          shown,
          semanticsLabel: spoken,
          textDirection: TextDirection.ltr,
          style: context.mm.styleFor(shown, style),
        ),
        IconButton(
          onPressed: () => setState(() => _masked = !_masked),
          tooltip: _masked ? strings.showFullCnic : strings.hideFullCnic,
          icon: Icon(_masked ? MmIcons.show : MmIcons.hide),
        ),
      ],
    );
  }
}
