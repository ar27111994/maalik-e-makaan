import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder.dart';
import 'package:web/web.dart' as web;

/// `encodeJpeg` in a browser: the pixels are drawn over white on a canvas,
/// which the browser encodes in the background (`toBlob`).
Future<Uint8List> encodeJpeg(RgbaPixels pixels, int quality) async {
  final RgbaPixels(:width, :height) = pixels;
  final layer = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  try {
    // Putting pixels replaces what is there; drawing them blends them, so
    // the transparent ones show the white under them.
    layer.context2D.putImageData(
      web.ImageData(
        Uint8ClampedList.sublistView(pixels.rgba).toJS,
        width,
        height.toJS,
      ),
      0,
      0,
    );
    canvas.context2D
      ..fillStyle = 'white'.toJS
      ..fillRect(0, 0, width, height)
      ..drawImage(layer, 0, 0);
    final encoded = Completer<web.Blob?>();
    void done(web.Blob? blob) => encoded.complete(blob);
    canvas.toBlob(done.toJS, 'image/jpeg', (quality / 100).toJS);
    final blob = await encoded.future;
    if (blob == null) throw StateError('The browser did not encode a JPEG.');
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    // A canvas holds its pixels until it is collected; free them now.
    for (final each in [layer, canvas]) {
      each
        ..width = 0
        ..height = 0;
    }
  }
}
