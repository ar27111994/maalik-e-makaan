import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';

import '../support/testing.dart';

const _start = Text('Ali Raza');
const _below = Text('Flat 3, Gulberg III, Lahore');
const _end = Text('Rs 45,000');

RenderMmReflow _render(WidgetTester tester) =>
    tester.renderObject(find.byType(MmReflow));

double _width(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).width;

const _label = 'Tenant';
const _value = 'Ali Raza';
const _long = 'House 12, Street 4, Gulberg III, Lahore';

/// A label in the small body style and a value in the body style, as on a
/// receipt row (different sizes, so their baselines differ from their
/// tops).
Widget _line({
  String start = _label,
  String end = _value,
  MmReflowAlignment alignment = MmReflowAlignment.baseline,
  bool stackedAtEnd = false,
  double width = 296,
}) => SizedBox(
  width: width,
  child: Builder(
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return MmReflow(
        alignment: alignment,
        stackedAtEnd: stackedAtEnd,
        start: Text(start, style: text.bodyMedium),
        end: Text(end, style: text.bodyLarge),
      );
    },
  ),
);

/// The distance from the top of the screen to [text]'s first baseline.
double _baselineOf(WidgetTester tester, String text) {
  final paragraph = paragraphOf(tester, text);
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

void main() {
  group('MmReflow', () {
    testWidgets('reports its natural and narrowest widths', (tester) async {
      await pumpThemed(
        tester,
        const MmReflow(start: _start, below: _below, end: _end),
      );
      final render = _render(tester);
      final start = _width(tester, 'Ali Raza');
      final below =
          render.getMaxIntrinsicWidth(double.infinity) -
          MmReflow.spacing -
          _width(tester, 'Rs 45,000');
      // The natural width puts the end beside the wider of the text lines.
      expect(below, greaterThan(start));
      expect(
        render.getMaxIntrinsicWidth(double.infinity),
        moreOrLessEquals(
          tester
                  .renderObject<RenderBox>(
                    find.text('Flat 3, Gulberg III, Lahore'),
                  )
                  .getMaxIntrinsicWidth(double.infinity) +
              MmReflow.spacing +
              tester
                  .renderObject<RenderBox>(find.text('Rs 45,000'))
                  .getMaxIntrinsicWidth(double.infinity),
        ),
      );
      // The narrowest width stacks everything: the widest single word.
      final narrowest = render.getMinIntrinsicWidth(double.infinity);
      expect(narrowest, lessThan(start));
      expect(narrowest, greaterThan(0));

      await pumpThemed(tester, const MmReflow(start: _start));
      expect(
        _render(tester).getMaxIntrinsicWidth(double.infinity),
        moreOrLessEquals(_width(tester, 'Ali Raza')),
      );
    });

    testWidgets('reports its height for a width, side by side or stacked', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmReflow(start: _start, below: _below, end: _end),
      );
      final render = _render(tester);
      final wide = render.getMinIntrinsicHeight(1000);
      expect(render.getMaxIntrinsicHeight(1000), wide);
      // The two text lines beside the end widget.
      final line = tester.getSize(find.text('Ali Raza')).height;
      expect(wide, line + tester.getSize(find.text(_below.data!)).height);
      final narrow = render.getMinIntrinsicHeight(100);
      expect(render.getMaxIntrinsicHeight(100), narrow);
      expect(narrow, greaterThan(wide + MmReflow.runSpacing + line));
      expect(
        render.getDryLayout(const BoxConstraints(maxWidth: 328)),
        render.size,
      );
    });

    testWidgets('sizes to an IntrinsicHeight and IntrinsicWidth parent', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const IntrinsicWidth(
          child: IntrinsicHeight(
            child: MmReflow(start: _start, below: _below, end: _end),
          ),
        ),
      );
      final render = _render(tester);
      expect(
        render.size.width,
        moreOrLessEquals(render.getMaxIntrinsicWidth(double.infinity)),
      );
      // Side by side: the end sits at the end edge.
      expect(
        tester.getRect(find.text('Rs 45,000')).right,
        tester.getRect(find.byType(MmReflow)).right,
      );
    });

    testWidgets('lays out side by side at natural widths when unbounded', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const UnconstrainedBox(
          child: MmReflow(start: _start, below: _below, end: _end),
        ),
      );
      final render = _render(tester);
      expect(
        render.size.width,
        moreOrLessEquals(render.getMaxIntrinsicWidth(double.infinity)),
      );
      await pumpThemed(
        tester,
        const UnconstrainedBox(
          child: MmReflow(start: _start, below: _below),
        ),
      );
      expect(
        _render(tester).size.width,
        moreOrLessEquals(_width(tester, 'Flat 3, Gulberg III, Lahore')),
      );
    });

    testWidgets('has the first baseline of its start text, laid out or dry', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Tenant', style: TextStyle(fontSize: 40)),
            Expanded(
              child: MmReflow(
                alignment: MmReflowAlignment.baseline,
                start: Text('Ali Raza'),
                end: Text('Paid', style: TextStyle(fontSize: 30)),
              ),
            ),
          ],
        ),
      );
      final render = _render(tester);
      final constraints = render.constraints;
      final dry = render.getDryBaseline(constraints, TextBaseline.alphabetic)!;
      final start = tester.renderObject<RenderParagraph>(find.text('Ali Raza'));
      final startTop =
          start.localToGlobal(Offset.zero).dy -
          render.localToGlobal(Offset.zero).dy;
      expect(
        dry,
        moreOrLessEquals(
          startTop +
              start.getDryBaseline(start.constraints, TextBaseline.alphabetic)!,
        ),
      );
      // The row lined the reflow's baseline up with its other child's.
      final tenant = tester.renderObject<RenderParagraph>(find.text('Tenant'));
      double baselineOf(RenderParagraph paragraph) =>
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
      expect(baselineOf(start), moreOrLessEquals(baselineOf(tenant)));
    });

    testWidgets('centres an end widget without a baseline', (tester) async {
      await pumpThemed(
        tester,
        const MmReflow(
          alignment: MmReflowAlignment.baseline,
          start: _start,
          end: SizedBox(width: 20, height: 60),
        ),
      );
      final box = tester.getRect(find.byType(SizedBox).last);
      final text = tester.getRect(find.text('Ali Raza'));
      expect(text.center.dy, moreOrLessEquals(box.center.dy));
    });

    testWidgets('relays out when its alignment or direction changes', (
      tester,
    ) async {
      var alignment = MmReflowAlignment.center;
      var direction = TextDirection.ltr;
      late StateSetter update;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Directionality(
              textDirection: direction,
              child: MmReflow(
                alignment: alignment,
                start: _start,
                end: const Text('Paid', style: TextStyle(fontSize: 40)),
              ),
            );
          },
        ),
      );
      final centred = tester.getRect(find.text('Ali Raza')).top;
      update(() => alignment = MmReflowAlignment.baseline);
      await tester.pump();
      expect(_render(tester).alignment, MmReflowAlignment.baseline);
      expect(tester.getRect(find.text('Ali Raza')).top, isNot(centred));

      final row = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text('Paid')).right, row.right);
      update(() => direction = TextDirection.rtl);
      await tester.pump();
      expect(_render(tester).textDirection, TextDirection.rtl);
      expect(tester.getRect(find.text('Paid')).left, row.left);
      expect(tester.getRect(find.text('Ali Raza')).right, row.right);
    });

    testWidgets('hit-tests its children and nothing between them', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        MmReflow(
          start: _start,
          end: TextButton(onPressed: () => taps++, child: const Text('Call')),
        ),
      );
      await tester.tap(find.text('Call'));
      expect(taps, 1);
      final render = _render(tester);
      final gap =
          Offset(tester.getRect(find.text('Ali Raza')).right + 2, 2) -
          render.localToGlobal(Offset.zero);
      expect(render.hitTest(BoxHitTestResult(), position: gap), isFalse);
    });

    testWidgets('reads its children in order: start, below, end', (
      tester,
    ) async {
      var withBelow = false;
      late StateSetter update;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MergeSemantics(
              child: MmReflow(
                start: _start,
                below: withBelow ? _below : null,
                end: _end,
              ),
            );
          },
        ),
      );
      update(() => withBelow = true);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(MmReflow)),
        matchesSemantics(
          label: 'Ali Raza\nFlat 3, Gulberg III, Lahore\nRs 45,000',
        ),
      );
    });

    testWidgets('puts the children side by side on one baseline', (
      tester,
    ) async {
      await pumpThemed(tester, _line());
      final line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_label)).left, line.left);
      expect(tester.getRect(find.text(_value)).right, line.right);
      expect(
        _baselineOf(tester, _label),
        moreOrLessEquals(_baselineOf(tester, _value), epsilon: 0.01),
      );
      expect(line.width, 296);
    });

    testWidgets('lines the children up at the top when asked', (tester) async {
      await pumpThemed(tester, _line(alignment: MmReflowAlignment.top));
      final line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_label)).top, line.top);
      expect(tester.getRect(find.text(_value)).top, line.top);
    });

    testWidgets('moves the end child under the start child when they do '
        'not fit, at the start edge', (tester) async {
      await pumpThemed(tester, _line(end: _long));
      final line = tester.getRect(find.byType(MmReflow));
      final label = tester.getRect(find.text(_label));
      final value = tester.getRect(find.text(_long));
      expect(value.top, label.bottom + MmReflow.runSpacing);
      expect(value.left, line.left);
      expect(line.bottom, value.bottom);
    });

    testWidgets('keeps a stacked end child at the end edge when asked', (
      tester,
    ) async {
      await pumpThemed(tester, _line(width: 100, stackedAtEnd: true));
      final line = tester.getRect(find.byType(MmReflow));
      final value = tester.getRect(find.text(_value));
      expect(value.top, greaterThan(tester.getRect(find.text(_label)).bottom));
      expect(value.right, line.right);
    });

    testWidgets('mirrors right to left, side by side and stacked', (
      tester,
    ) async {
      await pumpThemed(tester, _line(), variant: MmVariant.urdu);
      var line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_label)).right, line.right);
      expect(tester.getRect(find.text(_value)).left, line.left);

      await pumpThemed(tester, _line(end: _long), variant: MmVariant.urdu);
      line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_long)).right, line.right);

      await pumpThemed(
        tester,
        _line(width: 100, stackedAtEnd: true),
        variant: MmVariant.urdu,
      );
      line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_value)).left, line.left);
    });

    testWidgets('lays out again when its settings change', (tester) async {
      await pumpThemed(tester, _line(end: _long));
      final render = _render(tester);
      expect(render.alignment, MmReflowAlignment.baseline);

      await pumpThemed(
        tester,
        _line(end: _long, alignment: MmReflowAlignment.top, stackedAtEnd: true),
      );
      expect(render.alignment, MmReflowAlignment.top);
      expect(render.stackedAtEnd, isTrue);
      expect(render.textDirection, TextDirection.ltr);
      final line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_long)).right, line.right);

      await pumpThemed(
        tester,
        _line(end: _long, alignment: MmReflowAlignment.top, stackedAtEnd: true),
        variant: MmVariant.urdu,
      );
      expect(render.textDirection, TextDirection.rtl);
    });

    testWidgets('lines up at the top an end child without a baseline when '
        'asked', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 296,
          child: MmReflow(
            alignment: MmReflowAlignment.top,
            start: Text(_label),
            end: SizedBox(key: Key('box'), width: 40, height: 40),
          ),
        ),
      );
      final line = tester.getRect(find.byType(MmReflow));
      expect(tester.getRect(find.text(_label)).top, line.top);
      expect(tester.getRect(find.byKey(const Key('box'))).top, line.top);
      expect(line.height, 40);
    });
  });
}
