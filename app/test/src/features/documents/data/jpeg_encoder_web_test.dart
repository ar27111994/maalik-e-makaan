// The browser's encoder; run with `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maalik_e_makaan/src/features/documents/data/jpeg_encoder.dart';

void main() {
  test('the browser encodes a JPEG on white, without metadata', () async {
    // 32 x 16: the left half opaque green, the right half transparent.
    const width = 32;
    const height = 16;
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width ~/ 2; x++) {
        final i = (y * width + x) * 4;
        rgba
          ..[i + 1] = 160
          ..[i + 3] = 255;
      }
    }
    final jpeg = await encodeJpeg((
      width: width,
      height: height,
      rgba: rgba,
    ), 90);
    expect(jpeg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    // No Exif segment (APP1) before the image.
    for (var i = 2; i + 3 < jpeg.length && jpeg[i] == 0xFF;) {
      expect(jpeg[i + 1], isNot(0xE1));
      if (jpeg[i + 1] == 0xDA) break;
      i += 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
    }
    final decoded = img.decodeJpg(jpeg)!;
    expect((decoded.width, decoded.height), (width, height));
    final white = decoded.getPixel(28, 8);
    expect(white.r, greaterThan(245));
    expect(white.g, greaterThan(245));
    expect(white.b, greaterThan(245));
    final green = decoded.getPixel(4, 8);
    expect(green.g, greaterThan(140));
    expect(green.r, lessThan(30));
  });
}
