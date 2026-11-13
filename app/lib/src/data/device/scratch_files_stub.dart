// The web build: the app writes no files there (image_picker and
// file_picker keep picked files in memory), so there is nothing to delete.
// Native builds use scratch_files_io.dart.

/// No system temporary folder on the web.
String? systemTempPath() => null;

/// Nothing to delete on the web.
Future<void> deleteCopies(
  Iterable<String> roots,
  Iterable<String> paths,
) async {}

/// Nothing to sweep on the web.
Future<void> sweepFolder(
  String root, {
  required DateTime sharedBefore,
  DateTime? copiesBefore,
}) async {}

/// Nothing to sweep on the web.
Future<void> sweepOlder(String folder, DateTime before) async {}
