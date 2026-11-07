import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';

import '../support/testing.dart';

const _title = 'Tenants';
const _long = 'Gulberg Heights, Block C, Main Boulevard, Lahore';

/// A button 100 dp wide whose words sit 16 dp inside each of its edges.
const _end = SizedBox(width: 100, height: MmSize.minTarget);

/// A heading and [end] in a column [width] wide, hanging [overhang] out.
Widget _header({
  String title = _title,
  Widget end = _end,
  double overhang = MmSpace.s4,
  bool stackedAtEnd = false,
  double width = 296,
}) => SizedBox(
  width: width,
  child: MmReflow(
    endOverhang: overhang,
    stackedAtEnd: stackedAtEnd,
    start: Text(title),
    end: end,
  ),
);

Rect _endRect(WidgetTester tester) => tester.getRect(find.byWidget(_end).first);

void main() {
  group('MmReflow.endOverhang', () {
    testWidgets('hangs the end widget past the end edge beside the text', (
      tester,
    ) async {
      await pumpThemed(tester, _header());
      final box = tester.getRect(find.byType(MmReflow));
      expect(_endRect(tester).right, box.right + MmSpace.s4);
      expect(tester.getRect(find.text(_title)).left, box.left);

      await pumpThemed(tester, _header(), variant: MmVariant.urdu);
      expect(_endRect(tester).left, box.left - MmSpace.s4);
    });

    testWidgets('hangs it past the start edge when it moves under the text', (
      tester,
    ) async {
      await pumpThemed(tester, _header(title: _long, width: 200));
      final box = tester.getRect(find.byType(MmReflow));
      final title = tester.getRect(find.text(_long));
      expect(_endRect(tester).top, greaterThan(title.top));
      expect(_endRect(tester).left, box.left - MmSpace.s4);

      await pumpThemed(
        tester,
        _header(title: _long, width: 200),
        variant: MmVariant.urdu,
      );
      expect(_endRect(tester).right, box.right + MmSpace.s4);
    });

    testWidgets('stacked at the end, it hangs past the end edge', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _header(title: _long, width: 200, stackedAtEnd: true),
      );
      final box = tester.getRect(find.byType(MmReflow));
      expect(_endRect(tester).right, box.right + MmSpace.s4);
    });

    testWidgets('counts only the part inside when deciding what fits', (
      tester,
    ) async {
      // The title and the 84 dp of the end widget inside the box, with the
      // 16 dp between them, fit exactly.
      final title = await _titleWidth(tester);
      await pumpThemed(tester, _header(width: title + MmSpace.s4 + 84));
      expect(
        _endRect(tester).top,
        tester.getRect(find.byType(MmReflow)).top,
        reason: 'side by side',
      );
      expect(
        tester
            .renderObject<RenderBox>(find.byType(MmReflow))
            .getMaxIntrinsicWidth(double.infinity),
        title + MmSpace.s4 + 84,
      );
    });

    testWidgets('never hangs out so far that less than 48 dp stays inside', (
      tester,
    ) async {
      const narrow = SizedBox(width: 56, height: MmSize.minTarget);
      await pumpThemed(tester, _header(end: narrow));
      final box = tester.getRect(find.byType(MmReflow));
      final end = tester.getRect(find.byWidget(narrow));
      expect(box.right - end.left, MmSize.minTarget);
      expect(end.right, box.right + 8);

      const tiny = SizedBox(width: 40, height: MmSize.minTarget);
      await pumpThemed(tester, _header(end: tiny));
      expect(
        tester.getRect(find.byWidget(tiny)).right,
        tester.getRect(find.byType(MmReflow)).right,
      );
    });

    testWidgets('takes taps on the part that hangs out, and only there', (
      tester,
    ) async {
      var taps = 0;
      // Right inside the padding, which reaches past the reflow's edges.
      await pumpThemed(
        tester,
        Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: MmReflow(
            endOverhang: MmSpace.s4,
            start: const Text(_title),
            end: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: _end,
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(MmReflow));
      await tester.tapAt(Offset(box.right + 8, box.center.dy));
      expect(taps, 1);
      // Below the box, inside the padding: no child is there.
      await tester.tapAt(Offset(box.right - 8, box.bottom + 8));
      expect(taps, 1);
      // Between the title and the end widget: nothing either.
      final title = tester.getRect(find.text(_title));
      await tester.tapAt(Offset(title.right + 8, box.center.dy));
      expect(taps, 1);
    });

    testWidgets('sizes to its content without a width limit', (tester) async {
      await pumpThemed(
        tester,
        const UnconstrainedBox(
          child: MmReflow(
            endOverhang: MmSpace.s4,
            start: Text(_title),
            end: _end,
          ),
        ),
      );
      final title = tester.getSize(find.text(_title)).width;
      final box = tester.getRect(find.byType(MmReflow));
      expect(box.width, title + MmSpace.s4 + 84);
      expect(_endRect(tester).right, box.right + MmSpace.s4);
    });

    testWidgets('lays out again when the overhang changes', (tester) async {
      await pumpThemed(tester, _header(overhang: 0));
      final box = tester.getRect(find.byType(MmReflow));
      expect(_endRect(tester).right, box.right);
      await pumpThemed(tester, _header());
      expect(_endRect(tester).right, box.right + MmSpace.s4);
      final render = tester.renderObject<RenderMmReflow>(find.byType(MmReflow));
      expect(render.endOverhang, MmSpace.s4);
    });

    test('must not be negative', () {
      expect(
        () => MmReflow(start: const Text(_title), endOverhang: -1),
        throwsAssertionError,
      );
    });
  });
}

/// The width of [_title] laid out alone.
Future<double> _titleWidth(WidgetTester tester) async {
  await pumpThemed(tester, const Text(_title));
  return tester.getSize(find.text(_title)).width;
}
