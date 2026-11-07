import 'package:flutter/widgets.dart';

import 'package:mm_ui_gallery/src/app.dart';
import 'package:mm_ui_gallery/src/settings.dart';

/// Runs the gallery. On the web, the address can choose the page and the
/// settings it opens with, for screenshots and test scripts:
/// `?page=charts&lang=ur&theme=dark&contrast=high&text=200&grouping=western`.
void main() {
  final query = Uri.base.queryParameters;
  runApp(
    GalleryApp(
      settings: GallerySettings.fromQuery(query),
      family: GalleryFamily.named(query['page']) ?? GalleryFamily.actions,
    ),
  );
}
