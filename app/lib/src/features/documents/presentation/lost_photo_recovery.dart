import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
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
/// portfolio), whose documents section opens it in the add-document sheet;
/// a failure the camera met says so as any failure does. A photo let go
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
    final outcome = await ref
        .read(lostPhotoProvider.notifier)
        .look(userId: userId, portfolios: portfolios);
    if (!mounted) return;
    switch (outcome) {
      case LostPhotoRecovered(:final target):
        // The portfolio the photo was taken in, as it was then.
        if (ref.read(currentPortfolioProvider).value?.id !=
            target.portfolioId) {
          await ref
              .read(selectedPortfolioProvider(userId).notifier)
              .select(target.portfolioId);
          if (!mounted) return;
        }
        GoRouter.of(context).go(target.location);
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

  @override
  Widget build(BuildContext context) => widget.child;
}
