import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The key of the heading above the row on the page [pumpOnPage] pumps.
const pageHeadingKey = ValueKey<String>('page-heading');

/// Pumps [row] on an [MmPage] under a heading and a text field, as a form
/// holds it, in a window [width] wide, in [variant]; returns the page's
/// content column: where the heading and the field start and end.
Future<Rect> pumpOnPage(
  WidgetTester tester,
  Widget row, {
  double width = 360,
  MmVariant variant = MmVariant.light,
}) async {
  await pumpScreen(
    tester,
    MmPage(
      title: 'Settings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          const MmSectionHeader(key: pageHeadingKey, title: 'Reminders'),
          const MmTextField(label: 'Message'),
          row,
        ],
      ),
    ),
    size: Size(width, 900),
    variant: variant,
  );
  final heading = tester.getRect(find.byKey(pageHeadingKey));
  final field = tester.getRect(find.byType(TextField));
  expect(field.left, heading.left);
  expect(field.right, heading.right);
  return heading;
}

/// Expects the tile around [control] to reach [MmSpace.s4] past [content]
/// on both sides, into the page's gutter, as its ink and focus ring do.
void expectTileInGutter(WidgetTester tester, Finder control, Rect content) {
  final tile = tester.getRect(
    find.ancestor(of: control, matching: find.byType(ListTile)),
  );
  expect(tile.left, content.left - MmSpace.s4);
  expect(tile.right, content.right + MmSpace.s4);
}

/// Where the screen is inked in [region] (global, in logical pixels at a
/// device pixel ratio of 1): the bounding box of the pixels that differ
/// from the page colour by more than anti-aliasing does, so a control's
/// visible box, ring or track rather than its touch target.
Future<Rect> inkIn(WidgetTester tester, Rect region) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(screenKey),
  );
  final image = (await tester.runAsync(boundary.toImage))!;
  final bytes = (await tester.runAsync(image.toByteData))!;
  int channel(int x, int y, int offset) =>
      bytes.getUint8((y * image.width + x) * 4 + offset);
  final page = [for (var c = 0; c < 3; c++) channel(0, 0, c)];
  var ink = Rect.zero;
  for (var y = region.top.floor(); y < region.bottom.ceil(); y++) {
    for (var x = region.left.floor(); x < region.right.ceil(); x++) {
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      var difference = 0;
      for (var c = 0; c < 3; c++) {
        difference += (channel(x, y, c) - page[c]).abs();
      }
      if (difference < 96) continue;
      final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
      ink = ink.isEmpty ? pixel : ink.expandToInclude(pixel);
    }
  }
  image.dispose();
  return ink;
}

/// Expects the visible part of the control in [region] to start on
/// [content]'s start edge ([atStart]) or end on its end edge, in the
/// direction of [variant], within a pixel of anti-aliasing.
Future<void> expectInkOnEdge(
  WidgetTester tester,
  Rect region,
  Rect content, {
  required MmVariant variant,
  required bool atStart,
}) async {
  final ink = await inkIn(tester, region);
  final urdu = variant == MmVariant.urdu;
  // In Urdu the start edge is the right one.
  if (atStart != urdu) {
    expect(ink.left, closeTo(content.left, 1), reason: 'ink $ink');
  } else {
    expect(ink.right, closeTo(content.right, 1), reason: 'ink $ink');
  }
}
