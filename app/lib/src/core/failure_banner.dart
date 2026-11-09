import 'package:flutter/material.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:mm_ui/mm_ui.dart';

/// A refusal that belongs to no single field, above a form: an error banner
/// with [failureMessage], announced when it appears, and an optional action
/// that helps ("Send the e-mail again").
class FailureBanner extends StatelessWidget {
  const new({
    required this.failure,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final AppFailure failure;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s4),
    child: MmBanner(
      tone: MmBannerTone.error,
      message: failureMessage(AppLocalizations.of(context), failure),
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
