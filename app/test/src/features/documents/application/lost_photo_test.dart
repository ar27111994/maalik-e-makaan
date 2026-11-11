import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

/// When the landlord came back from the camera.
final _now = DateTime.utc(2026, 11, 7, 5, 30);

final DocumentOwner _owner = (entity: DocumentEntity.tenant, id: aliRaza.id);

/// The camera opened [ago] before [_now] for Ali Raza's documents.
CameraTarget _opened(
  Duration ago, {
  String userId = testUserId,
  String? portfolioId,
}) => CameraTarget(
  userId: userId,
  portfolioId: portfolioId ?? gulberg.id,
  owner: _owner,
  location: '/tenants/${aliRaza.id}',
  openedAt: _now.subtract(ago),
);

final _photo = ChosenFile(
  name: 'scaled_1234.jpg',
  bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]),
);

/// The parts [recoverLostPhoto] works with.
final class _World {
  final picker = FakeDocumentPicker()..lostPhoto = _photo;
  final documents = FakeDocumentRepository();
  final settings = MemorySettingsStore();
  late final CameraTargetStore targets = SettingsCameraTargetStore(settings);

  Future<LostPhotoOutcome> recover({
    bool android = true,
    List<PortfolioMembership> portfolios = const [gulberg, plaza],
  }) => recoverLostPhoto(
    android: android,
    picker: picker,
    targets: targets,
    documents: documents,
    userId: testUserId,
    portfolios: portfolios,
    now: _now,
  );
}

Matcher _discarded(LostPhotoDiscard reason) =>
    isA<LostPhotoDiscarded>().having((o) => o.reason, 'reason', reason);

/// A picker that keeps nothing, but sees the camera opened again for
/// [newer] while it is asked (the landlord was quicker than the check).
final class _BusyPicker implements DocumentPicker {
  new(this.targets, this.newer);

  final CameraTargetStore targets;
  final CameraTarget newer;

  @override
  Future<ChosenFile?> recoverLostPhoto() async {
    await targets.remember(newer);
    return null;
  }

  @override
  Future<ChosenFile?> takePhoto() => throw UnimplementedError();

  @override
  Future<ChosenFile?> chooseFile() => throw UnimplementedError();
}

void main() {
  group('recoverLostPhoto', () {
    test(
      'a fresh photo comes back to its record, and the target goes',
      () async {
        final world = _World();
        await world.targets.remember(_opened(const Duration(minutes: 3)));
        final outcome = await world.recover();
        expect(
          outcome,
          isA<LostPhotoRecovered>()
              .having((o) => o.photo, 'photo', same(_photo))
              .having(
                (o) => o.target,
                'target',
                _opened(const Duration(minutes: 3)),
              ),
        );
        expect(world.targets.read(), isNull);
        expect(world.picker.calls, ['recoverLostPhoto']);
        // The record was checked, and nothing was uploaded.
        expect(world.documents.calls.map((c) => c.$1), ['ownerTakesDocuments']);
        expect(world.documents.calls.single.$2, [gulberg.id, _owner]);
      },
    );

    test('a photo up to a day old still comes back', () async {
      final world = _World();
      await world.targets.remember(_opened(lostPhotoMaxAge));
      expect(await world.recover(), isA<LostPhotoRecovered>());
    });

    test('a stale photo is let go', () async {
      final world = _World();
      await world.targets.remember(
        _opened(lostPhotoMaxAge + const Duration(minutes: 1)),
      );
      expect(await world.recover(), _discarded(LostPhotoDiscard.stale));
      expect(world.targets.read(), isNull);
      expect(world.documents.calls, isEmpty);
    });

    test(
      'a clock set back a little keeps the photo; more lets it go',
      () async {
        final world = _World();
        await world.targets.remember(_opened(-lostPhotoClockSkew));
        expect(await world.recover(), isA<LostPhotoRecovered>());
        final moved = _World();
        await moved.targets.remember(
          _opened(-lostPhotoClockSkew - const Duration(seconds: 1)),
        );
        expect(await moved.recover(), _discarded(LostPhotoDiscard.stale));
      },
    );

    test('a photo nothing says the record of is let go', () async {
      final world = _World();
      expect(await world.recover(), _discarded(LostPhotoDiscard.missingTarget));
      // One that cannot be read says nothing either.
      final unreadable = _World();
      unreadable.settings.values[AppSettings.cameraTargetKey] = '{';
      expect(
        await unreadable.recover(),
        _discarded(LostPhotoDiscard.missingTarget),
      );
    });

    test("another account's photo is let go", () async {
      final world = _World();
      await world.targets.remember(
        _opened(const Duration(minutes: 3), userId: 'someone-else'),
      );
      expect(await world.recover(), _discarded(LostPhotoDiscard.otherUser));
      expect(world.targets.read(), isNull);
    });

    test('a record the member can no longer add to is let go', () async {
      // They left the portfolio.
      final left = _World();
      await left.targets.remember(_opened(const Duration(minutes: 3)));
      expect(
        await left.recover(portfolios: const [plaza]),
        _discarded(LostPhotoDiscard.unreachable),
      );
      expect(left.targets.read(), isNull);
      // They only view it now.
      final viewer = _World();
      await viewer.targets.remember(_opened(const Duration(minutes: 3)));
      expect(
        await viewer.recover(portfolios: const [gulbergAsViewer, plaza]),
        _discarded(LostPhotoDiscard.unreachable),
      );
      // The record is gone, archived or voided, or hidden from them.
      final gone = _World();
      gone.documents.closedOwners.add(_owner);
      await gone.targets.remember(_opened(const Duration(minutes: 3)));
      expect(await gone.recover(), _discarded(LostPhotoDiscard.unreachable));
      expect(gone.targets.read(), isNull);
    });

    test('a record that cannot be checked (offline) keeps its photo', () async {
      final world = _World();
      world.documents.ownerFailure = const NetworkFailure();
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      expect(await world.recover(), isA<LostPhotoRecovered>());
    });

    testWidgets('a record check with no answer keeps its photo', (
      tester,
    ) async {
      final world = _World();
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      world.documents.gate.close();
      LostPhotoOutcome? outcome;
      unawaited(world.recover().then((o) => outcome = o));
      await tester.pump(lostPhotoCheckLimit - const Duration(milliseconds: 1));
      expect(outcome, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(outcome, isA<LostPhotoRecovered>());
      // An answer after the limit changes nothing.
      world.documents.closedOwners.add(_owner);
      world.documents.gate.open();
      await tester.pump();
      expect(outcome, isA<LostPhotoRecovered>());
    });

    test(
      'a device that cannot forget the target still gets its photo',
      () async {
        final world = _World();
        await world.targets.remember(_opened(const Duration(minutes: 3)));
        world.settings.writeFailure = Exception('read-only');
        expect(await world.recover(), isA<LostPhotoRecovered>());
        // Left behind, for the next camera to replace.
        expect(world.targets.read(), _opened(const Duration(minutes: 3)));
        // Nor does a failure, or no photo, end in an error.
        world.picker.lostFailure = const RejectedFailure(
          'picker_access_denied',
        );
        expect(await world.recover(), isA<LostPhotoFailed>());
        expect(await world.recover(), isA<NoLostPhoto>());
        expect(await world.recover(android: false), isA<NoLostPhoto>());
      },
    );

    test("the camera's failure is passed on, and the target goes", () async {
      final world = _World()
        ..picker.lostPhoto = null
        ..picker.lostFailure = const RejectedFailure('picker_access_denied');
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      expect(
        await world.recover(),
        isA<LostPhotoFailed>().having(
          (o) => o.failure,
          'failure',
          const RejectedFailure('picker_access_denied'),
        ),
      );
      expect(world.targets.read(), isNull);
    });

    test('no photo: a target left behind goes', () async {
      final world = _World()..picker.lostPhoto = null;
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      expect(await world.recover(), isA<NoLostPhoto>());
      expect(world.targets.read(), isNull);
      expect(world.documents.calls, isEmpty);
    });

    test('off Android the camera is not asked; a target left goes', () async {
      final world = _World();
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      expect(await world.recover(android: false), isA<NoLostPhoto>());
      expect(world.picker.calls, isEmpty);
      expect(world.targets.read(), isNull);
      // Without a target nothing is written.
      world.settings.writeFailure = Exception('read-only');
      expect(await world.recover(android: false), isA<NoLostPhoto>());
    });

    test('a camera opened again meanwhile keeps its own target', () async {
      final world = _World();
      final newer = _opened(Duration.zero);
      final picker = _BusyPicker(world.targets, newer);
      await world.targets.remember(_opened(const Duration(minutes: 3)));
      final outcome = await recoverLostPhoto(
        android: true,
        picker: picker,
        targets: world.targets,
        documents: world.documents,
        userId: testUserId,
        portfolios: const [gulberg],
        now: _now,
      );
      expect(outcome, isA<NoLostPhoto>());
      expect(world.targets.read(), newer);
    });
  });

  group('lostPhotoProvider', () {
    test('Android is the platform that loses photos', () {
      final container = containerFor(TestApp());
      expect(container.read(cameraLosesPhotosProvider), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(containerFor(TestApp()).read(cameraLosesPhotosProvider), isFalse);
    });

    test('looks once; a photo held waits for its record until taken', () async {
      final app = TestApp();
      app.picker.lostPhoto = _photo;
      await app.settings.setString(
        AppSettings.cameraTargetKey,
        CameraTarget(
          userId: testUserId,
          portfolioId: gulberg.id,
          owner: _owner,
          location: '/tenants/${aliRaza.id}',
          openedAt: DateTime.now().toUtc(),
        ).toJson(),
      );
      final container = containerFor(app);
      listen(container, lostPhotoProvider);
      final lost = container.read(lostPhotoProvider.notifier);
      final outcome = await lost.look(
        userId: testUserId,
        portfolios: const [gulberg],
      );
      expect(outcome, isA<LostPhotoRecovered>());
      // Not held until the landlord is on the way to its record.
      expect(container.read(lostPhotoProvider), isNull);
      final list = (portfolioId: gulberg.id, owner: _owner);
      lost.hold(list, _photo);
      expect(container.read(lostPhotoProvider), (list: list, photo: _photo));
      // Once a run: the plugin hands a photo over once.
      app.picker.lostPhoto = _photo;
      expect(
        await lost.look(userId: testUserId, portfolios: const [gulberg]),
        isA<NoLostPhoto>(),
      );
      expect(app.picker.calls, ['recoverLostPhoto']);
      // Another record's section finds nothing; its own takes it, once.
      expect(lost.take((portfolioId: plaza.id, owner: _owner)), isNull);
      expect(lost.take(list), same(_photo));
      expect(lost.take(list), isNull);
      expect(container.read(lostPhotoProvider), isNull);
    });

    test('signing out lets go of a photo still waiting', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, lostPhotoProvider);
      final list = (portfolioId: gulberg.id, owner: _owner);
      container.read(lostPhotoProvider.notifier).hold(list, _photo);
      expect(container.read(lostPhotoProvider), isNotNull);
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(container.read(lostPhotoProvider), isNull);
    });
  });
}
