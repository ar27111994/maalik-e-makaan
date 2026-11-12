import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

import '../../../../support/fakes.dart';

final _target = CameraTarget(
  userId: testUserId,
  portfolioId: gulberg.id,
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
  location: '/tenants/${aliRaza.id}',
  openedAt: DateTime.utc(2026, 11, 7, 5, 30),
);

/// [_target]'s JSON with [changes] (a null value leaves a field out).
String _json(Map<String, Object?> changes) {
  final fields = <String, Object?>{
    ...(jsonDecode(_target.toJson()) as Map<String, Object?>),
    ...changes,
  }..removeWhere((_, value) => value == null);
  return jsonEncode(fields);
}

void main() {
  group('CameraTarget', () {
    test('is written as JSON and read back the same', () {
      final json = _target.toJson();
      expect(jsonDecode(json), {
        'user': testUserId,
        'portfolio': gulberg.id,
        'entity': 'tenant',
        'id': aliRaza.id,
        'location': '/tenants/${aliRaza.id}',
        'opened_at': '2026-11-07T05:30:00.000Z',
      });
      final read = CameraTarget.tryParse(json);
      expect(read, _target);
      expect(read.hashCode, _target.hashCode);
      // The same moment written in another zone is the same target.
      final elsewhere = CameraTarget.tryParse(
        _json({'opened_at': '2026-11-07T10:30:00+05:00'}),
      );
      expect(elsewhere, _target);
      expect(elsewhere!.openedAt.isUtc, isTrue);
    });

    test('anything else is not a target', () {
      for (final json in [
        'not json',
        '[]',
        '"a string"',
        _json({'user': null}),
        _json({'user': ''}),
        _json({'portfolio': ''}),
        _json({'id': ''}),
        _json({'id': 7}),
        _json({'entity': 'car'}),
        _json({'opened_at': 'yesterday'}),
        _json({'location': 'tenants/x'}),
        _json({'location': '//elsewhere.example/tenants'}),
        _json({'location': 'https://elsewhere.example/tenants'}),
      ]) {
        expect(CameraTarget.tryParse(json), isNull, reason: json);
      }
    });

    test('differs by every field', () {
      CameraTarget changed({
        String? userId,
        String? portfolioId,
        DocumentOwner? owner,
        String? location,
        DateTime? openedAt,
      }) => CameraTarget(
        userId: userId ?? _target.userId,
        portfolioId: portfolioId ?? _target.portfolioId,
        owner: owner ?? _target.owner,
        location: location ?? _target.location,
        openedAt: openedAt ?? _target.openedAt,
      );
      expect(changed(), _target);
      for (final other in [
        changed(userId: 'someone else'),
        changed(portfolioId: plaza.id),
        changed(owner: (entity: DocumentEntity.lease, id: aliRaza.id)),
        changed(location: '/tenants'),
        changed(openedAt: _target.openedAt.add(const Duration(seconds: 1))),
      ]) {
        expect(other, isNot(_target));
      }
    });
  });

  test('only paths in the app are locations to go back to', () {
    expect(isAppLocation('/tenants/abc'), isTrue);
    expect(isAppLocation('/money/leases/l1/receipts/p1'), isTrue);
    expect(isAppLocation('/'), isTrue);
    expect(isAppLocation(''), isFalse);
    expect(isAppLocation('tenants'), isFalse);
    expect(isAppLocation('//elsewhere.example'), isFalse);
    expect(isAppLocation('https://elsewhere.example/'), isFalse);
  });

  group('SettingsCameraTargetStore', () {
    late MemorySettingsStore settings;
    late CameraTargetStore store;

    setUp(() {
      settings = MemorySettingsStore();
      final container = ProviderContainer.test(
        overrides: [settingsStoreProvider.overrideWithValue(settings)],
      );
      store = container.read(cameraTargetStoreProvider);
    });

    test('keeps one target in the preferences, and forgets it', () async {
      expect(store.read(), isNull);
      await store.remember(_target);
      expect(settings.values[AppSettings.cameraTargetKey], _target.toJson());
      expect(store.read(), _target);
      final later = CameraTarget(
        userId: testUserId,
        portfolioId: plaza.id,
        owner: (entity: DocumentEntity.unit, id: groundFloor.id),
        location: '/properties/${gulbergHouse.id}/units/${groundFloor.id}',
        openedAt: DateTime.utc(2026, 11, 7, 6),
      );
      await store.remember(later);
      expect(store.read(), later);
      await store.forget();
      expect(store.read(), isNull);
      expect(settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    test('forgets a target only while it is still the one kept', () async {
      await store.remember(_target);
      final newer = CameraTarget(
        userId: testUserId,
        portfolioId: gulberg.id,
        owner: _target.owner,
        location: _target.location,
        openedAt: _target.openedAt.add(const Duration(minutes: 2)),
      );
      await store.remember(newer);
      await store.forgetIfStill(_target);
      expect(store.read(), newer);
      await store.forgetIfStill(newer);
      expect(store.read(), isNull);
    });

    test('a target that cannot be read is none', () async {
      settings.values[AppSettings.cameraTargetKey] = '{"user":';
      expect(store.read(), isNull);
      await store.remember(_target);
      expect(store.read(), _target);
    });

    test('a device that cannot write says so', () async {
      settings.writeFailure = Exception('disk full');
      await expectLater(store.remember(_target), throwsException);
      expect(store.read(), isNull);
    });
  });
}
