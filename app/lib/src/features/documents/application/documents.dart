import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';

/// Which documents a list shows: those of one record in a portfolio.
typedef DocumentList = ({String portfolioId, DocumentOwner owner});

/// One record's documents, newest first, the saved copy first, 50 at a
/// time.
final StreamNotifierProviderFamily<
  DocumentsController,
  Snapshot<Paged<Document>>,
  DocumentList
>
documentsProvider = StreamNotifierProvider.autoDispose
    .family<DocumentsController, Snapshot<Paged<Document>>, DocumentList>(
      DocumentsController.new,
    );

/// An upload in progress, from picking the file until its document is
/// recorded: it keeps the ids of the attempt, so that trying again neither
/// stores the file twice nor adds a second row, and knows whether the file
/// is stored without a row (to delete it when the landlord gives up).
final class UploadAttempt {
  new({
    required String portfolioId,
    required DocumentOwner owner,
    required PreparedFile file,
    String Function()? newId,
  }) : _newId = newId ?? newUuid,
       _upload = DocumentUpload(
         id: (newId ?? newUuid)(),
         portfolioId: portfolioId,
         owner: owner,
         file: file,
       );

  final String Function() _newId;
  DocumentUpload _upload;
  bool _stored = false;
  bool _recorded = false;

  /// The ids, path and file of the attempt.
  DocumentUpload get upload => _upload;

  /// The stored file no row refers to yet, if there is one.
  String? get unrecordedPath =>
      _stored && !_recorded ? _upload.storagePath : null;

  /// The same file under new ids, for when the old path cannot be used.
  void _renew() {
    _upload = DocumentUpload(
      id: _newId(),
      portfolioId: _upload.portfolioId,
      owner: _upload.owner,
      file: _upload.file,
    );
    _stored = false;
  }
}

/// Reads one record's documents and changes them. Commands throw
/// [AppFailure].
final class DocumentsController extends SwrNotifier<Paged<Document>> {
  new(this.list);

  final DocumentList list;

  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  String get query =>
      'documents.${list.portfolioId}.${list.owner.entity.db}.${list.owner.id}';

  @override
  Stream<Snapshot<Paged<Document>>> build() {
    ref.watch(documentRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<Document>> fetch() =>
      _repository.documents(list.portfolioId, list.owner);

  @override
  Paged<Document> decode(Object? json) =>
      Paged.fromJson(json, Document.fromRow);

  @override
  Object? encode(Paged<Document> value) => value.toJson((d) => d.toRow());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.documents(
      list.portfolioId,
      list.owner,
      after: next,
    );
    await show(current.followedBy(more));
  }

  /// Stores [attempt]'s file and records its document, named [name] and of
  /// [kind] (DOC-01). Call it again with the same attempt to retry.
  ///
  /// The database refuses a row whose file is missing (it was deleted
  /// since it was stored) or queued for deletion (it waited unrecorded for
  /// the daily sweep): the file is then stored again, under new ids when
  /// its path is queued, and recorded once more before the refusal is
  /// passed on.
  Future<Document> attach(
    UploadAttempt attempt, {
    required String name,
    required DocumentKind kind,
  }) async {
    Future<Document> once() async {
      if (!attempt._stored) {
        await _repository.uploadFile(attempt.upload);
        attempt._stored = true;
      }
      return await _repository.recordDocument(
        attempt.upload,
        name: name,
        kind: kind,
      );
    }

    Document document;
    try {
      document = await once();
    } on RejectedFailure catch (failure) {
      switch (failure.reason) {
        case 'document_file_missing':
          attempt._stored = false;
        case 'document_file_pending_deletion':
          attempt._renew();
        default:
          rethrow;
      }
      document = await once();
    }
    attempt._recorded = true;
    await reload();
    return document;
  }

  /// Renames [document] and changes its kind.
  Future<Document> save(
    Document document, {
    required String name,
    required DocumentKind kind,
  }) async {
    final saved = await _repository.updateDocument(
      document,
      name: name,
      kind: kind,
    );
    await reload();
    return saved;
  }

  /// Deletes [document]; its file is queued for deletion.
  Future<void> delete(Document document) async {
    await _repository.deleteDocument(document.id);
    await reload();
  }
}

/// Gives up an upload: deletes its stored file if no row refers to it.
typedef UploadDiscarder = Future<void> Function(UploadAttempt attempt);

/// Gives up uploads (an [UploadDiscarder]). Deleting the file is a
/// courtesy: owners and managers may delete a file no row refers to,
/// failures are ignored, and what is left behind is queued by the daily
/// sweep (`private.enqueue_orphaned_storage`) a day after it was stored.
final Provider<UploadDiscarder> uploadDiscarderProvider =
    Provider<UploadDiscarder>((ref) {
      final repository = ref.watch(documentRepositoryProvider);
      return (attempt) async {
        final path = attempt.unrecordedPath;
        if (path == null) return;
        try {
          await repository.discardFile(path);
        } on AppFailure {
          // The daily sweep queues the file.
        }
      };
    });

/// Links to a document's file, made when its sheet opens, so that opening
/// it is the tap's own action (a browser lets only that open a tab), and
/// when they were made.
///
/// While the sheet shows them, they are made again every
/// [linksRenewedAfter], before [linksFresh] counts them stale: a tap then
/// always finds a working link, and never has to wait for a new one (by
/// then the browser no longer counts the tab it opens as the tap's).
final FutureProviderFamily<DocumentLinksAt, Document> documentLinksProvider =
    FutureProvider.autoDispose.family<DocumentLinksAt, Document>((
      ref,
      document,
    ) async {
      // Counted from before the request: the server's five minutes start
      // later, so the links are never older than this says.
      final madeAt = clock.now();
      final renew = Timer(linksRenewedAfter, ref.invalidateSelf);
      ref.onDispose(renew.cancel);
      final links = await ref.watch(documentRepositoryProvider).links(document);
      return (links: links, madeAt: madeAt);
    });

/// Links to a file and when they were made.
typedef DocumentLinksAt = ({DocumentLinks links, DateTime madeAt});

/// How long after they were made a document's links are made again while
/// its sheet is open: a minute before [linksFresh] counts them stale.
const linksRenewedAfter = Duration(minutes: 3);

/// Whether links made at [madeAt] still work for a minute at [now].
bool linksFresh(DateTime madeAt, DateTime now) =>
    now.difference(madeAt) <
    DocumentRepository.linkLifetime - const Duration(minutes: 1);
