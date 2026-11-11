import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// What a document is (`public.document_kind`).
enum DocumentKind with DbEnum {
  cnicFront('cnic_front'),
  cnicBack('cnic_back'),
  photo('photo'),
  tenancyAgreement('tenancy_agreement'),
  policeRegistration('police_registration'),
  rentRegistration('rent_registration'),
  utilityBill('utility_bill'),
  receipt('receipt'),
  invoice('invoice'),
  meterPhoto('meter_photo'),
  propertyPaper('property_paper'),
  other('other');

  new(this.db);

  @override
  final String db;

  static DocumentKind parse(String name) => parseDbEnum(values, name);
}

/// What a document is attached to (`public.document_entity`).
enum DocumentEntity with DbEnum {
  property('property'),
  unit('unit'),
  tenant('tenant'),
  lease('lease'),
  payment('payment'),
  expense('expense'),
  maintenanceRequest('maintenance_request'),
  utilityBill('utility_bill'),
  meterReading('meter_reading');

  new(this.db);

  @override
  final String db;

  static DocumentEntity parse(String name) => parseDbEnum(values, name);

  /// The table of these records (`private.document_entity_table`).
  String get table => switch (this) {
    property => 'properties',
    unit => 'units',
    tenant => 'tenants',
    lease => 'leases',
    payment => 'payments',
    expense => 'expenses',
    maintenanceRequest => 'maintenance_requests',
    utilityBill => 'utility_bills',
    meterReading => 'meter_readings',
  };

  /// The column of [table] that, once set, closes a record to new
  /// documents in the app: an archived property, unit or tenant, or a
  /// voided payment, whose screens offer no "Add document" (their
  /// `DocumentsSection.canAdd`). Null for the records that always take
  /// documents.
  String? get closedColumn => switch (this) {
    property || unit || tenant => 'archived_at',
    payment => 'voided_at',
    lease => null,
    expense => null,
    maintenanceRequest => null,
    utilityBill => null,
    meterReading => null,
  };

  /// The kinds offered first for a document of this record, the likeliest
  /// first; the other kinds follow them.
  List<DocumentKind> get suggestedKinds => switch (this) {
    tenant => const [
      DocumentKind.cnicFront,
      DocumentKind.cnicBack,
      DocumentKind.photo,
    ],
    lease => const [
      DocumentKind.tenancyAgreement,
      DocumentKind.policeRegistration,
      DocumentKind.rentRegistration,
    ],
    unit => const [
      DocumentKind.photo,
      DocumentKind.meterPhoto,
      DocumentKind.utilityBill,
    ],
    property => const [
      DocumentKind.propertyPaper,
      DocumentKind.photo,
      DocumentKind.utilityBill,
    ],
    payment => const [DocumentKind.receipt],
    expense => const [DocumentKind.invoice, DocumentKind.receipt],
    maintenanceRequest => const [DocumentKind.photo, DocumentKind.invoice],
    utilityBill => const [DocumentKind.utilityBill, DocumentKind.receipt],
    meterReading => const [DocumentKind.meterPhoto],
  };

  /// Every kind, [suggestedKinds] first.
  List<DocumentKind> get kindsInOrder => [
    ...suggestedKinds,
    for (final kind in DocumentKind.values)
      if (!suggestedKinds.contains(kind)) kind,
  ];
}

/// The record a document is attached to.
typedef DocumentOwner = ({DocumentEntity entity, String id});

/// The file types the `documents` bucket accepts (its
/// `allowed_mime_types` and the `documents_mime_type_check`), with the
/// extension a stored file's name ends in.
enum DocumentFileType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp'),
  heic('image/heic', 'heic'),
  pdf('application/pdf', 'pdf');

  new(this.mimeType, this.extension);

  /// The MIME type stored with the file and its row.
  final String mimeType;

  /// The extension of the stored file's name.
  final String extension;

  bool get isImage => this != pdf;

  /// The type whose MIME type is [mimeType]; throws [FormatException] for
  /// any other.
  static DocumentFileType parse(String mimeType) => values.firstWhere(
    (type) => type.mimeType == mimeType,
    orElse: () => throw FormatException('unknown file type', mimeType),
  );

  /// The type [bytes] are, read from their first bytes (never from a file
  /// name, which can say anything), or null for any other kind of file.
  static DocumentFileType? sniff(List<int> bytes) {
    bool startsWith(List<int> prefix, [int offset = 0]) {
      if (bytes.length < offset + prefix.length) return false;
      for (var i = 0; i < prefix.length; i++) {
        if (bytes[offset + i] != prefix[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return jpeg;
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return png;
    }
    // RIFF....WEBP
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return webp;
    }
    if (startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) return pdf; // %PDF-
    // An ISO base media file (....ftyp) that says it holds HEVC images.
    if (startsWith(const [0x66, 0x74, 0x79, 0x70], 4)) {
      final brands = _brands(bytes);
      // An AVIF can carry the generic HEIF brands too (`mif1`, `msf1`):
      // it is an AV1 image, not HEIC.
      if (brands.any(_av1Brands.contains)) return null;
      if (brands.any(_hevcBrands.contains)) return heic;
    }
    return null;
  }

  /// The brands of an ISO base media file's `ftyp` box: its major brand
  /// and its compatible brands.
  static List<String> _brands(List<int> bytes) {
    if (bytes.length < 12) return const [];
    // The box's size, a 32-bit big-endian count that includes its header;
    // a size below the minimum (0: to the end of the file, 1: a 64-bit
    // size follows) leaves only the major brand to read.
    final declared = bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
    final end = math.min(declared < 16 ? 12 : declared, bytes.length);
    String brandAt(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    return [
      brandAt(8),
      // The minor version (bytes 12 to 15) is skipped.
      for (var offset = 16; offset + 4 <= end; offset += 4) brandAt(offset),
    ];
  }

  /// The brands of HEIF files whose images are HEVC: HEIC.
  static const _hevcBrands = {'heic', 'heix', 'heim', 'heis', 'hevc', 'hevx'};

  /// The brands of HEIF files whose images are AV1: AVIF.
  static const _av1Brands = {'avif', 'avis'};
}

/// A stored file's metadata (`public.documents`): what it is, what it is
/// attached to and where its file is in the private `documents` bucket.
@immutable
final class Document {
  const new({
    required this.id,
    required this.owner,
    required this.kind,
    required this.storagePath,
    required this.fileName,
    required this.fileType,
    required this.sizeBytes,
    required this.createdAt,
  });

  /// Reads a `documents` row selected with [Document.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'document');
    final createdAt = row.string('created_at');
    // Checked here, so a malformed row fails where it is read rather than
    // where it is shown.
    if (DateTime.tryParse(createdAt) == null) {
      throw FormatException('created_at is not a timestamp', createdAt);
    }
    return Document(
      id: row.string('id'),
      owner: (
        entity: row.choice('entity_type', DocumentEntity.parse),
        id: row.string('entity_id'),
      ),
      kind: row.choice('kind', DocumentKind.parse),
      storagePath: row.string('storage_path'),
      fileName: row.string('file_name'),
      fileType: row.choice('mime_type', DocumentFileType.parse),
      sizeBytes: row.integer('size_bytes'),
      createdAt: createdAt,
    );
  }

  /// The columns [Document.fromRow] reads.
  static const columns =
      'id,entity_type,entity_id,kind,storage_path,file_name,mime_type,'
      'size_bytes,created_at';

  /// The longest name the database accepts (`documents_file_name_check`).
  static const maxNameLength = 200;

  /// The largest file the bucket and the row accept (10 MB,
  /// `file_size_limit` and `documents_size_bytes_check`).
  static const maxSizeBytes = 10485760;

  final String id;
  final DocumentOwner owner;
  final DocumentKind kind;

  /// `<portfolio>/<entity type>/<entity id>/<uuid>.<extension>`.
  final String storagePath;

  /// The name the landlord sees (not the stored file's name).
  final String fileName;
  final DocumentFileType fileType;
  final int sizeBytes;

  /// The timestamp exactly as PostgREST wrote it (for paging).
  final String createdAt;

  /// When it was uploaded, in UTC.
  DateTime get uploadedAt => DateTime.parse(createdAt).toUtc();

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// This document renamed to [fileName] and of [kind].
  Document copyWith({String? fileName, DocumentKind? kind}) => Document(
    id: id,
    owner: owner,
    kind: kind ?? this.kind,
    storagePath: storagePath,
    fileName: fileName ?? this.fileName,
    fileType: fileType,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
  );

  /// The row [Document.fromRow] reads back (for the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    'entity_type': owner.entity.db,
    'entity_id': owner.id,
    'kind': kind.db,
    'storage_path': storagePath,
    'file_name': fileName,
    'mime_type': fileType.mimeType,
    'size_bytes': sizeBytes,
    'created_at': createdAt,
  };

  @override
  bool operator ==(Object other) =>
      other is Document &&
      other.id == id &&
      other.owner == owner &&
      other.kind == kind &&
      other.storagePath == storagePath &&
      other.fileName == fileName &&
      other.fileType == fileType &&
      other.sizeBytes == sizeBytes &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    owner,
    kind,
    storagePath,
    fileName,
    fileType,
    sizeBytes,
    createdAt,
  );
}

/// The name a document is saved under: [name] on one line, without the
/// characters the database refuses, at most [Document.maxNameLength] long.
///
/// The database counts code points (`char_length`), and a letter with its
/// marks or an emoji is several of them ("بَ" is two), so a name of 200
/// characters as a reader counts them can still be too long: whole
/// characters are then dropped from its end until it fits.
String documentName(String name) {
  var characters = singleLineWithin(name, Document.maxNameLength).characters;
  while (_tooLong(characters.string)) {
    characters = characters.skipLast(1);
  }
  return characters.string.trimRight();
}

/// Whether [typed], once tidied, is longer than the database takes, so
/// that [documentName] would have to cut it: a form says so instead.
bool documentNameTooLong(String typed) => _tooLong(sanitizeSingleLine(typed));

/// Whether [name] has more code points than `documents_file_name_check`
/// allows (`char_length`, at most [Document.maxNameLength]).
bool _tooLong(String name) => name.runes.length > Document.maxNameLength;

/// A file ready to upload: its bytes, what they are, and the name the
/// landlord gave it.
@immutable
final class PreparedFile {
  const new({
    required this.name,
    required this.bytes,
    required this.type,
    required this.originalSize,
  });

  /// The name the file had where it was picked, without folders.
  final String name;
  final Uint8List bytes;
  final DocumentFileType type;

  /// Its size before it was made smaller (the same when it was not).
  final int originalSize;

  int get size => bytes.length;

  /// Whether it was made smaller before upload (DOC-02).
  bool get compressed => size < originalSize;
}
