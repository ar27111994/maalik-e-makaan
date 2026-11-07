import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Material that paints the surface of the widget found by [widget].
Material surfaceOf(WidgetTester tester, Finder widget) => tester.widget(
  find.descendant(of: widget, matching: find.byType(Material)).first,
);

/// The border of the surface of the widget found by [widget].
BorderSide sideOf(WidgetTester tester, Finder widget) =>
    (surfaceOf(tester, widget).shape! as OutlinedBorder).side;

/// The bounds of the ink inside the circle that [boundary] holds: the
/// pixels that differ clearly from the circle's [fill], in logical pixels
/// from the boundary's top left.
Future<Rect> inkOnCircle(
  WidgetTester tester,
  Finder boundary,
  Color fill,
) async {
  const pixelRatio = 4.0;
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final image = (await tester.runAsync(
    () => render.toImage(pixelRatio: pixelRatio),
  ))!;
  // Raw RGBA, the default.
  final data = (await tester.runAsync(image.toByteData))!;
  int channel(double value) => (value * 255).round();
  final (r, g, b) = (channel(fill.r), channel(fill.g), channel(fill.b));
  // Inside the circle, clear of its anti-aliased edge.
  final radius = image.width / 2 - 2 * pixelRatio;
  var ink = Rect.zero;
  var found = false;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x + 0.5 - image.width / 2;
      final dy = y + 0.5 - image.height / 2;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (y * image.width + x) * 4;
      final distance =
          (data.getUint8(i) - r).abs() +
          (data.getUint8(i + 1) - g).abs() +
          (data.getUint8(i + 2) - b).abs();
      if (distance <= 90) continue;
      final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
      ink = found ? ink.expandToInclude(pixel) : pixel;
      found = true;
    }
  }
  expect(found, isTrue, reason: 'no ink on the circle');
  return Rect.fromLTRB(
    ink.left / pixelRatio,
    ink.top / pixelRatio,
    ink.right / pixelRatio,
    ink.bottom / pixelRatio,
  );
}
