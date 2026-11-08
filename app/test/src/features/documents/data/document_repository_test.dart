import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

const _documentId = '0192d0c4-6666-7000-8000-000000000001';
const _path =
    '${'0192d0c4-0000-7000-8000-000000000001'}/tenant/'
    '0192d0c4-4444-7000-8000-000000000001/$_documentId.pdf';

/// A `documents` row as PostgREST returns it.
final Map<String, Object?> _row = {
  'id': _documentId,
  'entity_type': 'tenant',
  'entity_id': '0192d0c4-4444-7000-8000-000000000001',
  'kind': 'cnic_front',
  'storage_path': _path,
  'file_name': 'CNIC front',
  'mime_type': 'application/pdf',
  'size_bytes': 245760,
  'created_at': '2026-11-01T06:30:00+00:00',
};

final _upload = DocumentUpload(
  id: _documentId,
  portfolioId: gulberg.id,
  owner: (
    entity: DocumentEntity.tenant,
    id: '0192d0c4-4444-7000-8000-000000000001',
  ),
  file: PreparedFile(
    name: 'scan',
    bytes: Uint8List.fromList(utf8.encode('%PDF-1.7 test')),
    type: DocumentFileType.pdf,
    originalSize: 13,
  ),
);

http.Response _storageError(String status, String error, String message) =>
    jsonResponse({
      'statusCode': status,
      'error': error,
      'message': message,
    }, status: 400);

void main() {
  late MockSupabase supabase;
  late SupabaseDocumentRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse([_row]));
    repository = SupabaseDocumentRepository(supabase.client);
  });

  group('Document', () {
    test('reads every column and writes it back', () {
      final document = Document.fromRow(_row);
      expect(document.id, _documentId);
      expect(document.owner, (
        entity: DocumentEntity.tenant,
        id: '0192d0c4-4444-7000-8000-000000000001',
      ));
      expect(document.kind, DocumentKind.cnicFront);
      expect(document.fileType, DocumentFileType.pdf);
      expect(document.sizeBytes, 245760);
      expect(document.uploadedAt, DateTime.utc(2026, 11, 1, 6, 30));
      expect(document.cursor.createdAt, '2026-11-01T06:30:00+00:00');
      expect(Document.fromRow(document.toRow()), document);
      expect(Document.fromRow(document.toRow()).hashCode, document.hashCode);
      final renamed = document.copyWith(
        fileName: 'Front',
        kind: DocumentKind.cnicBack,
      );
      expect(renamed.fileName, 'Front');
      expect(renamed.kind, DocumentKind.cnicBack);
      expect(renamed, isNot(document));
      expect(document.copyWith(), document);
    });

    test('malformed rows are refused', () {
      for (final row in <Object?>[
        null,
        {..._row}..remove('kind'),
        {..._row, 'kind': 'passport'},
        {..._row, 'entity_type': 'garage'},
        {..._row, 'mime_type': 'image/gif'},
        {..._row, 'size_bytes': '245760'},
        {..._row, 'created_at': 'yesterday'},
      ]) {
        expect(
          () => Document.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
      for (final kind in DocumentKind.values) {
        expect(DocumentKind.parse(kind.db), kind);
      }
      for (final entity in DocumentEntity.values) {
        expect(DocumentEntity.parse(entity.db), entity);
        expect(entity.kindsInOrder.toSet(), DocumentKind.values.toSet());
        expect(entity.kindsInOrder.length, DocumentKind.values.length);
        expect(
          entity.kindsInOrder.take(entity.suggestedKinds.length),
          entity.suggestedKinds,
        );
      }
      for (final type in DocumentFileType.values) {
        expect(DocumentFileType.parse(type.mimeType), type);
      }
    });

    test('a file type is read from its first bytes', () {
      List<int> bytes(String text) => latin1.encode(text);
      expect(
        DocumentFileType.sniff([0xFF, 0xD8, 0xFF, 0xE0]),
        DocumentFileType.jpeg,
      );
      expect(
        DocumentFileType.sniff([0x89, ...bytes('PNG\r\n'), 0x1A, 0x0A, 0]),
        DocumentFileType.png,
      );
      expect(
        DocumentFileType.sniff(bytes('RIFF\u0000\u0000\u0000\u0000WEBPVP8 ')),
        DocumentFileType.webp,
      );
      expect(DocumentFileType.sniff(bytes('%PDF-1.7')), DocumentFileType.pdf);

      /// An ftyp box of [size] bytes with these brands.
      List<int> ftyp(String major, List<String> compatible, {int? size}) => [
        0,
        0,
        0,
        size ?? 16 + 4 * compatible.length,
        ...bytes('ftyp$major\u0000\u0000\u0000\u0000${compatible.join()}'),
      ];
      for (final brand in ['heic', 'heix', 'heim', 'heis', 'hevc', 'hevx']) {
        expect(
          DocumentFileType.sniff(bytes('\u0000\u0000\u0000\u0018ftyp$brand')),
          DocumentFileType.heic,
          reason: brand,
        );
      }
      // The generic HEIF brands say nothing of the codec: a compatible
      // brand does.
      expect(
        DocumentFileType.sniff(ftyp('mif1', ['mif1', 'heic'])),
        DocumentFileType.heic,
      );
      expect(
        DocumentFileType.sniff(ftyp('msf1', ['msf1', 'hevc', 'iso8'])),
        DocumentFileType.heic,
      );
      expect(DocumentFileType.sniff(ftyp('mif1', ['mif1', 'miaf'])), isNull);
      // AVIF is not HEIC, whatever generic brand it starts with.
      expect(DocumentFileType.sniff(ftyp('mif1', ['avif', 'mif1'])), isNull);
      expect(DocumentFileType.sniff(ftyp('msf1', ['avis', 'msf1'])), isNull);
      expect(DocumentFileType.sniff(ftyp('avif', ['mif1', 'miaf'])), isNull);
      expect(
        DocumentFileType.sniff(ftyp('mif1', ['mif1', 'heic', 'avif'])),
        isNull,
      );
      // Brands past the box's end, or a box size of 0 or 1, are not read.
      expect(
        DocumentFileType.sniff(ftyp('mif1', ['mif1', 'heic'], size: 20)),
        isNull,
      );
      expect(DocumentFileType.sniff(ftyp('mif1', ['heic'], size: 1)), isNull);
      expect(
        DocumentFileType.sniff(ftyp('heic', ['mif1'], size: 0)),
        DocumentFileType.heic,
      );
      // A box that says it is longer than the file reads to the file's end.
      expect(
        DocumentFileType.sniff(ftyp('mif1', ['heic'], size: 200)),
        DocumentFileType.heic,
      );
      expect(
        DocumentFileType.sniff(bytes('\u0000\u0000\u0000\u0018ftypisom')),
        isNull,
      );
      expect(
        DocumentFileType.sniff(bytes('\u0000\u0000\u0000\u0018ftyp')),
        isNull,
      );
      expect(DocumentFileType.sniff(bytes('GIF89a')), isNull);
      expect(DocumentFileType.sniff(bytes('RIFF1234AVI ')), isNull);
      expect(DocumentFileType.sniff(const []), isNull);
      expect(DocumentFileType.sniff(const [0xFF]), isNull);
    });

    test('names are tidied to what the database accepts', () {
      expect(documentName('  Lease\n  scan\u202E '), 'Lease scan');
      expect(documentName('x' * 300).length, Document.maxNameLength);
      // 200 Urdu letters, each with a zabar: 200 characters to a reader,
      // 400 code points to the database's char_length; whole letters are
      // dropped until it fits, never a letter's mark alone.
      final marked = documentName('\u0628\u064E' * 200);
      expect(marked, '\u0628\u064E' * 100);
      expect(marked.runes.length, Document.maxNameLength);
      expect(documentNameTooLong(marked), isFalse);
      expect(documentNameTooLong('\u0628\u064E' * 101), isTrue);
      expect(documentNameTooLong('x' * 201), isTrue);
      expect(documentNameTooLong('  ${'x' * 200}\n'), isFalse);
      // A family emoji is one character of five code points.
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(documentName(family * 50), family * 40);
      // A name that fits is unchanged, and a trailing space left by the
      // cut is dropped.
      expect(
        documentName('${'\u0628\u064E' * 99}a \u0628\u064E'),
        '${'\u0628\u064E' * 99}a',
      );
      final file = _upload.file;
      expect(file.size, 13);
      expect(file.compressed, isFalse);
      expect(
        PreparedFile(
          name: 'p',
          bytes: Uint8List(10),
          type: DocumentFileType.jpeg,
          originalSize: 99,
        ).compressed,
        isTrue,
      );
    });

    test('an upload is stored where the bucket policies expect it', () {
      expect(_upload.storagePath, _path);
      expect(
        RegExp(
          '^[0-9a-f-]{36}/(property|unit|tenant|lease|payment|expense|'
          'maintenance_request|utility_bill|meter_reading)/[0-9a-f-]{36}/'
          r'[0-9a-f-]{36}\.(jpg|jpeg|png|webp|heic|pdf)$',
        ).hasMatch(_upload.storagePath),
        isTrue,
      );
    });
  });

  group('requests', () {
    test("a page of a record's documents, newest first", () async {
      final page = await repository.documents(
        gulberg.id,
        _upload.owner,
        after: const PageCursor(
          createdAt: '2026-11-02T00:00:00+00:00',
          id: 'd9',
        ),
      );
      expect(page.items.single.id, _documentId);
      expect(page.hasMore, isFalse);
      final request = supabase.request;
      expect(request.url.path, '/rest/v1/documents');
      final query = request.url.queryParametersAll;
      expect(query['select'], [Document.columns]);
      expect(query['portfolio_id'], ['eq.${gulberg.id}']);
      expect(query['entity_type'], ['eq.tenant']);
      expect(query['entity_id'], ['eq.${_upload.owner.id}']);
      const at = '"2026-11-02T00:00:00+00:00"';
      expect(query['or'], [
        '(created_at.lt.$at,and(created_at.eq.$at,id.lt."d9"))',
      ]);
      expect(query['order'], ['created_at.desc.nullslast,id.desc.nullslast']);
      expect(query['limit'], ['50']);
    });

    test('the file is uploaded under its path, with its type', () async {
      supabase.respond = (_) async => jsonResponse({'Key': 'documents/$_path'});
      await repository.uploadFile(_upload);
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.path, '/storage/v1/object/documents/$_path');
      expect(request.headers['x-upsert'], 'false');
      expect(request.body, contains('application/pdf'));
      expect(request.body, contains('%PDF-1.7 test'));
    });

    test('an upload the server already has (a retry) succeeds', () async {
      supabase.respond = (_) async =>
          _storageError('409', 'Duplicate', 'The resource already exists');
      await repository.uploadFile(_upload);
      expect(supabase.requests, hasLength(1));
    });

    test('storage refusals become failures', () async {
      final cases = <(http.Response, AppFailure)>[
        (
          _storageError(
            '403',
            'Unauthorized',
            'new row violates row-level security policy',
          ),
          const Forbidden(),
        ),
        (
          _storageError(
            '400',
            'InvalidJWT',
            '"exp" claim timestamp check failed',
          ),
          const SessionExpired(),
        ),
        (
          _storageError(
            '413',
            'Payload too large',
            'The object exceeded the maximum allowed size',
          ),
          const RejectedFailure('file_too_large'),
        ),
        (
          _storageError(
            '415',
            'invalid_mime_type',
            'mime type image/gif is not supported',
          ),
          const RejectedFailure('file_type_not_allowed'),
        ),
        (
          _storageError('429', 'too_many', 'slow down'),
          const RateLimited(null),
        ),
        (
          _storageError('503', 'unavailable', 'busy'),
          const TemporarilyUnavailable(),
        ),
        (_storageError('401', 'unauthorized', 'who'), const SessionExpired()),
        (_storageError('403', 'Forbidden', 'no'), const Forbidden()),
        (
          _storageError('500', 'internal', 'boom'),
          const ServerFailure('storage:500'),
        ),
        // A refusal no rule covers: a key the bucket does not accept.
        (
          _storageError('400', 'InvalidKey', 'Invalid key: a/b/../c.jpg'),
          const ServerFailure('storage:400'),
        ),
        (
          _storageError('404', 'not_found', 'Bucket not found'),
          const NotFoundFailure(),
        ),
      ];
      for (final (response, expected) in cases) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.uploadFile(_upload),
          throwsA(_sameFailure(expected)),
          reason: response.body,
        );
      }
      supabase.respond = (_) => throw http.ClientException('offline');
      await expectLater(
        repository.uploadFile(_upload),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('the row is inserted with only the granted columns', () async {
      supabase.respond = (_) async => jsonResponse(_row);
      final document = await repository.recordDocument(
        _upload,
        name: '  CNIC   front ',
        kind: DocumentKind.cnicFront,
      );
      expect(document.storagePath, _path);
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/documents');
      expect(bodyOf(request), {
        'id': _documentId,
        'portfolio_id': gulberg.id,
        'entity_type': 'tenant',
        'entity_id': _upload.owner.id,
        'kind': 'cnic_front',
        'storage_path': _path,
        'file_name': 'CNIC front',
        'mime_type': 'application/pdf',
        'size_bytes': 13,
      });
    });

    test('a retried insert returns the row it added', () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse([_row]);
      final document = await repository.recordDocument(
        _upload,
        name: 'CNIC front',
        kind: DocumentKind.cnicFront,
      );
      expect(document, Document.fromRow(_row));
      expect(supabase.requests.map((r) => r.method), ['POST', 'GET']);
      // The insert it retried, then a read of that row alone, with the
      // columns a document is read with.
      expect(bodyOf(supabase.requests.first), containsPair('id', _documentId));
      final read = supabase.requests.last;
      expect(read.url.path, '/rest/v1/documents');
      expect(read.url.queryParameters, {
        'select': Document.columns,
        'id': 'eq.$_documentId',
      });
    });

    test("a duplicate that is not this upload's row is a conflict", () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(<Object?>[]);
      await expectLater(
        repository.recordDocument(
          _upload,
          name: 'CNIC front',
          kind: DocumentKind.cnicFront,
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test("the database's refusals of a row reach the caller", () async {
      for (final reason in [
        'document_file_missing',
        'document_file_pending_deletion',
        'document_entity_not_found',
      ]) {
        supabase.respond = (_) async =>
            postgrestError('22023', message: reason);
        await expectLater(
          repository.recordDocument(
            _upload,
            name: 'CNIC front',
            kind: DocumentKind.cnicFront,
          ),
          throwsA(_sameFailure(RejectedFailure(reason))),
        );
      }
      supabase.respond = (_) async =>
          postgrestError('42501', status: 403, message: 'forbidden');
      await expectLater(
        repository.recordDocument(_upload, name: 'x', kind: DocumentKind.other),
        throwsA(isA<Forbidden>()),
      );
    });

    test('an unrecorded file is removed from the bucket', () async {
      supabase.respond = (_) async => jsonResponse([
        {'name': _path},
      ]);
      await repository.discardFile(_path);
      final request = supabase.request;
      expect(request.method, 'DELETE');
      expect(request.url.path, '/storage/v1/object/documents');
      expect(bodyOf(request), {
        'prefixes': [_path],
      });
    });

    test('links open and download the file for five minutes', () async {
      supabase.respond = (_) async => jsonResponse({
        'signedURL': '/object/sign/documents/$_path?token=t0k3n',
      });
      final links = await repository.links(Document.fromRow(_row));
      final request = supabase.request;
      expect(request.url.path, '/storage/v1/object/sign/documents/$_path');
      expect(bodyOf(request), {'expiresIn': 300});
      expect(
        links.open.toString(),
        '$supabaseUrl/storage/v1/object/sign/documents/$_path?token=t0k3n',
      );
      expect(links.download.queryParameters, {
        'token': 't0k3n',
        'download': 'CNIC front.pdf',
      });
      expect(links.download.path, links.open.path);
    });

    test('a link to a file that is gone is not found', () async {
      supabase.respond = (_) async =>
          _storageError('404', 'not_found', 'Object not found');
      await expectLater(
        repository.links(Document.fromRow(_row)),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('renaming writes only the name and the kind', () async {
      supabase.respond = (_) async => jsonResponse(_row);
      final saved = await repository.updateDocument(
        Document.fromRow(_row),
        name: ' Front ',
        kind: DocumentKind.cnicBack,
      );
      expect(saved.id, _documentId);
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.$_documentId');
      expect(bodyOf(request), {'file_name': 'Front', 'kind': 'cnic_back'});
    });

    test('renaming a document that is gone, or hidden, is not found', () async {
      // PostgREST answers a PATCH that matched no row (deleted, or no
      // longer visible to the member) and asked for one back with 406.
      supabase.respond = (_) async =>
          postgrestError('PGRST116', status: 406, message: '0 rows');
      await expectLater(
        repository.updateDocument(
          Document.fromRow(_row),
          name: 'Front',
          kind: DocumentKind.cnicBack,
        ),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('deleting a document', () async {
      supabase.respond = (_) async => jsonResponse([
        {'id': _documentId},
      ]);
      await repository.deleteDocument(_documentId);
      expect(supabase.request.method, 'DELETE');
      expect(supabase.request.url.queryParameters['id'], 'eq.$_documentId');
    });

    test('deleting one already gone succeeds', () async {
      supabase.respond = (request) async => request.method == 'DELETE'
          ? jsonResponse(<Object?>[])
          : jsonResponse(<Object?>[]);
      await repository.deleteDocument(_documentId);
      expect(supabase.requests, hasLength(2));
    });

    test('deleting one the member may not delete is forbidden', () async {
      supabase.respond = (request) async => request.method == 'DELETE'
          ? jsonResponse(<Object?>[])
          : jsonResponse([
              {'id': _documentId},
            ]);
      await expectLater(
        repository.deleteDocument(_documentId),
        throwsA(isA<Forbidden>()),
      );
    });
  });
}

/// A matcher for a failure equal in kind and reason to [expected].
Matcher _sameFailure(AppFailure expected) => predicate<Object?>(
  (actual) => switch ((actual, expected)) {
    (RejectedFailure(reason: final a), RejectedFailure(reason: final b)) =>
      a == b,
    (ServerFailure(code: final a), ServerFailure(code: final b)) => a == b,
    (RateLimited(retryAfter: final a), RateLimited(retryAfter: final b)) =>
      a == b,
    _ => actual.runtimeType == expected.runtimeType,
  },
  '$expected',
);
