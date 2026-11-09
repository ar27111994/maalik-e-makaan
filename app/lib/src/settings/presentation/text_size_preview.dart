import 'package:flutter/material.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The text size the phone asks for, as a percentage, with a sample of a
/// tenant's row at that size, so the landlord sees how the app will read.
/// The app follows the phone's setting up to 200%; it has no size of its
/// own, so the explanation says where to change it.
class TextSizePreview extends StatelessWidget {
  const new({super.key});

  /// The sample rent in the preview.
  static const sampleRent = Money.fromRupees(45000);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = MediaQuery.textScalerOf(context).scale(100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.textSizeTitle,
          subtitle: l10n.textSizeBody(percent),
        ),
        const SizedBox(height: MmSpace.s3),
        Semantics(
          label: l10n.textSizePreviewLabel,
          container: true,
          child: MmCard(
            padding: EdgeInsetsDirectional.zero,
            child: MmListTile(
              leading: MmAvatar(name: l10n.textSizeSampleName),
              title: l10n.textSizeSampleName,
              subtitle: l10n.textSizeSampleDetail,
              trailing: const MmAmount(amount: sampleRent),
            ),
          ),
        ),
      ],
    );
  }
}
