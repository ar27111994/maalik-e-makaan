import 'dart:typed_data';

import 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder_io.dart'
    if (dart.library.js_interop) 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder_web.dart'
    as platform;

/// An image's pixels: RGBA, not premultiplied
/// (`ui.ImageByteFormat.rawStraightRgba`), row by row.
typedef RgbaPixels = ({int width, int height, Uint8List rgba});

/// [pixels] as a JPEG of [quality] (1 to 100), on white where they are
/// transparent, with no metadata.
///
/// On a device it is encoded in a background isolate (package:image). In a
/// browser `compute` has no isolate, and package:image's encoder would hold
/// up the page for each try, so the browser's own encoder does it (a
/// canvas).
Future<Uint8List> encodeJpeg(RgbaPixels pixels, int quality) =>
    platform.encodeJpeg(pixels, quality);
