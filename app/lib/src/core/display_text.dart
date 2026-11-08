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

/// [text], the landlord's own words (a name), ready to be put into a
/// sentence of the UI running in [direction]: kept in its own direction
/// ([MmSemantics.isolated]), so "2026 (signed)" keeps its order inside an
/// Urdu sentence and an Urdu name inside an English one.
String inSentence(String text, TextDirection direction) =>
    MmSemantics.isolated(text, direction);

/// [amount], a formatted rupee amount ("Rs 1,25,000", "1,25,000 روپے"),
/// free to wrap between its figures and its currency word where a line is
/// too narrow for both: for the title of a list row (an `MmListTile`).
/// The money format keeps them together with a no-break space, but at 200%
/// text an Urdu amount and its "روپے" can be wider than a list row, which
/// would then break inside the word or the figures; the figures themselves
/// never break. mm_ui's badges and receipt seal loosen their own breaks
/// only where they must (`MmStatusBadge`, `MmReceipt`): give them the
/// amount as it is.
String wrappableAmount(String amount) => amount.replaceAll('\u00A0', ' ');

/// [number], a receipt number ("MM-2026-00041"), with a place to break
/// after each dash, for a list row's subtitle. A dash before figures is no
/// place to break (it could be a minus sign), so the whole number is one
/// word: at large text sizes it would otherwise be cut mid-figure
/// ("MM-2026-0003" / "8"); with it, it wraps as "MM-2026-" / "00038".
/// `MmReceipt` does this itself for its seal.
String breakableNumber(String number) => number.replaceAll('-', '-\u200B');

/// [text], a sentence or line the app builds (from its own words and the
/// landlord's data), ready to show in a UI running in [direction], where
/// it is shown as the landlord's text (an `MmListTile`'s title or
/// subtitle).
///
/// Those decide a text's direction by its first letter and keep it apart
/// in that direction ([MmSemantics.isolated]): an Urdu sentence that starts
/// with a name typed in English ("Ali Raza، Ground floor: …") would be
/// laid out left to right, its words and punctuation out of order. Kept in
/// [direction]'s own isolate here, the sentence reads in the UI's order
/// whatever its first letter is. Isolate the landlord's parts inside it
/// with [inSentence].
///
/// For display only: the database refuses bidi isolates.
///
/// A sentence whose only letters are the landlord's, each isolated with
/// [inSentence] ("Shop 3، Saddar Plaza" in Urdu), or with no letter at all
/// (a date, an amount), runs with the paragraph already: it is left as it
/// is.
String appText(String text, TextDirection direction) {
  final own = MmSemantics.firstStrongDirection(text);
  if (own == null || own == direction) return text;
  return direction == TextDirection.rtl
      ? '\u2067$text\u2069'
      : '\u2066$text\u2069';
}
