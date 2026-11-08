import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [link] in another app (WhatsApp, the phone, a government portal)
/// and says whether it could. Tests replace it.
typedef LinkOpener = Future<bool> Function(Uri link);

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) =>
      (link) => launchUrl(link, mode: LaunchMode.externalApplication),
);

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
