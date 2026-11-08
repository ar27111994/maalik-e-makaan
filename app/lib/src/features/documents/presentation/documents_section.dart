import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/document_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_ui/mm_ui.dart';

/// The documents of one record (DOC-01, TEN-04): CNIC copies, agreements,
/// police forms and photos, newest first, each opening a sheet to open,
/// download, rename or delete it as the member's role allows, and "Add
/// document" for the roles that upload (when [canAdd]: a record in use).
class DocumentsSection extends ConsumerWidget {
  const new({required this.owner, this.canAdd = true, super.key});

  final DocumentOwner owner;

  /// Offers adding documents (the record is in use, not archived).
  final bool canAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    if (portfolio == null) return const SizedBox.shrink();
    final list = (portfolioId: portfolio.id, owner: owner);
    final role = portfolio.role;
    final add = canAdd && role.recordsDocuments;
    final provider = documentsProvider(list);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.documentsSection,
          subtitle: l10n.documentsSectionHelp,
          actionLabel: add ? l10n.addDocumentAction : null,
          onAction: add
              ? () => showMmSheet<void>(
                  context,
                  title: l10n.addDocumentAction,
                  builder: (_) => AddDocumentSheet(
                    list: list,
                    discardsFiles: role.deletesDocuments,
                  ),
                )
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingDocuments,
          failedTitle: l10n.documentsLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 2),
          builder: (page) => page.items.isEmpty
              ? Text(
                  l10n.documentsEmptyFor(owner.entity, adding: add),
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListCard(
                      children: [
                        for (final document in page.items)
                          DocumentTile(
                            document: document,
                            onTap: () => showMmSheet<void>(
                              context,
                              // The name is the landlord's, in either
                              // script: the sheet shows it as their text,
                              // under a title in the UI's own.
                              title: l10n.documentSheetTitle,
                              builder: (_) => DocumentSheet(
                                document: document,
                                list: list,
                                role: role,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (page.hasMore)
                      LoadMoreButton(
                        onLoad: () => ref.read(provider.notifier).loadMore(),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A document in a list: its name, its kind (unless the name is the
/// kind's), when it was added and its format; its size is on its sheet.
class DocumentTile extends StatelessWidget {
  const new({required this.document, required this.onTap, super.key});

  /// More lines than any subtitle here takes, even in Urdu at 200%:
  /// MmListTile has no setting for "no limit", and a subtitle must wrap,
  /// never end in an ellipsis.
  static const subtitleLines = 100;

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = l10n.documentKind(document.kind);
    return MmListTile(
      leading: Icon(documentIcon(document.fileType)),
      title: document.fileName,
      subtitle: detailLine([
        if (document.fileName != kind) kind,
        // The day before the format: MmListTile sets a subtitle in the
        // direction of its first letter, which must be the UI's, not a
        // Latin "JPEG"'s in the Urdu UI.
        dateLabel(context, pakistanDate(document.uploadedAt)),
        // Kept apart, so that it keeps to its place at the end.
        inSentence(
          l10n.fileFormat(document.fileType),
          Directionality.of(context),
        ),
      ]),
      subtitleMaxLines: subtitleLines,
      trailing: const Icon(MmIcons.chevronEnd),
      onTap: onTap,
    );
  }
}

/// One document: what it is, opening and downloading its file through a
/// short-lived link, and for the roles that may, renaming it, changing its
/// kind and deleting it.
class DocumentSheet extends ConsumerStatefulWidget {
  const new({
    required this.document,
    required this.list,
    required this.role,
    super.key,
  });

  final Document document;
  final DocumentList list;
  final MemberRole role;

  @override
  ConsumerState<DocumentSheet> createState() => _DocumentSheetState();
}

class _DocumentSheetState extends ConsumerState<DocumentSheet>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.document.fileName);
  late DocumentKind _kind = widget.document.kind;
  bool _editing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DocumentsController get _documents =>
      ref.read(documentsProvider(widget.list).notifier);

  /// Opens the link [pick] chooses: the one made when the sheet opened
  /// while it works, else a new one.
  Future<void> _launch(Uri Function(DocumentLinks links) pick) async {
    final l10n = AppLocalizations.of(context);
    final provider = documentLinksProvider(widget.document);
    var links = switch (ref.read(provider).value) {
      final made? when linksFresh(made.madeAt, clock.now()) => made.links,
      _ => null,
    };
    if (links == null) {
      final made = await runCommand(() async {
        links = (await ref.refresh(provider.future)).links;
      });
      if (!made || !mounted) return;
    }
    final opened = await ref.read(linkOpenerProvider)(pick(links!));
    if (!opened && mounted) {
      await showMmSnackbar(
        context,
        message: l10n.linkNotOpened,
        tone: MmBannerTone.error,
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final name = documentName(_name.text);
    final done = await runCommand(
      () => _documents.save(widget.document, name: name, kind: _kind),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.documentSaved(
          inSentence(name, Directionality.of(context)),
        ),
        tone: MmBannerTone.success,
      ),
    );
    _closeSheet(context);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final name = inSentence(
      widget.document.fileName,
      Directionality.of(context),
    );
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteDocumentTitle(name),
      message: l10n.deleteDocumentBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(() => _documents.delete(widget.document));
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.documentDeleted(name),
        tone: MmBannerTone.success,
      ),
    );
    _closeSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final document = widget.document;
    if (_editing) {
      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null) FailureBanner(failure: failure),
            _KindField(
              entity: widget.list.owner.entity,
              value: _kind,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
            const SizedBox(height: MmSpace.s4),
            MmTextField(
              label: l10n.documentNameLabel,
              controller: _name,
              required: true,
              maxLength: Document.maxNameLength,
              validator: (value) {
                if (documentName(value ?? '').isEmpty) {
                  return l10n.validationRequired;
                }
                return _nameError(l10n, value);
              },
            ),
            const SizedBox(height: MmSpace.s4),
            MmButton(label: l10n.saveAction, busy: busy, onPressed: _save),
            const SizedBox(height: MmSpace.s3),
            MmButton(
              label: l10n.cancelAction,
              variant: MmButtonVariant.tertiary,
              onPressed: busy ? null : () => setState(() => _editing = false),
            ),
          ],
        ),
      );
    }
    final links = ref.watch(documentLinksProvider(document));
    final linkError = links.error;
    // Links being made again in the background leave the ones there in
    // use: only the first ones are waited for.
    final waiting = links.isLoading && !links.hasValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null)
          FailureBanner(failure: failure)
        else if (linkError != null)
          FailureBanner(failure: AppFailure.from(linkError)),
        MmDetailRow(label: l10n.documentNameLabel, value: document.fileName),
        MmDetailRow(
          label: l10n.documentKindLabel,
          value: l10n.documentKind(document.kind),
          userData: false,
        ),
        MmDetailRow(
          label: l10n.documentFileLabel,
          value: fileSummary(context, document.fileType, document.sizeBytes),
          userData: false,
        ),
        MmDetailRow(
          label: l10n.documentAddedOnLabel,
          value: momentLabel(context, document.uploadedAt),
          userData: false,
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.openDocumentAction,
          icon: documentIcon(document.fileType),
          busy: busy || waiting,
          onPressed: () => _launch((links) => links.open),
        ),
        const SizedBox(height: MmSpace.s3),
        MmButton(
          label: l10n.downloadDocumentAction,
          icon: MmIcons.download,
          variant: MmButtonVariant.secondary,
          onPressed: busy || waiting
              ? null
              : () => _launch((links) => links.download),
        ),
        if (widget.role.recordsDocuments) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.editDocumentAction,
            icon: MmIcons.edit,
            variant: MmButtonVariant.tertiary,
            onPressed: busy ? null : () => setState(() => _editing = true),
          ),
        ],
        if (widget.role.deletesDocuments) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.deleteAction,
            icon: MmIcons.delete,
            variant: MmButtonVariant.destructive,
            onPressed: busy ? null : _delete,
          ),
        ],
      ],
    );
  }
}

/// Adding a document (DOC-01, DOC-02): a photo taken now or a file chosen
/// from the device, checked and made smaller, then its kind and name, and
/// the upload. A failed upload is tried again with the same attempt; when
/// the sheet closes with the file stored but not recorded, the file is
/// deleted (for the roles that may, [discardsFiles]; otherwise the daily
/// sweep queues it a day later).
class AddDocumentSheet extends ConsumerStatefulWidget {
  const new({required this.list, required this.discardsFiles, super.key});

  final DocumentList list;

  /// Whether the member may delete a stored file no row refers to.
  final bool discardsFiles;

  @override
  ConsumerState<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

/// Where the file being prepared comes from.
enum _Source { camera, files }

class _AddDocumentSheetState extends ConsumerState<AddDocumentSheet>
    with CommandState {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late DocumentKind _kind = widget.list.owner.entity.suggestedKinds.first;
  late final UploadDiscarder _discard;
  UploadAttempt? _attempt;
  _Source? _source;

  @override
  void initState() {
    super.initState();
    // Read now: the sheet gives up its upload when it is disposed, when it
    // may no longer read providers.
    _discard = ref.read(uploadDiscarderProvider);
  }

  @override
  void dispose() {
    // An upload still running goes on and records its document, or fails
    // and leaves its file to the daily sweep: deleting the file under it
    // would only make it store the file again.
    if (!busy) _giveUp();
    _name.dispose();
    super.dispose();
  }

  /// Deletes the current attempt's file if it was stored but not recorded.
  void _giveUp() {
    final attempt = _attempt;
    if (attempt != null && widget.discardsFiles) unawaited(_discard(attempt));
  }

  Future<void> _pick(_Source source) async {
    setState(() => _source = source);
    final picker = ref.read(documentPickerProvider);
    final prepare = ref.read(filePreparerProvider);
    await runCommand(() async {
      final picked = await (source == _Source.camera
          ? picker.takePhoto()
          : picker.chooseFile());
      if (picked == null) return;
      final file = await prepare(picked);
      if (!mounted) return;
      _giveUp();
      setState(() {
        _attempt = UploadAttempt(
          portfolioId: widget.list.portfolioId,
          owner: widget.list.owner,
          file: file,
        );
        // A camera photo's file name means nothing: it is named after its
        // kind unless the landlord names it.
        _name.text = source == _Source.camera ? '' : documentName(file.name);
      });
    });
  }

  void _chooseAgain() {
    _giveUp();
    setState(() {
      _attempt = null;
      failure = null;
    });
  }

  Future<void> _upload(UploadAttempt attempt) async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final typed = documentName(_name.text);
    final name = typed.isEmpty ? l10n.documentKind(_kind) : typed;
    final done = await runCommand(
      () => ref
          .read(documentsProvider(widget.list).notifier)
          .attach(attempt, name: name, kind: _kind),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.documentAdded(
          inSentence(name, Directionality.of(context)),
        ),
        tone: MmBannerTone.success,
      ),
    );
    _closeSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final attempt = _attempt;
    final file = attempt?.upload.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (attempt == null || file == null) ...[
          Text(
            l10n.addDocumentHelp,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MmSpace.s4),
          Semantics(
            liveRegion: busy,
            label: busy ? l10n.preparingFile : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MmButton(
                  label: l10n.takePhotoAction,
                  icon: MmIcons.camera,
                  variant: MmButtonVariant.secondary,
                  busy: busy && _source == _Source.camera,
                  onPressed: busy ? null : () => _pick(_Source.camera),
                ),
                const SizedBox(height: MmSpace.s3),
                MmButton(
                  label: l10n.chooseFileAction,
                  icon: MmIcons.attach,
                  variant: MmButtonVariant.secondary,
                  busy: busy && _source == _Source.files,
                  onPressed: busy ? null : () => _pick(_Source.files),
                ),
              ],
            ),
          ),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChosenFileCard(file: file),
                MmButton(
                  label: l10n.chooseAnotherFileAction,
                  icon: MmIcons.attach,
                  variant: MmButtonVariant.tertiary,
                  onPressed: busy ? null : _chooseAgain,
                ),
                const SizedBox(height: MmSpace.s4),
                _KindField(
                  entity: widget.list.owner.entity,
                  value: _kind,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                const SizedBox(height: MmSpace.s4),
                MmTextField(
                  label: l10n.documentNameLabel,
                  controller: _name,
                  optional: true,
                  helper: l10n.documentNameHelp,
                  maxLength: Document.maxNameLength,
                  validator: (value) => _nameError(l10n, value),
                ),
                const SizedBox(height: MmSpace.s4),
                MmButton(
                  label: l10n.uploadAction,
                  icon: MmIcons.upload,
                  busy: busy,
                  onPressed: () => _upload(attempt),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The file about to be uploaded, to check before it goes: a photo shows
/// itself (the front or the back of a CNIC, and whether it is sharp), a
/// PDF or a HEIC photo its icon; then its type, and its size or how much
/// smaller it was made.
class _ChosenFileCard extends StatelessWidget {
  const new({required this.file});

  /// The height of a photo's preview: enough to read a CNIC's layout,
  /// small enough to leave the form in view. (The design system has no
  /// size for previews.)
  static const previewHeight = 160.0;

  final PreparedFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    // The browser and the platform show these; a HEIC photo kept as it is
    // could not be decoded here, and a PDF is not a picture.
    final previewable = switch (file.type) {
      DocumentFileType.jpeg ||
      DocumentFileType.png ||
      DocumentFileType.webp => true,
      DocumentFileType.heic || DocumentFileType.pdf => false,
    };
    return MmCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (previewable)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: MmSpace.s3,
                start: MmSpace.s3,
                end: MmSpace.s3,
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MmRadius.sm),
                  child: Image.memory(
                    file.bytes,
                    height: previewHeight,
                    fit: BoxFit.contain,
                    semanticLabel: l10n.documentPreviewLabel,
                    // A photo the screen cannot show leaves only its
                    // details.
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          // The UI's own words, in the UI's direction (an MmListTile would
          // set them as the landlord's text, in the direction of their
          // first letter: in the Urdu UI, that of "2.4 MB").
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(MmSpace.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MmSpace.s4,
                children: [
                  Icon(
                    documentIcon(file.type),
                    color: colors.inkMuted,
                    // Grown with the text up to one and a half times, as
                    // mm_ui grows icons beside words (its MmIconLabel,
                    // which it does not export).
                    size: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.5)
                        .scale(MmSize.iconLg),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.fileType(file.type), style: text.bodyLarge),
                        Text(
                          file.compressed
                              ? l10n.documentCompressed(
                                  fileSizeLabel(context, file.originalSize),
                                  fileSizeLabel(context, file.size),
                                )
                              : fileSizeLabel(context, file.size),
                          style: text.bodyMedium?.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The error of a typed document name too long for the database, which
/// counts a letter's marks as characters of their own.
String? _nameError(AppLocalizations l10n, String? value) =>
    documentNameTooLong(value ?? '') ? l10n.documentNameTooLong : null;

/// The kind of a document of [entity], the likeliest kinds first.
class _KindField extends StatelessWidget {
  const new({
    required this.entity,
    required this.value,
    required this.onChanged,
  });

  final DocumentEntity entity;
  final DocumentKind value;
  final ValueChanged<DocumentKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MmSelectField<DocumentKind>(
      label: l10n.documentKindLabel,
      required: true,
      options: [
        for (final kind in entity.kindsInOrder)
          MmOption(value: kind, label: l10n.documentKind(kind)),
      ],
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Closes the sheet [context] is in, unless it is closing already (the
/// landlord closed it while its command ran): popping then would close the
/// screen under it.
void _closeSheet(BuildContext context) {
  if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
}
