import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/components/records/mm_record_line.dart';

import '../../support/harness.dart';
import 'support.dart';

const _label = 'Tenant';
const _value = 'Ali Raza';
const _long = 'House 12, Street 4, Gulberg III, Lahore';

/// A label in the small body style and a value in the body style, as on a
/// receipt row (different sizes, so their baselines differ from their
/// tops).
Widget _line({
  String start = _label,
  String end = _value,
  MmRecordLineAlignment alignment = MmRecordLineAlignment.baseline,
  bool stackedAtEnd = false,
  double width = 296,
}) => SizedBox(
  width: width,
  child: Builder(
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return MmRecordLine(
        alignment: alignment,
        stackedAtEnd: stackedAtEnd,
        start: Text(start, style: text.bodyMedium),
        end: Text(end, style: text.bodyLarge),
      );
    },
  ),
);

RenderMmRecordLine _render(WidgetTester tester) =>
    tester.renderObject(find.byType(MmRecordLine));

void main() {
  group('MmRecordLine', () {
    testWidgets('puts the children side by side on one baseline', (
      tester,
    ) async {
      await pumpThemed(tester, _line());
      final line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_label)).left, line.left);
      expect(tester.getRect(find.text(_value)).right, line.right);
      expect(
        baselineOf(tester, _label),
        moreOrLessEquals(baselineOf(tester, _value), epsilon: 0.01),
      );
      expect(line.width, 296);
    });

    testWidgets('lines the children up at the top when asked', (tester) async {
      await pumpThemed(tester, _line(alignment: MmRecordLineAlignment.top));
      final line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_label)).top, line.top);
      expect(tester.getRect(find.text(_value)).top, line.top);
    });

    testWidgets('lines up at the top a child that has no baseline', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 296,
          child: MmRecordLine(
            start: Text(_label),
            end: SizedBox(key: Key('box'), width: 40, height: 40),
          ),
        ),
      );
      final line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_label)).top, line.top);
      expect(tester.getRect(find.byKey(const Key('box'))).top, line.top);
      expect(line.height, 40);
    });

    testWidgets('moves the end child under the start child when they do '
        'not fit, at the start edge', (tester) async {
      await pumpThemed(tester, _line(end: _long));
      final line = tester.getRect(find.byType(MmRecordLine));
      final label = tester.getRect(find.text(_label));
      final value = tester.getRect(find.text(_long));
      expect(value.top, label.bottom + MmRecordLine.runSpacing);
      expect(value.left, line.left);
      expect(line.bottom, value.bottom);
    });

    testWidgets('keeps a stacked end child at the end edge when asked', (
      tester,
    ) async {
      await pumpThemed(tester, _line(width: 100, stackedAtEnd: true));
      final line = tester.getRect(find.byType(MmRecordLine));
      final value = tester.getRect(find.text(_value));
      expect(value.top, greaterThan(tester.getRect(find.text(_label)).bottom));
      expect(value.right, line.right);
    });

    testWidgets('mirrors right to left, side by side and stacked', (
      tester,
    ) async {
      await pumpThemed(tester, _line(), variant: MmVariant.urdu);
      var line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_label)).right, line.right);
      expect(tester.getRect(find.text(_value)).left, line.left);

      await pumpThemed(tester, _line(end: _long), variant: MmVariant.urdu);
      line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_long)).right, line.right);

      await pumpThemed(
        tester,
        _line(width: 100, stackedAtEnd: true),
        variant: MmVariant.urdu,
      );
      line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_value)).left, line.left);
    });

    testWidgets('takes its natural width when its width is unbounded', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const UnconstrainedBox(
          child: MmRecordLine(start: Text(_label), end: Text(_value)),
        ),
      );
      final width =
          tester.getSize(find.text(_label)).width +
          MmRecordLine.spacing +
          tester.getSize(find.text(_value)).width;
      expect(
        tester.getSize(find.byType(MmRecordLine)).width,
        moreOrLessEquals(width, epsilon: 0.01),
      );
    });

    testWidgets('reports intrinsic sizes, dry layout and baselines that '
        'match its layout', (tester) async {
      await pumpThemed(tester, _line());
      final render = _render(tester);
      final label = tester.getSize(find.text(_label));
      final value = tester.getSize(find.text(_value));
      expect(
        render.getMaxIntrinsicWidth(double.infinity),
        moreOrLessEquals(
          label.width + MmRecordLine.spacing + value.width,
          epsilon: 0.01,
        ),
      );
      final longestWord = tester
          .renderObject<RenderParagraph>(find.text(_value))
          .getMinIntrinsicWidth(double.infinity);
      expect(
        render.getMinIntrinsicWidth(double.infinity),
        greaterThanOrEqualTo(longestWord),
      );
      expect(render.getMinIntrinsicHeight(296), render.size.height);
      expect(render.getMaxIntrinsicHeight(296), render.size.height);
      // Narrower than both side by side: the value moves under the label.
      expect(render.getMinIntrinsicHeight(60), greaterThan(render.size.height));

      final constraints = BoxConstraints.tightFor(width: render.size.width);
      expect(render.getDryLayout(constraints), render.size);
      final baseline = render.getDryBaseline(
        constraints,
        TextBaseline.alphabetic,
      )!;
      expect(
        render.localToGlobal(Offset(0, baseline)).dy,
        moreOrLessEquals(baselineOf(tester, _label), epsilon: 0.01),
      );
    });

    testWidgets('reports the first baseline of its start child', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 296,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Rs', key: Key('beside')),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final text = Theme.of(context).textTheme;
                    return MmRecordLine(
                      start: Text(_label, style: text.titleLarge),
                      end: Text(_value, style: text.bodyLarge),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        baselineOf(tester, _label),
        moreOrLessEquals(baselineOf(tester, 'Rs'), epsilon: 0.01),
      );
    });

    testWidgets('hit-tests its children and not the space between them', (
      tester,
    ) async {
      await pumpThemed(tester, _line());
      expect(find.text(_label).hitTestable(), findsOneWidget);
      expect(find.text(_value).hitTestable(), findsOneWidget);
      final render = _render(tester);
      final gap = render.globalToLocal(
        Offset(
          (tester.getRect(find.text(_label)).right +
                  tester.getRect(find.text(_value)).left) /
              2,
          tester.getCenter(find.text(_label)).dy,
        ),
      );
      expect(render.hitTest(BoxHitTestResult(), position: gap), isFalse);
    });

    testWidgets('lays out again when its settings change', (tester) async {
      await pumpThemed(tester, _line(end: _long));
      final render = _render(tester);
      expect(render.alignment, MmRecordLineAlignment.baseline);

      await pumpThemed(
        tester,
        _line(
          end: _long,
          alignment: MmRecordLineAlignment.top,
          stackedAtEnd: true,
        ),
      );
      expect(render.alignment, MmRecordLineAlignment.top);
      expect(render.stackedAtEnd, isTrue);
      expect(render.textDirection, TextDirection.ltr);
      final line = tester.getRect(find.byType(MmRecordLine));
      expect(tester.getRect(find.text(_long)).right, line.right);

      await pumpThemed(
        tester,
        _line(
          end: _long,
          alignment: MmRecordLineAlignment.top,
          stackedAtEnd: true,
        ),
        variant: MmVariant.urdu,
      );
      expect(render.textDirection, TextDirection.rtl);
    });

    testWidgets('reads its children in order: start, then end', (tester) async {
      await pumpThemed(
        tester,
        Semantics(container: true, explicitChildNodes: true, child: _line()),
      );
      final node = tester.getSemantics(find.byType(MmRecordLine));
      expect(readingOrder(node), [_label, _value]);
    });
  });
}
