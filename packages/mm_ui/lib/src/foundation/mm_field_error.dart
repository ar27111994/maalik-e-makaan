import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';

/// The error line below a field: the error icon and [message] in the
/// overdue colour, so the error never rests on colour alone, announced as a
/// live region. The icon grows with the text (see [MmIconLabel]) and is
/// hidden from assistive technology.
///
/// Internal to mm_ui: the fields of every family use it, in place of their
/// helper text while they have an error.
class MmFieldError extends StatelessWidget {
  /// Shows [message].
  const new(this.message, {super.key});

  /// What is wrong and how to fix it.
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MmIconLabel(
      icon: MmIcons.error,
      label: message,
      style: Theme.of(context).inputDecorationTheme.errorStyle!,
      iconColor: context.mm.colors.overdue,
    ),
  );
}
