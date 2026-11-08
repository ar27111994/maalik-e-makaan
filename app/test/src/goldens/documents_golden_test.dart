@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/tenancy_list.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_detail_screen.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// A tenant's documents, as the tenant screen shows them under its details.
Widget _tenantDocuments() => MmPage(
  title: 'Ali Raza',
  body: DocumentsSection(
    owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
  ),
);

/// A tenant with no documents yet.
Widget _noDocuments() => MmPage(
  title: 'Indus Tech (Pvt) Ltd',
  body: DocumentsSection(
    owner: (entity: DocumentEntity.tenant, id: techCorp.id),
  ),
);

/// The tenant screen as the app shows it, with the tenancies and the
/// documents under the details (as `app_router.dart` puts them).
Widget _tenantScreen() => TenantDetailScreen(
  tenantId: aliRaza.id,
  extras: (tenant) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TenancyList(tenantId: tenant.id),
      const SizedBox(height: MmSpace.s8),
      DocumentsSection(
        owner: (entity: DocumentEntity.tenant, id: tenant.id),
        canAdd: !tenant.archived,
      ),
    ],
  ),
);

/// Ali Raza's documents, with one of a long kind: the rent registration
/// slip, a HEIC photo.
TestApp _withRegistration() {
  final app = TestApp();
  app.documents
      .documentsOf(cnicFrontScan.owner)
      .add(
        Document(
          id: '0192d0c4-6666-7000-8000-000000000009',
          owner: cnicFrontScan.owner,
          kind: DocumentKind.rentRegistration,
          storagePath:
              '${gulberg.id}/tenant/${aliRaza.id}/'
              '0192d0c4-6666-7000-8000-000000000009.heic',
          fileName: 'Registration slip, Gulberg office',
          fileType: DocumentFileType.heic,
          sizeBytes: 1258291,
          createdAt: '2026-10-30T09:00:00+00:00',
        ),
      );
  return app;
}

Future<void> _tapTile(WidgetTester tester) async {
  await tester.tap(find.byType(MmListTile).first);
  await tester.pumpAndSettle();
}

Future<void> _openAdd(WidgetTester tester) async {
  final add = find.descendant(
    of: find.byType(MmSectionHeader),
    matching: find.byType(TextButton),
  );
  await tester.ensureVisible(add.last);
  await tester.tap(add.last);
  await tester.pumpAndSettle();
}

Future<void> _addPhoto(WidgetTester tester) async {
  await _openAdd(tester);
  // The first choice: the camera.
  await tester.tap(find.byIcon(MmIcons.camera));
  await tester.pumpAndSettle();
  // The preview decodes outside the test's fake time.
  final preview = find.byType(Image);
  await tester.runAsync(
    () => precacheImage(
      tester.widget<Image>(preview).image,
      tester.element(preview),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseFile(WidgetTester tester) async {
  await _openAdd(tester);
  await tester.tap(find.byIcon(MmIcons.attach));
  await tester.pumpAndSettle();
}

Future<void> _takePhoto(WidgetTester tester) async {
  await _openAdd(tester);
  await tester.tap(find.byIcon(MmIcons.camera));
  await tester.pumpAndSettle();
}

Future<void> _edit(WidgetTester tester) async {
  await _tapTile(tester);
  await tester.tap(find.byIcon(MmIcons.edit));
  await tester.pumpAndSettle();
}

Future<void> _delete(WidgetTester tester) async {
  await _tapTile(tester);
  final delete = find.byIcon(MmIcons.delete);
  await tester.ensureVisible(delete);
  await tester.tap(delete);
  await tester.pumpAndSettle();
}

void main() {
  screenGoldenEveryVariant(
    'documents',
    _tenantDocuments,
    app: _withRegistration,
    sizes: {MmVariant.largeText: const Size(360, 1700)},
  );

  screenGoldenEveryVariant(
    'documents_empty',
    _noDocuments,
    sizes: {MmVariant.largeText: const Size(360, 1100)},
  );

  screenGoldenEveryVariant(
    'documents_error',
    _tenantDocuments,
    app: () => TestApp()..documents.readFailure = const NetworkFailure(),
    sizes: {MmVariant.largeText: const Size(360, 1400)},
  );

  screenGoldenEveryVariant(
    'document_sheet',
    _tenantDocuments,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _tapTile,
  );

  screenGoldenEveryVariant(
    'document_edit',
    _tenantDocuments,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _edit,
  );

  screenGoldenEveryVariant(
    'document_delete',
    _tenantDocuments,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _delete,
  );

  screenGoldenEveryVariant(
    'add_document_choice',
    _tenantDocuments,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _openAdd,
  );

  screenGoldenEveryVariant(
    'add_document_sheet',
    _tenantDocuments,
    size: const Size(360, 1200),
    sizes: {MmVariant.largeText: const Size(360, 2600)},
    act: _addPhoto,
  );

  screenGoldenEveryVariant(
    'add_document_type_refused',
    _tenantDocuments,
    app: () => TestApp()
      ..picker.file = ChosenFile(
        name: 'cnic.gif',
        bytes: Uint8List.fromList('GIF89a'.codeUnits),
      ),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _chooseFile,
  );

  screenGoldenEveryVariant(
    'add_document_too_large',
    _tenantDocuments,
    app: () =>
        TestApp()..picker.failure = const RejectedFailure('file_too_large'),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: _takePhoto,
  );

  screenGoldenEveryVariant(
    'tenant_detail_records',
    _tenantScreen,
    size: const Size(360, 1750),
    sizes: {
      MmVariant.largeText: const Size(360, 3700),
      MmVariant.urdu: const Size(360, 2300),
    },
  );
}
