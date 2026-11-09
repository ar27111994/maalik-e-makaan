import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:share_plus/share_plus.dart';

/// A finished document (a PDF, or a CSV file) to hand on: its bytes, the
/// file name it is saved under (whose extension says what it is) and its
/// title.
typedef SharedDocument = ({Uint8List bytes, String fileName, String title});

/// Hands a document to the platform: the share sheet on phones (WhatsApp,
/// e-mail, files), and on the web the browser's share sheet where it has
/// one, otherwise a download. Tests replace it.
typedef DocumentSharer = Future<void> Function(SharedDocument document);

final Provider<DocumentSharer> documentSharerProvider =
    Provider<DocumentSharer>(
      (ref) => (document) async {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  document.bytes,
                  mimeType: documentMimeType(document.fileName),
                  name: document.fileName,
                ),
              ],
              fileNameOverrides: [document.fileName],
              title: document.title,
            ),
          );
        } on Exception catch (error) {
          throw UnexpectedFailure(error);
        }
      },
    );

/// The media type of a file named [fileName]: a CSV file or a PDF.
String documentMimeType(String fileName) =>
    fileName.toLowerCase().endsWith('.csv') ? 'text/csv' : 'application/pdf';

/// Makes a document in a language, for [ShareDocumentSheet].
typedef DocumentMaker = Future<SharedDocument> Function(
  DocumentLanguage language,
);

/// Choosing the language of a receipt or statement and sharing it: the
/// landlord writes to a tenant in their language, whatever the app's.
class ShareDocumentSheet extends ConsumerStatefulWidget {
  const new({required this.make, super.key});

  final DocumentMaker make;

  @override
  ConsumerState<ShareDocumentSheet> createState() => _ShareDocumentSheetState();
}

class _ShareDocumentSheetState extends ConsumerState<ShareDocumentSheet>
    with CommandState {
  late DocumentLanguage _language =
      Localizations.localeOf(context).languageCode == 'ur'
      ? DocumentLanguage.urdu
      : DocumentLanguage.english;

  Future<void> _share() async {
    final done = await runCommand(() async {
      final SharedDocument document;
      try {
        document = await widget.make(_language);
      } on AppFailure {
        rethrow;
      } on Object catch (error) {
        throw UnexpectedFailure(error);
      }
      await ref.read(documentSharerProvider)(document);
    });
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmRadioGroup<DocumentLanguage>(
          label: l10n.documentLanguageLabel,
          options: [
            MmOption(
              value: DocumentLanguage.english,
              label: l10n.languageEnglish,
            ),
            MmOption(value: DocumentLanguage.urdu, label: l10n.languageUrdu),
          ],
          value: _language,
          onChanged: (language) {
            if (language != null) setState(() => _language = language);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.shareDocumentAction,
          icon: MmIcons.share,
          busy: busy,
          onPressed: _share,
        ),
      ],
    );
  }
}

/// Opens [ShareDocumentSheet] titled [title].
Future<void> showShareDocument(
  BuildContext context, {
  required String title,
  required DocumentMaker make,
}) => showMmSheet<void>(
  context,
  title: title,
  builder: (_) => ShareDocumentSheet(make: make),
);
