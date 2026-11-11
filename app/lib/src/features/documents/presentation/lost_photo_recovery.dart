import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_ui/mm_ui.dart';

/// Brings back a camera photo that Android kept after closing the app
/// behind the camera, around the signed-in frame ([child]).
///
/// Once the user is signed in and their portfolios are known, it looks
/// for one ([LostPhotoController.look]), once per run of the app: not
/// again when the app comes back to the foreground, as a run that was not
/// closed gets its photo from the camera itself. A photo for a record the
/// landlord may still add documents to takes them to that record (in its
/// portfolio), whose documents section opens it in the add-document sheet.
/// The app can be used while the photo's record is checked: a landlord who
/// has moved to another screen (or portfolio) by then is not pulled away,
/// but offered the photo in a snackbar whose action takes them to it. A
/// failure the camera met says so as any failure does. A photo let go
/// ([LostPhotoDiscarded]) is let go quietly: it is old, another account's,
/// or for a record the landlord can no longer add to.
class LostPhotoRecovery extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LostPhotoRecovery> createState() => _LostPhotoRecoveryState();
}

class _LostPhotoRecoveryState extends ConsumerState<LostPhotoRecovery> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(currentPortfolioProvider, (_, current) {
      if (current.value != null) unawaited(_look());
    }, fireImmediately: true);
  }

  Future<void> _look() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final portfolios = ref.read(portfoliosProvider(userId)).value?.value;
    if (portfolios == null) return;
    // Where the landlord is as the look starts.
    final router = GoRouter.of(context);
    final from = _place(router);
    final outcome = await ref
        .read(lostPhotoProvider.notifier)
        .look(userId: userId, portfolios: portfolios);
    if (!mounted) return;
    switch (outcome) {
      case LostPhotoRecovered(:final target, :final photo):
        if (_place(router) == from) {
          await _bringBack(userId, target, photo);
        } else {
          // They moved on while the record was checked: offered, not
          // pulled away from what they are doing.
          final l10n = AppLocalizations.of(context);
          await showMmSnackbar(
            context,
            message: l10n.photoKeptOffer,
            actionLabel: l10n.photoKeptAction,
            onAction: () => unawaited(_bringBack(userId, target, photo)),
          );
        }
      case LostPhotoFailed(:final failure):
        await showMmSnackbar(
          context,
          message: failureMessage(AppLocalizations.of(context), failure),
          tone: MmBannerTone.error,
        );
      case NoLostPhoto() || LostPhotoDiscarded():
        break;
    }
  }

  /// The screen and the portfolio the landlord is in.
  (Uri, String?) _place(GoRouter router) =>
      (router.state.uri, ref.read(currentPortfolioProvider).value?.id);

  /// Takes [userId] to [target]'s record, in the portfolio the photo was
  /// taken in, where its documents section opens [photo] in the
  /// add-document sheet.
  Future<void> _bringBack(
    String userId,
    CameraTarget target,
    ChosenFile photo,
  ) async {
    if (!mounted || ref.read(currentUserIdProvider) != userId) return;
    final router = GoRouter.of(context);
    if (ref.read(currentPortfolioProvider).value?.id != target.portfolioId) {
      try {
        await ref
            .read(selectedPortfolioProvider(userId).notifier)
            .select(target.portfolioId);
      } on Exception {
        // Switched for this run; only the device's note of it failed.
      }
      if (!mounted) return;
    }
    ref.read(lostPhotoProvider.notifier).hold((
      portfolioId: target.portfolioId,
      owner: target.owner,
    ), photo);
    router.go(target.location);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
