import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

final DocumentList _ali = (
  portfolioId: gulberg.id,
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
);

final _scan = PreparedFile(
  name: 'scan',
  bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]),
  type: DocumentFileType.pdf,
  originalSize: 5,
);

/// Ids handed out in turn, so a test knows each attempt's path.
String Function() _ids() {
  var next = 0;
  return () => '0192d0c4-7777-7000-8000-00000000000${++next}';
}

UploadAttempt _attempt() => UploadAttempt(
  portfolioId: gulberg.id,
  owner: _ali.owner,
  file: _scan,
  newId: _ids(),
);

void main() {
  test("lists a record's documents, newest first, and pages", () async {
    final app = TestApp()..documents.pageLimit = 1;
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    expect(container.read(documentsProvider(_ali)).value!.value.items, [
      cnicFrontScan,
    ]);
    final controller = container.read(documentsProvider(_ali).notifier);
    await controller.loadMore();
    expect(container.read(documentsProvider(_ali)).value!.value.items, [
      cnicFrontScan,
      cnicBackScan,
    ]);
    // Nothing more to read.
    await controller.loadMore();
    expect(app.documents.calls.where((c) => c.$1 == 'documents'), hasLength(2));
    expect(app.documents.calls.first.$2, [gulberg.id, _ali.owner, null]);
  });

  test('loading more signs only the new photos', () async {
    final front = Uri.parse('https://files.example/front.jpg?token=1');
    final back = Uri.parse('https://files.example/back.jpg?token=1');
    final app = TestApp()..documents.pageLimit = 1;
    app.documents.thumbnails = {cnicFrontScan.id: front, cnicBackScan.id: back};
    final container = containerFor(app);
    listen(container, documentThumbnailsProvider(_ali));
    await pumpEventQueue();
    expect(await container.read(documentThumbnailsProvider(_ali).future), {
      cnicFrontScan.id: front,
    });
    await container.read(documentsProvider(_ali).notifier).loadMore();
    await pumpEventQueue();
    // The first row keeps its link; only the new photo is signed.
    expect(await container.read(documentThumbnailsProvider(_ali).future), {
      cnicFrontScan.id: front,
      cnicBackScan.id: back,
    });
    expect(
      [
        for (final call in app.documents.calls)
          if (call.$1 == 'thumbnailLinks') call.$2,
      ],
      [
        [cnicFrontScan.id],
        [cnicBackScan.id],
      ],
    );
  });

  test("the cache keeps a record's documents apart", () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final controller = container.read(documentsProvider(_ali).notifier);
    expect(controller.query, 'documents.${gulberg.id}.tenant.${aliRaza.id}');
    final page = container.read(documentsProvider(_ali)).value!.value;
    expect(controller.decode(controller.encode(page)), page);
  });

  test('a file is stored, then recorded, and the list shows it', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final attempt = _attempt();
    expect(attempt.unrecordedPath, isNull);
    final document = await container
        .read(documentsProvider(_ali).notifier)
        .attach(attempt, name: 'Scan', kind: DocumentKind.photo);
    expect(document.storagePath, attempt.upload.storagePath);
    expect(attempt.unrecordedPath, isNull);
    expect(
      container.read(documentsProvider(_ali)).value!.value.items.first,
      document,
    );
    expect(app.documents.calls.map((c) => c.$1), [
      'documents',
      'uploadFile',
      'recordDocument',
      'documents',
    ]);
  });

  test('a retry after a failed insert does not upload again', () async {
    final app = TestApp();
    app.documents.recordFailures.add(const NetworkFailure());
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final controller = container.read(documentsProvider(_ali).notifier);
    final attempt = _attempt();
    await expectLater(
      controller.attach(attempt, name: 'Scan', kind: DocumentKind.photo),
      throwsA(isA<NetworkFailure>()),
    );
    expect(attempt.unrecordedPath, attempt.upload.storagePath);
    await controller.attach(attempt, name: 'Scan', kind: DocumentKind.photo);
    expect(
      app.documents.calls.where((c) => c.$1 == 'uploadFile'),
      hasLength(1),
    );
    expect(attempt.unrecordedPath, isNull);
  });

  test('a file deleted before its row is stored again', () async {
    final app = TestApp();
    app.documents.recordFailures.add(
      const RejectedFailure('document_file_missing'),
    );
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final attempt = _attempt();
    final path = attempt.upload.storagePath;
    await container
        .read(documentsProvider(_ali).notifier)
        .attach(attempt, name: 'Scan', kind: DocumentKind.photo);
    expect(
      app.documents.calls
          .where((c) => c.$1 == 'uploadFile')
          .map((c) => c.$2.first),
      [path, path],
    );
  });

  test('a file queued for deletion is stored again under new ids', () async {
    final app = TestApp();
    app.documents.recordFailures.add(
      const RejectedFailure('document_file_pending_deletion'),
    );
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final attempt = _attempt();
    final first = attempt.upload.storagePath;
    final document = await container
        .read(documentsProvider(_ali).notifier)
        .attach(attempt, name: 'Scan', kind: DocumentKind.photo);
    expect(document.storagePath, isNot(first));
    expect(document.id, '0192d0c4-7777-7000-8000-000000000002');
    expect(
      app.documents.calls
          .where((c) => c.$1 == 'uploadFile')
          .map((c) => c.$2.first),
      [first, document.storagePath],
    );
  });

  test('other refusals, and a second refusal, reach the caller', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final controller = container.read(documentsProvider(_ali).notifier);
    app.documents.recordFailures.add(
      const RejectedFailure('document_entity_not_found'),
    );
    await expectLater(
      controller.attach(_attempt(), name: 'S', kind: DocumentKind.photo),
      throwsA(isA<RejectedFailure>()),
    );
    app.documents.recordFailures.addAll(const [
      RejectedFailure('document_file_pending_deletion'),
      RejectedFailure('document_file_pending_deletion'),
    ]);
    await expectLater(
      controller.attach(_attempt(), name: 'S', kind: DocumentKind.photo),
      throwsA(
        isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'document_file_pending_deletion',
        ),
      ),
    );
  });

  test('giving up deletes only a stored, unrecorded file', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final discard = container.read(uploadDiscarderProvider);
    final untouched = _attempt();
    await discard(untouched);
    expect(app.documents.calls.where((c) => c.$1 == 'discardFile'), isEmpty);

    app.documents.recordFailures.add(const NetworkFailure());
    final stranded = _attempt();
    await expectLater(
      container
          .read(documentsProvider(_ali).notifier)
          .attach(stranded, name: 'S', kind: DocumentKind.photo),
      throwsA(isA<NetworkFailure>()),
    );
    await discard(stranded);
    expect(app.documents.stored, isNot(contains(stranded.upload.storagePath)));

    // A failure to delete is ignored: the daily sweep queues the file.
    app.documents.gate.failure = const Forbidden();
    await discard(stranded);
  });

  test('a document is renamed and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, documentsProvider(_ali));
    await pumpEventQueue();
    final controller = container.read(documentsProvider(_ali).notifier);
    final saved = await controller.save(
      cnicFrontScan,
      name: 'Front side',
      kind: DocumentKind.cnicFront,
    );
    expect(saved.fileName, 'Front side');
    expect(
      container.read(documentsProvider(_ali)).value!.value.items.first,
      saved,
    );
    await controller.delete(saved);
    expect(container.read(documentsProvider(_ali)).value!.value.items, [
      cnicBackScan,
    ]);
  });

  test('links are made once and say when', () async {
    final app = TestApp();
    final container = containerFor(app);
    final sub = listen(container, documentLinksProvider(cnicFrontScan));
    final made = await container.read(
      documentLinksProvider(cnicFrontScan).future,
    );
    expect(made.links.open.path, '/${cnicFrontScan.storagePath}');
    expect(sub.read().value, made);
    final at = DateTime.utc(2026, 11, 7, 10);
    expect(linksFresh(at, at.add(const Duration(minutes: 3))), isTrue);
    expect(linksFresh(at, at.add(const Duration(minutes: 4))), isFalse);
    expect(DocumentRepository.linkLifetime, const Duration(minutes: 5));
  });
}
