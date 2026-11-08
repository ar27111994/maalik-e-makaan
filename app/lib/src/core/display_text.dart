import 'package:flutter/widgets.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The separator between the parts of a detail line ("0300 1234567 · Son of
/// Ahmed Raza"): a no-break space before the dot keeps it at the end of a
/// line, so a wrapped line never starts with it.
const String detailSeparator = '\u00A0\u00B7 ';

/// [parts] joined into one detail line with [detailSeparator].
String detailLine(Iterable<String> parts) => parts.join(detailSeparator);

/// [email] with a place to break after its "@". An address has no break of
/// its own, so at large text sizes it would otherwise be cut mid-word
/// ("kam" / "ran@example.co" / "m"); with it, it wraps as "kamran@" /
/// "example.com". Text without an "@" is returned unchanged.
String breakableEmail(String email) => email.replaceFirst('@', '@\u200B');

/// [phone] as it is shown in a detail line: its national format, kept left
/// to right in the UI's [direction], so its digit groups are not reversed
/// in the Urdu UI. Its space stays a place to break: at large text sizes a
/// number too long for its line wraps between its groups, not inside one.
String phoneLabel(PhoneNumber phone, TextDirection direction) =>
    MmSemantics.isolated(phone.national, direction);
