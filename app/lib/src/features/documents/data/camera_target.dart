import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

/// The record a camera photo is being taken for, who is taking it, and
/// when the camera opened.
///
/// It is kept on the device while the camera is open: Android may close
/// the app behind the camera (a phone short of memory does), and the photo
/// then comes back only when the app starts again
/// ([DocumentPicker.recoverLostPhoto]), with nothing else to say which
/// record it was for.
@immutable
final class CameraTarget {
  const new({
    required this.userId,
    required this.portfolioId,
    required this.owner,
    required this.location,
    required this.openedAt,
  });

  /// The target [json] describes, as [toJson] writes it; null for anything
  /// else (another version wrote it, or it was changed by hand).
  static CameraTarget? tryParse(String json) {
    try {
      if (jsonDecode(json)
          case {
            'user': final String userId,
            'portfolio': final String portfolioId,
            'entity': final String entity,
            'id': final String id,
            'location': final String location,
            'opened_at': final String openedAt,
          }
          when userId.isNotEmpty && portfolioId.isNotEmpty && id.isNotEmpty) {
        final at = DateTime.tryParse(openedAt);
        if (at == null || !isAppLocation(location)) return null;
        return CameraTarget(
          userId: userId,
          portfolioId: portfolioId,
          owner: (entity: DocumentEntity.parse(entity), id: id),
          location: location,
          openedAt: at.toUtc(),
        );
      }
    } on FormatException {
      // Not JSON, or a record of a kind this version does not know.
    }
    return null;
  }

  /// The signed-in user who opened the camera.
  final String userId;

  final String portfolioId;

  /// The record the photo is for.
  final DocumentOwner owner;

  /// Where the app shows the record (its path, as `Routes` makes it): the
  /// screen to go back to.
  final String location;

  /// When the camera opened.
  final DateTime openedAt;

  /// The target as JSON, for [tryParse].
  String toJson() => jsonEncode({
    'user': userId,
    'portfolio': portfolioId,
    'entity': owner.entity.db,
    'id': owner.id,
    'location': location,
    'opened_at': openedAt.toUtc().toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is CameraTarget &&
      other.userId == userId &&
      other.portfolioId == portfolioId &&
      other.owner == owner &&
      other.location == location &&
      other.openedAt.isAtSameMomentAs(openedAt);

  @override
  int get hashCode => Object.hash(
    userId,
    portfolioId,
    owner,
    location,
    openedAt.microsecondsSinceEpoch,
  );
}

/// Whether [location] is a path in this app ("/tenants/…"), never another
/// site's address.
bool isAppLocation(String location) {
  if (!location.startsWith('/') || location.startsWith('//')) return false;
  final uri = Uri.tryParse(location);
  return uri != null && !uri.hasScheme && !uri.hasAuthority;
}

/// Where the device keeps the [CameraTarget] while the camera is open.
abstract interface class CameraTargetStore {
  /// The target kept, or null: none, or one that cannot be read (which the
  /// next camera's target replaces).
  CameraTarget? read();

  /// Keeps [target] in place of any other. Throws when the device cannot
  /// write it.
  Future<void> remember(CameraTarget target);

  /// Forgets the target kept, readable or not.
  Future<void> forget();
}

/// Forgetting one target and no other.
extension ForgetCameraTarget on CameraTargetStore {
  /// Forgets [target] unless another has been kept since: a camera opened
  /// again in the meantime keeps its own.
  Future<void> forgetIfStill(CameraTarget target) async {
    if (read() == target) await forget();
  }
}

/// [CameraTargetStore] in the device's preferences
/// ([AppSettings.cameraTargetKey]), written before the camera opens:
/// `shared_preferences` finishes writing before it answers.
final class SettingsCameraTargetStore implements CameraTargetStore {
  new(this._settings);

  final SettingsStore _settings;

  @override
  CameraTarget? read() =>
      switch (_settings.getString(AppSettings.cameraTargetKey)) {
        final json? => CameraTarget.tryParse(json),
        null => null,
      };

  @override
  Future<void> remember(CameraTarget target) =>
      _settings.setString(AppSettings.cameraTargetKey, target.toJson());

  @override
  Future<void> forget() => _settings.remove(AppSettings.cameraTargetKey);
}

final Provider<CameraTargetStore> cameraTargetStoreProvider =
    Provider<CameraTargetStore>(
      (ref) => SettingsCameraTargetStore(ref.watch(settingsStoreProvider)),
    );
