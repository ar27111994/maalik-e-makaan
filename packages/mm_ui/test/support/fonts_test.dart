import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'testing.dart';

/// The bounding box of what [icon] inks in its 48 dp square.
Future<Rect> _inkOf(WidgetTester tester, IconData icon) async {
  const key = Key('icon');
  await tester.pumpWidget(
    themed(
      Center(
        child: RepaintBoundary(key: key, child: Icon(icon, size: 48)),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(boundary.toImage))!;
  final bytes = (await tester.runAsync(image.toByteData))!;
  var ink = Rect.zero;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (bytes.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
      final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
      ink = ink.isEmpty ? pixel : ink.expandToInclude(pixel);
    }
  }
  image.dispose();
  return ink;
}

void main() {
  testWidgets("Material's icon font is loaded: arrows, not boxes", (
    tester,
  ) async {
    // Without the font each glyph is the test font's box, as wide and as
    // tall as the em; Material's arrows are much narrower or flatter.
    final left = await _inkOf(tester, Icons.chevron_left);
    final right = await _inkOf(tester, Icons.chevron_right);
    final dropDown = await _inkOf(tester, Icons.arrow_drop_down);
    expect(left.width, lessThan(48 / 2));
    expect(right.width, lessThan(48 / 2));
    // The two chevrons point opposite ways from the middle.
    expect(left.center.dx, lessThan(right.center.dx));
    expect(dropDown.height, lessThan(48 / 3));
  });
}
