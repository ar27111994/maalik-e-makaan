import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder.dart';

/// `encodeJpeg` on a device: package:image in a background isolate.
Future<Uint8List> encodeJpeg(RgbaPixels pixels, int quality) =>
    compute(_encode, (pixels, quality));

/// [input]'s pixels as a JPEG of its quality, on white: a pixel's colour
/// on white is its colour where it is opaque, and white where its
/// transparency lets white through.
Uint8List _encode((RgbaPixels, int) input) {
  final (pixels, quality) = input;
  final rgba = pixels.rgba;
  final rgb = Uint8List(pixels.width * pixels.height * 3);
  for (var i = 0, j = 0; j < rgb.length; i += 4, j += 3) {
    final alpha = rgba[i + 3];
    final through = 255 - alpha;
    rgb[j] = (rgba[i] * alpha + 127) ~/ 255 + through;
    rgb[j + 1] = (rgba[i + 1] * alpha + 127) ~/ 255 + through;
    rgb[j + 2] = (rgba[i + 2] * alpha + 127) ~/ 255 + through;
  }
  final image = img.Image.fromBytes(
    width: pixels.width,
    height: pixels.height,
    bytes: rgb.buffer,
    numChannels: 3,
  );
  return img.encodeJpg(image, quality: quality);
}
