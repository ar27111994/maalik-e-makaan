import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One upload of a file and its document row: the ids are chosen once,
/// when the file is picked, and kept for every retry, so a retried upload
/// never stores the file twice and a retried insert never adds a second
/// row.
final class DocumentUpload {
  new({
    required this.id,
    required this.portfolioId,
    required this.owner,
    required this.file,
  });

  /// The document's id, also the stored file's name.
  final String id;
  final String portfolioId;
  final DocumentOwner owner;
  final PreparedFile file;

  /// Where the file is stored:
  /// `<portfolio_id>/<entity>/<entity_id>/<uuid>.<ext>`, the layout the
  /// bucket's policies and the `documents_storage_path_check` require.
  String get storagePath =>
      '$portfolioId/${owner.entity.db}/${owner.id}/$id.${file.type.extension}';
}

/// The links to a stored file, valid for [DocumentRepository.linkLifetime].
typedef DocumentLinks = ({Uri open, Uri download});

/// Documents and their files. Every method throws [AppFailure].
///
/// Members see and open documents; owners, managers and accountants
/// upload, rename and change their kind; owners and managers delete them
/// (`docs/architecture/permissions.md`). A file is uploaded first, then its
/// row is written: the database refuses a row whose file is missing
/// (`document_file_missing`) or queued for deletion
/// (`document_file_pending_deletion`).
abstract interface class DocumentRepository {
  /// How long a link to a file works: short, as the files are private
  /// (TEN-04), but long enough to open one from the sheet that made it.
  static const linkLifetime = Duration(minutes: 5);

  /// A page of [owner]'s documents in [portfolioId], newest first.
  Future<Paged<Document>> documents(
    String portfolioId,
    DocumentOwner owner, {
    PageCursor? after,
  });

  /// Stores [upload]'s file. A retry of an upload that reached the server
  /// finds the file there and succeeds.
  Future<void> uploadFile(DocumentUpload upload);

  /// Writes the row of [upload]'s stored file, named [name] and of [kind].
  /// A retry of an insert that reached the server returns the document it
  /// added. Refusals: `document_file_missing`,
  /// `document_file_pending_deletion`, `document_entity_not_found`.
  Future<Document> recordDocument(
    DocumentUpload upload, {
    required String name,
    required DocumentKind kind,
  });

  /// Deletes a stored file no row refers to (an upload whose row was never
  /// written). Owners and managers only; for anyone else, and for a file a
  /// row refers to, nothing is deleted. Files left behind are queued by
  /// the daily sweep a day after they were uploaded.
  Future<void> discardFile(String storagePath);

  /// Short-lived links that open [document]'s file and download it under
  /// its name.
  Future<DocumentLinks> links(Document document);

  /// Renames [document] and changes its kind.
  Future<Document> updateDocument(
    Document document, {
    required String name,
    required DocumentKind kind,
  });

  /// Deletes the document; its file is queued for deletion. Deleting one
  /// already deleted succeeds.
  Future<void> deleteDocument(String documentId);
}

/// [DocumentRepository] over `documents` and the `documents` bucket.
final class SupabaseDocumentRepository implements DocumentRepository {
  new(this._client);

  static const bucket = 'documents';

  final SupabaseClient _client;

  StorageFileApi get _files => _client.storage.from(bucket);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Paged<Document>> documents(
    String portfolioId,
    DocumentOwner owner, {
    PageCursor? after,
  }) => _guard(() async {
    final rows = await _client
        .from('documents')
        .select(Document.columns)
        .eq('portfolio_id', portfolioId)
        .eq('entity_type', owner.entity.db)
        .eq('entity_id', owner.id)
        .before(after)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(Document.fromRow).toList(), (d) => d.cursor);
  });

  @override
  Future<void> uploadFile(DocumentUpload upload) => _guard(() async {
    try {
      await _files.uploadBinary(
        upload.storagePath,
        upload.file.bytes,
        fileOptions: FileOptions(contentType: upload.file.type.mimeType),
      );
    } on StorageException catch (error) {
      // The name is this upload's own uuid: a file already there is the
      // one an earlier try of this upload stored.
      if (error.statusCode == '409') return;
      rethrow;
    }
  });

  @override
  Future<Document> recordDocument(
    DocumentUpload upload, {
    required String name,
    required DocumentKind kind,
  }) => _guard(() async {
    try {
      final row = await _client
          .from('documents')
          .insert({
            'id': upload.id,
            'portfolio_id': upload.portfolioId,
            'entity_type': upload.owner.entity.db,
            'entity_id': upload.owner.id,
            'kind': kind.db,
            'storage_path': upload.storagePath,
            'file_name': documentName(name),
            'mime_type': upload.file.type.mimeType,
            'size_bytes': upload.file.size,
          })
          .select(Document.columns)
          .single();
      return Document.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A retry of an insert that reached the server returns its row.
      final existing = await _client
          .from('documents')
          .select(Document.columns)
          .eq('id', upload.id)
          .maybeSingle();
      if (existing == null) rethrow;
      return Document.fromRow(existing);
    }
  });

  @override
  Future<void> discardFile(String storagePath) =>
      _guard(() => _files.remove([storagePath]));

  @override
  Future<DocumentLinks> links(Document document) => _guard(() async {
    final signed = await _files.createSignedUrl(
      document.storagePath,
      DocumentRepository.linkLifetime.inSeconds,
    );
    // The bucket names a download by its `download` parameter, which the
    // signature does not cover; it is added as storage_client adds it.
    final name = '${document.fileName}.${document.fileType.extension}';
    final separator = signed.contains('?') ? '&' : '?';
    final download =
        '$signed${separator}download=${Uri.encodeQueryComponent(name)}';
    return (open: Uri.parse(signed), download: Uri.parse(download));
  });

  @override
  Future<Document> updateDocument(
    Document document, {
    required String name,
    required DocumentKind kind,
  }) => _guard(() async {
    final row = await _client
        .from('documents')
        .update({'file_name': documentName(name), 'kind': kind.db})
        .eq('id', document.id)
        .select(Document.columns)
        .single();
    return Document.fromRow(row);
  });

  @override
  Future<void> deleteDocument(String documentId) => _guard(() async {
    final deleted = await _client
        .from('documents')
        .delete()
        .eq('id', documentId)
        .select('id');
    if (deleted.isNotEmpty) return;
    // Nothing deleted: gone already (a retry, or someone else deleted it),
    // or still there and the caller may not delete it.
    final still = await _client
        .from('documents')
        .select('id')
        .eq('id', documentId)
        .maybeSingle();
    if (still != null) throw const Forbidden();
  });
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => SupabaseDocumentRepository(ref.watch(supabaseClientProvider)),
);
