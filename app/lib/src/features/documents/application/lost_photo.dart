import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';

/// How old a remembered camera target may be for its photo to come back.
///
/// Android starts the app again as soon as the landlord leaves the camera,
/// so a real recovery is seconds or minutes old. A day still covers a
/// landlord called away just after taking the photo, who opens the app
/// again that evening; anything older is a photo they no longer have in
/// mind (of someone's CNIC, perhaps on a phone that has changed hands
/// since), which should not appear unasked on a record days later.
const lostPhotoMaxAge = Duration(days: 1);

/// How far "in the future" a remembered camera target may be: a phone
/// whose clock the network set back a little while the app restarted
/// keeps the photo; one whose clock was moved by more does not.
const lostPhotoClockSkew = Duration(minutes: 5);

/// What became of a photo the camera took after Android closed the app.
sealed class LostPhotoOutcome {
  const new();
}

/// There was no photo to recover, or the platform never loses one.
final class NoLostPhoto extends LostPhotoOutcome {
  const new();
}

/// The photo came back, for [target]'s record.
final class LostPhotoRecovered extends LostPhotoOutcome {
  const new({required this.target, required this.photo});

  final CameraTarget target;
  final ChosenFile photo;
}

/// Why a photo that came back was let go.
enum LostPhotoDiscard {
  /// Nothing (or nothing readable) says which record it was for.
  missingTarget,

  /// Another account opened the camera.
  otherUser,

  /// The camera opened more than [lostPhotoMaxAge] ago (or, by the
  /// device's clock, more than [lostPhotoClockSkew] in the future).
  stale,

  /// The member no longer adds documents to the record: they left the
  /// portfolio, their role changed, or the record is gone.
  unreachable,
}

/// The photo came back but was let go, unseen and not uploaded.
final class LostPhotoDiscarded extends LostPhotoOutcome {
  const new(this.reason);

  final LostPhotoDiscard reason;
}

/// Taking the photo had failed before the app closed.
final class LostPhotoFailed extends LostPhotoOutcome {
  const new(this.failure);

  final AppFailure failure;
}

/// Looks for a photo the camera took after Android closed the app, and
/// decides what becomes of it.
///
/// Only Android loses photos ([android]); elsewhere the picker is not
/// asked, and a target left behind (the app was closed some other way) is
/// forgotten. On Android the photo comes back to its record when the
/// target [userId] remembered for it ([targets]) is younger than
/// [lostPhotoMaxAge], and the member may still add documents to that
/// record: they belong to its portfolio ([portfolios]) with a role that
/// adds documents, and [documents] still finds the record. When the
/// record cannot be checked (no connection), the photo is kept: the
/// database checks the record again when the document is uploaded.
///
/// Whatever happens, the target is forgotten, unless a camera opened since
/// kept a new one.
Future<LostPhotoOutcome> recoverLostPhoto({
  required bool android,
  required DocumentPicker picker,
  required CameraTargetStore targets,
  required DocumentRepository documents,
  required String userId,
  required List<PortfolioMembership> portfolios,
  required DateTime now,
}) async {
  final target = targets.read();
  Future<void> forgetTarget() async {
    if (target != null) await targets.forgetIfStill(target);
  }

  if (!android) {
    await forgetTarget();
    return const NoLostPhoto();
  }
  final ChosenFile? photo;
  try {
    photo = await picker.recoverLostPhoto();
  } on AppFailure catch (failure) {
    await forgetTarget();
    return LostPhotoFailed(failure);
  }
  await forgetTarget();
  if (photo == null) return const NoLostPhoto();
  if (target == null) {
    return const LostPhotoDiscarded(LostPhotoDiscard.missingTarget);
  }
  if (target.userId != userId) {
    return const LostPhotoDiscarded(LostPhotoDiscard.otherUser);
  }
  final age = now.difference(target.openedAt);
  if (age < -lostPhotoClockSkew || age > lostPhotoMaxAge) {
    return const LostPhotoDiscarded(LostPhotoDiscard.stale);
  }
  final membership = portfolios
      .where((portfolio) => portfolio.id == target.portfolioId)
      .firstOrNull;
  if (membership == null || !membership.role.recordsDocuments) {
    return const LostPhotoDiscarded(LostPhotoDiscard.unreachable);
  }
  bool exists;
  try {
    exists = await documents.ownerExists(target.portfolioId, target.owner);
  } on AppFailure {
    exists = true;
  }
  if (!exists) return const LostPhotoDiscarded(LostPhotoDiscard.unreachable);
  return LostPhotoRecovered(target: target, photo: photo);
}

/// Whether the camera can lose a photo here: Android may close the app
/// behind the camera; iOS and the web never lose one. Tests set it.
final Provider<bool> cameraLosesPhotosProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// A photo that came back, and the list of the record it was taken for.
typedef RecoveredPhoto = ({DocumentList list, ChosenFile photo});

/// The photo that came back after Android closed the app, until the
/// documents section of its record opens it in the add-document sheet;
/// null when none waits.
final NotifierProvider<LostPhotoController, RecoveredPhoto?> lostPhotoProvider =
    NotifierProvider<LostPhotoController, RecoveredPhoto?>(
      LostPhotoController.new,
    );

/// Looks for a lost photo once, keeps it for its record, and hands it to
/// that record's documents section.
final class LostPhotoController extends Notifier<RecoveredPhoto?> {
  /// Whether this run of the app has looked: a lost photo can only be
  /// lost by an earlier run, and the plugin hands it over once.
  bool _looked = false;

  @override
  RecoveredPhoto? build() {
    // A photo is its taker's: signing out (or in as someone else) lets go
    // of one still waiting.
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next) state = null;
    });
    return null;
  }

  /// Looks for a lost photo the first time it is called in this run of
  /// the app (see [recoverLostPhoto]), for [userId] in [portfolios], and
  /// keeps one that came back for its record ([take]). Later calls find
  /// [NoLostPhoto].
  Future<LostPhotoOutcome> look({
    required String userId,
    required List<PortfolioMembership> portfolios,
  }) async {
    if (_looked) return const NoLostPhoto();
    _looked = true;
    final outcome = await recoverLostPhoto(
      android: ref.read(cameraLosesPhotosProvider),
      picker: ref.read(documentPickerProvider),
      targets: ref.read(cameraTargetStoreProvider),
      documents: ref.read(documentRepositoryProvider),
      userId: userId,
      portfolios: portfolios,
      now: clock.now(),
    );
    if (outcome case LostPhotoRecovered(:final target, :final photo)
        when ref.mounted) {
      hold((portfolioId: target.portfolioId, owner: target.owner), photo);
    }
    return outcome;
  }

  /// Keeps [photo] until [list]'s documents section takes it.
  void hold(DocumentList list, ChosenFile photo) =>
      state = (list: list, photo: photo);

  /// The photo kept for [list], handed over once; null when none waits
  /// for it.
  ChosenFile? take(DocumentList list) {
    final waiting = state;
    if (waiting == null || waiting.list != list) return null;
    state = null;
    return waiting.photo;
  }
}
