import 'dart:async';

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
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

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

/// How long the record of a photo that came back is checked for.
///
/// The landlord can use the app while the check runs, and is taken to the
/// record only if they are still where they were when it started; a check
/// that takes longer is treated as one that could not be made (no
/// connection): the photo is kept, and the database checks the record
/// again when the document is uploaded. One small read takes well under
/// this on a working mobile connection.
const lostPhotoCheckLimit = Duration(seconds: 5);

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
  /// portfolio, their role changed, or the record is gone, archived or
  /// voided.
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
/// adds documents, and [documents] finds the record still taking documents
/// (not gone, archived or voided). When the record cannot be checked (no
/// connection, or no answer within [lostPhotoCheckLimit]), the photo is
/// kept: the database checks the record again when the document is
/// uploaded.
///
/// Whatever happens, the target is forgotten, unless a camera opened since
/// kept a new one. A device that cannot forget it still gets its photo:
/// the target left behind is replaced by the next camera's, or forgotten
/// at a later start.
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
    if (target == null) return;
    try {
      await targets.forgetIfStill(target);
    } on Exception {
      // Left behind: see above. The photo, if any, is handed over once,
      // and must not be lost to a preference that could not be removed.
    }
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
  if (!_recent(target, now)) {
    return const LostPhotoDiscarded(LostPhotoDiscard.stale);
  }
  final membership = portfolios
      .where((portfolio) => portfolio.id == target.portfolioId)
      .firstOrNull;
  if (membership == null || !membership.role.recordsDocuments) {
    return const LostPhotoDiscarded(LostPhotoDiscard.unreachable);
  }
  bool open;
  try {
    open = await documents
        .ownerTakesDocuments(target.portfolioId, target.owner)
        .timeout(lostPhotoCheckLimit);
  } on AppFailure {
    open = true;
  } on TimeoutException {
    open = true;
  }
  if (!open) return const LostPhotoDiscarded(LostPhotoDiscard.unreachable);
  return LostPhotoRecovered(target: target, photo: photo);
}

/// Whether [target]'s camera opened recently enough at [now] for its photo
/// to come back: within [lostPhotoMaxAge], and not more than
/// [lostPhotoClockSkew] in the future.
bool _recent(CameraTarget target, DateTime now) {
  final age = now.difference(target.openedAt);
  return age >= -lostPhotoClockSkew && age <= lostPhotoMaxAge;
}

/// Whether a photo an earlier run of the app lost may still come back to
/// its record: the camera's record kept in [settings] can be read and is
/// recent at [now]. Otherwise [recoverLostPhoto] would let the photo go,
/// so the start-up tidy (`tidyDeviceAtStart`) deletes it with the record
/// at once.
bool lostPhotoMayReturn(SettingsStore settings, DateTime now) {
  final target = SettingsCameraTargetStore(settings).read();
  return target != null && _recent(target, now);
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

/// Looks for a lost photo once, and keeps one that came back for its
/// record until that record's documents section takes it.
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
  /// the app (see [recoverLostPhoto]), for [userId] in [portfolios]. Later
  /// calls find [NoLostPhoto]. A photo that came back is not kept yet: the
  /// caller [hold]s it once the landlord is on its way to the record.
  Future<LostPhotoOutcome> look({
    required String userId,
    required List<PortfolioMembership> portfolios,
  }) {
    if (_looked) return Future.value(const NoLostPhoto());
    _looked = true;
    return recoverLostPhoto(
      android: ref.read(cameraLosesPhotosProvider),
      picker: ref.read(documentPickerProvider),
      targets: ref.read(cameraTargetStoreProvider),
      documents: ref.read(documentRepositoryProvider),
      userId: userId,
      portfolios: portfolios,
      now: clock.now(),
    );
  }

  /// Keeps [photo] until [list]'s documents section takes it: a section
  /// of that record already shown opens it at once.
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
