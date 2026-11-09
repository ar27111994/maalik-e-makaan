import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [link] in another app (WhatsApp, the phone, a government portal)
/// and says whether it could. Tests replace it.
typedef LinkOpener = Future<bool> Function(Uri link);

final linkOpenerProvider = Provider<LinkOpener>((ref) => openExternally);

/// Opens [link] in another app with [launch] (url_launcher's [launchUrl] by
/// default) and answers false when no app can take it.
///
/// On Android url_launcher does not answer false for that: it throws a
/// [PlatformException] (`ACTIVITY_NOT_FOUND`, for example a `tel:` link on a
/// tablet without a phone app). Callers show their own message on false, so
/// the exception becomes false here rather than escaping unseen.
Future<bool> openExternally(
  Uri link, {
  Future<bool> Function(Uri link, {LaunchMode mode}) launch = launchUrl,
}) async {
  try {
    return await launch(link, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

/// A WhatsApp link that opens a chat with [message] ready to send, to a
/// contact the user picks (or to [phoneDigits], the number without `+`).
Uri whatsAppLink(String message, {String? phoneDigits}) => Uri.https(
  'wa.me',
  phoneDigits == null ? '/' : '/$phoneDigits',
  {'text': message},
);

/// Puts [text] on the clipboard.
Future<void> copyText(String text) =>
    Clipboard.setData(ClipboardData(text: text));
