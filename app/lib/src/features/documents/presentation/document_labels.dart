import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:mm_ui/mm_ui.dart';

/// The words for documents and their files.
extension DocumentWords on AppLocalizations {
  String documentKind(DocumentKind kind) => switch (kind) {
    DocumentKind.cnicFront => documentKindCnicFront,
    DocumentKind.cnicBack => documentKindCnicBack,
    DocumentKind.photo => documentKindPhoto,
    DocumentKind.tenancyAgreement => documentKindTenancyAgreement,
    DocumentKind.policeRegistration => documentKindPoliceRegistration,
    DocumentKind.rentRegistration => documentKindRentRegistration,
    DocumentKind.utilityBill => documentKindUtilityBill,
    DocumentKind.receipt => documentKindReceipt,
    DocumentKind.invoice => documentKindInvoice,
    DocumentKind.meterPhoto => documentKindMeterPhoto,
    DocumentKind.propertyPaper => documentKindPropertyPaper,
    DocumentKind.other => documentKindOther,
  };

  String fileType(DocumentFileType type) => switch (type) {
    DocumentFileType.jpeg => fileTypeJpeg,
    DocumentFileType.png => fileTypePng,
    DocumentFileType.webp => fileTypeWebp,
    DocumentFileType.heic => fileTypeHeic,
    DocumentFileType.pdf => fileTypePdf,
  };

  /// A file's format alone, for a list row: "JPEG", "PDF".
  String fileFormat(DocumentFileType type) => switch (type) {
    DocumentFileType.jpeg => fileFormatJpeg,
    DocumentFileType.png => fileFormatPng,
    DocumentFileType.webp => fileFormatWebp,
    DocumentFileType.heic => fileFormatHeic,
    DocumentFileType.pdf => fileFormatPdf,
  };

  /// What a record without documents says: when the member may add them,
  /// also what to add to a tenant, a tenancy, a unit or a property.
  String documentsEmptyFor(DocumentEntity entity, {required bool adding}) {
    if (!adding) return documentsEmpty;
    return switch (entity) {
      DocumentEntity.tenant => documentsEmptyTenant,
      DocumentEntity.lease => documentsEmptyLease,
      DocumentEntity.unit => documentsEmptyUnit,
      DocumentEntity.property => documentsEmptyProperty,
      DocumentEntity.payment ||
      DocumentEntity.expense ||
      DocumentEntity.maintenanceRequest ||
      DocumentEntity.utilityBill ||
      DocumentEntity.meterReading => documentsEmpty,
    };
  }

  /// [bytes] as a size: "245 KB" under a megabyte, else "1.2 MB" (see
  /// [fileSizeLabel] for showing it).
  String fileSize(int bytes) {
    const kilobyte = 1024;
    const megabyte = kilobyte * kilobyte;
    if (bytes < megabyte) {
      return fileSizeKb('${(bytes / kilobyte).ceil()}');
    }
    return fileSizeMb((bytes / megabyte).toStringAsFixed(1));
  }
}

/// [bytes] as a size in the UI's direction: "245 KB", kept left to right
/// (and on one line) in the Urdu UI, where its figures and "KB" would
/// otherwise trade places with the words around them.
String fileSizeLabel(BuildContext context, int bytes) => MmSemantics.isolated(
  AppLocalizations.of(context).fileSize(bytes),
  Directionality.of(context),
);

/// A file's type and size: "PDF, 1.2 MB" (with the Urdu comma in Urdu).
String fileSummary(BuildContext context, DocumentFileType type, int bytes) =>
    MmLocalizations.of(context).joined([
      AppLocalizations.of(context).fileType(type),
      fileSizeLabel(context, bytes),
    ]);

/// The icon of a document's file: a photo or a page.
IconData documentIcon(DocumentFileType type) =>
    type.isImage ? MmIcons.image : MmIcons.document;
