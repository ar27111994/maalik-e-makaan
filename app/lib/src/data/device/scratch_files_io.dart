import 'dart:io';

/// Deletes one entry of the app's folders; tests replace it to make an entry
/// that cannot be deleted.
typedef Deleter = Future<void> Function(FileSystemEntity entry);

Future<void> _deleteEntry(FileSystemEntity entry) =>
    entry.delete(recursive: true);

/// The system's temporary folder: on iOS, the app's own `tmp/`, where the
/// camera and the file picker leave their copies.
String systemTempPath() => Directory.systemTemp.path;

const _uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

/// A folder share_plus makes for each file it writes to share
/// (`<uuid>/<file name>`); image_picker's gallery copies take the same
/// shape on Android.
final _sharedFolder = RegExp('^$_uuid\$', caseSensitive: false);

/// A photo image_picker took with the camera on Android, and its resized
/// copy: `<uuid><digits>.jpg`, `scaled_<uuid><digits>.jpg`.
final _cameraCopy = RegExp(
  '^(scaled_)?$_uuid[0-9]*\\.[a-z0-9]+\$',
  caseSensitive: false,
);

/// Where share_plus copies a file on Android for the app it is shared with.
const _shareCopies = 'share_plus';

/// Deletes each of [paths] that is a file inside one of [roots], and
/// nothing else: not a folder, not a link, nothing outside them. It never
/// throws: a path that cannot be checked or deleted is left.
Future<void> deleteCopies(
  Iterable<String> roots,
  Iterable<String> paths, {
  Deleter delete = _deleteEntry,
}) async {
  final bases = <String>[];
  for (final root in roots) {
    try {
      bases.add(await Directory(root).resolveSymbolicLinks());
    } on FileSystemException {
      // A folder that does not exist holds nothing to delete.
    }
  }
  for (final path in paths) {
    try {
      if (FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      final parent = await File(path).parent.resolveSymbolicLinks();
      if (bases.any((base) => _within(base, parent))) {
        await delete(File(path));
      }
    } on FileSystemException {
      // Gone already, or not the app's to delete.
    }
  }
}

/// Whether [path] is [base] or inside it (both resolved).
bool _within(String base, String path) =>
    path == base || path.startsWith('$base${Platform.pathSeparator}');

/// Deletes the copies the app's plugins left in [root], the app's cache
/// folder, and nothing else in it:
///
/// - share_plus's folders of files written to share (`<uuid>/`), and
///   Android's `share_plus/` copies, when nothing in them changed after
///   [sharedBefore]: a file shared more recently may still be read by the
///   app it was shared with;
/// - when [copiesBefore] is given, the camera's photos on Android (and their
///   resized copies) last changed before it, so that nothing written after
///   the sweep started is touched.
///
/// Links are neither followed nor deleted. An entry that cannot be read or
/// deleted is left, and the rest go on; a missing [root] holds nothing.
Future<void> sweepFolder(
  String root, {
  required DateTime sharedBefore,
  DateTime? copiesBefore,
  Deleter delete = _deleteEntry,
}) async {
  final List<FileSystemEntity> entries;
  try {
    entries = await Directory(root).list(followLinks: false).toList();
  } on FileSystemException {
    return;
  }
  for (final entry in entries) {
    final name = entry.path.split(Platform.pathSeparator).last;
    try {
      if (entry is Directory && _sharedFolder.hasMatch(name)) {
        await _deleteIfOlder(entry, sharedBefore, delete);
      } else if (entry is Directory && name == _shareCopies) {
        await for (final copy in entry.list(followLinks: false)) {
          await _deleteIfOlder(copy, sharedBefore, delete);
        }
      } else if (entry is File &&
          copiesBefore != null &&
          _cameraCopy.hasMatch(name)) {
        await _deleteIfOlder(entry, copiesBefore, delete);
      }
    } on FileSystemException {
      // Changed or locked while it was looked at: the next sweep tries again.
    }
  }
}

/// Deletes each entry of [folder] that, with everything in it, last changed
/// before [before]: the pickers' copies (file_picker's `<time>/` and
/// `<uuid>/` folders, the camera's photos on iOS). A copy made since keeps
/// it: a picker copies a file into a folder it has just made, whose time is
/// new even when the copy keeps its original's. Links are neither followed
/// nor deleted; an entry that cannot be read or deleted is left, and the
/// rest go on; a missing [folder] holds nothing.
Future<void> sweepOlder(
  String folder,
  DateTime before, {
  Deleter delete = _deleteEntry,
}) async {
  final List<FileSystemEntity> entries;
  try {
    entries = await Directory(folder).list(followLinks: false).toList();
  } on FileSystemException {
    return;
  }
  for (final entry in entries) {
    try {
      await _deleteIfOlder(entry, before, delete);
    } on FileSystemException {
      // Changed or locked while it was looked at: the next sweep tries again.
    }
  }
}

/// Deletes [entry] when it, and everything in it, last changed before
/// [before]. Links are left.
Future<void> _deleteIfOlder(
  FileSystemEntity entry,
  DateTime before,
  Deleter delete,
) async {
  if (entry is Link) return;
  var newest = entry.statSync().modified;
  if (entry is Directory) {
    await for (final inner in entry.list(recursive: true, followLinks: false)) {
      if (inner is Link) continue;
      final modified = inner.statSync().modified;
      if (modified.isAfter(newest)) newest = modified;
    }
  }
  if (newest.isBefore(before)) await delete(entry);
}
