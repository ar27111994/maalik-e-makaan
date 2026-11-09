import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/feedback/mm_skeleton_pulse.dart';

import '../../support/testing.dart';

/// The shapes the skeletons under [of] paint.
List<ShapeDecoration> _bones(WidgetTester tester, {Finder? of}) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: of ?? find.byType(MmSkeleton),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration as ShapeDecoration)
    .toList();

/// The rectangles of the skeleton shapes under [of], top to bottom.
List<Rect> _rects(WidgetTester tester, {Finder? of}) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: of ?? find.byType(MmSkeleton),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => tester.getRect(find.byWidget(box)))
    .toList();

/// The fades of the skeleton shapes.
Iterable<FadeTransition> _fades(WidgetTester tester) =>
    tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(MmSkeleton),
        matching: find.byType(FadeTransition),
      ),
    );

/// The opacity the skeletons are faded to.
double _opacity(WidgetTester tester) => _fades(tester).first.opacity.value;

/// [child] with the platform's reduced-motion setting at [still].
Widget _motion(Widget child, {required bool still}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: child,
  ),
);

/// Pumps [child] without settling: a pulse never settles.
Future<void> _pumpPulsing(
  WidgetTester tester,
  Widget child, {
  MmVariant variant = MmVariant.light,
}) async {
  tester.view
    ..physicalSize = const Size(360, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themed(child, variant: variant));
  await tester.pump();
}

void main() {
  group('MmSkeleton', () {
    testEveryVariant('a box is a shape in the rule tone, of the given size', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        _motion(const MmSkeleton.box(width: 180, height: 40), still: true),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final [bone] = _bones(tester);
      expect(bone.color, colors.rule);
      final shape = bone.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.sm)),
      );
      // The tone alone parts it from the page, in every mode.
      expect(shape.side, BorderSide.none);
      expect(tester.getSize(find.byType(MmSkeleton)), const Size(180, 40));
    });

    testEveryVariant('stands apart from the page and from a surface, even '
        'at the faintest of its pulse', (tester, variant) async {
      await pumpThemed(
        tester,
        _motion(const MmSkeleton.box(width: 180, height: 40), still: true),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final [bone] = _bones(tester);
      final fill = bone.color!;
      for (final (name, behind) in [
        ('page', colors.bg),
        ('surface', colors.surface),
      ]) {
        // At full opacity: 3:1 in the high-contrast modes (the contrast a
        // non-text shape needs there), 1.25:1 otherwise, the step from the
        // page to a hairline rule.
        expect(
          mmContrastRatio(fill, behind),
          greaterThanOrEqualTo(variant.highContrast ? 3 : 1.25),
          reason: '$name, full',
        );
        // Faded to the faintest of the pulse, still a shape.
        final faint = Color.alphaBlend(
          fill.withValues(alpha: MmSkeletonPulse.faintest),
          behind,
        );
        expect(
          mmContrastRatio(faint, behind),
          greaterThanOrEqualTo(1.1),
          reason: '$name, faintest',
        );
      }
    });

    testWidgets('a box without a width fills its parent', (tester) async {
      await pumpThemed(
        tester,
        _motion(
          const SizedBox(width: 300, child: MmSkeleton.box(height: 120)),
          still: true,
        ),
      );
      expect(tester.getSize(find.byType(MmSkeleton)), const Size(300, 120));
      const box = MmSkeleton.box(height: 120);
      expect(box.width, isNull);
      expect(box.height, 120);
      expect(box.lines, isNull);
    });

    testWidgets('a circle is round', (tester) async {
      await pumpThemed(
        tester,
        _motion(const MmSkeleton.circle(diameter: 40), still: true),
      );
      final [bone] = _bones(tester);
      expect(bone.shape, isA<CircleBorder>());
      expect(tester.getSize(find.byType(MmSkeleton)), const Size(40, 40));
      const circle = MmSkeleton.circle(diameter: 40);
      expect(circle.width, 40);
      expect(circle.height, 40);
    });

    testEveryVariant('text lines are as tall as body lines at any size', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        _motion(
          const SizedBox(width: 300, child: MmSkeleton.text(lines: 3)),
          still: true,
        ),
        variant: variant,
      );
      final body = variant.theme.textTheme.bodyLarge!;
      final fontSize = body.fontSize! * variant.textScale;
      final lineHeight = fontSize * body.height!;
      expect(
        tester.getSize(find.byType(MmSkeleton)).height,
        moreOrLessEquals(lineHeight * 3, epsilon: 0.01),
      );
      final rects = _rects(tester);
      expect(rects, hasLength(3));
      for (final rect in rects) {
        expect(
          rect.height,
          moreOrLessEquals(fontSize * MmSkeleton.barShare, epsilon: 0.01),
        );
      }
      // Full lines, then a shorter last line at the start edge.
      expect(rects[0].width, 300);
      expect(rects[1].width, 300);
      expect(rects[2].width, 300 * MmSkeleton.lastLineShare);
      final start = tester.getRect(find.byType(MmSkeleton));
      if (variant.locale.languageCode == 'ur') {
        expect(rects[2].right, start.right);
      } else {
        expect(rects[2].left, start.left);
      }
      final shape = _bones(tester).first.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.xs)),
      );
    });

    testWidgets('one line of text fills the width', (tester) async {
      await pumpThemed(
        tester,
        _motion(
          const SizedBox(width: 200, child: MmSkeleton.text()),
          still: true,
        ),
      );
      expect(_rects(tester).single.width, 200);
      expect(const MmSkeleton.text().lines, 1);
    });

    test('empty shapes are programming errors', () {
      expect(() => MmSkeleton.box(height: 0), throwsAssertionError);
      expect(() => MmSkeleton.box(width: 0, height: 10), throwsAssertionError);
      expect(() => MmSkeleton.text(lines: 0), throwsAssertionError);
      expect(() => MmSkeleton.circle(diameter: 0), throwsAssertionError);
    });

    testWidgets('is hidden from assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      int nodeCount() {
        var count = 0;
        bool visit(SemanticsNode node) {
          count++;
          node.visitChildren(visit);
          return true;
        }

        visit(tester.getSemantics(find.byType(MaterialApp)));
        return count;
      }

      Widget page({required bool loading}) => _motion(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ayesha Khan'),
            if (loading) const MmSkeleton.box(width: 100, height: 20),
            if (loading) const MmSkeleton.text(lines: 2),
            if (loading) const MmSkeleton.circle(diameter: 40),
          ],
        ),
        still: true,
      );
      await pumpThemed(tester, page(loading: false));
      final without = nodeCount();
      await pumpThemed(tester, page(loading: true));
      expect(nodeCount(), without);
      final excluded = tester.widget<ExcludeSemantics>(
        find
            .descendant(
              of: find.byType(MmSkeleton).first,
              matching: find.byType(ExcludeSemantics),
            )
            .first,
      );
      expect(excluded.excluding, isTrue);
      handle.dispose();
    });

    testWidgets('pulses slowly between full and half opacity', (tester) async {
      await _pumpPulsing(tester, const MmSkeleton.box(width: 100, height: 20));
      expect(_opacity(tester), 1);
      await tester.pump(MmDuration.pulse);
      expect(_opacity(tester), moreOrLessEquals(MmSkeletonPulse.faintest));
      await tester.pump(MmDuration.pulse);
      expect(_opacity(tester), moreOrLessEquals(1));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('holds still when the platform asks for reduced motion', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _motion(const MmSkeleton.box(width: 100, height: 20), still: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(_opacity(tester), 1);
    });

    testWidgets('follows the reduced-motion setting as it changes', (
      tester,
    ) async {
      const bone = MmSkeleton.box(width: 100, height: 20);
      await _pumpPulsing(tester, _motion(bone, still: false));
      await tester.pump(MmDuration.pulse);
      expect(_opacity(tester), moreOrLessEquals(MmSkeletonPulse.faintest));

      await tester.pumpWidget(themed(_motion(bone, still: true)));
      // Settles: nothing pulses any more.
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);

      await tester.pumpWidget(themed(_motion(bone, still: false)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(MmDuration.pulse);
      expect(_opacity(tester), moreOrLessEquals(MmSkeletonPulse.faintest));
    });

    testWidgets('skeletons under one pulse breathe together', (tester) async {
      await _pumpPulsing(
        tester,
        const MmSkeletonPulse(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MmSkeleton.box(width: 100, height: 20),
              MmSkeleton.circle(diameter: 40),
            ],
          ),
        ),
      );
      final opacities = _fades(tester).map((fade) => fade.opacity).toSet();
      expect(opacities, hasLength(1));
      await tester.pump(MmDuration.pulse);
      expect(_opacity(tester), moreOrLessEquals(MmSkeletonPulse.faintest));
    });

    testWidgets('a widget outside any pulse sees full opacity', (tester) async {
      late Animation<double> opacity;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            opacity = MmSkeletonPulse.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(opacity, same(kAlwaysCompleteAnimation));
    });

    testWidgets('lays out at 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        _motion(
          const Card(
            child: Padding(
              padding: EdgeInsets.all(MmSpace.s4),
              child: Row(
                spacing: MmSpace.s3,
                children: [
                  MmSkeleton.circle(diameter: 48),
                  Expanded(child: MmSkeleton.text(lines: 4)),
                ],
              ),
            ),
          ),
          still: true,
        ),
      );
      await pumpLargeNarrow(
        tester,
        _motion(
          const Card(
            child: Padding(
              padding: EdgeInsets.all(MmSpace.s4),
              child: Row(
                spacing: MmSpace.s3,
                children: [
                  MmSkeleton.circle(diameter: 48),
                  Expanded(child: MmSkeleton.text(lines: 4)),
                ],
              ),
            ),
          ),
          still: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_rects(tester).length, 5);
    });

    testWidgets('stops pulsing when removed', (tester) async {
      await _pumpPulsing(tester, const MmSkeleton.box(width: 100, height: 20));
      await tester.pumpWidget(themed(const SizedBox.shrink()));
      // Settles: the pulse's ticker went with the skeleton.
      await tester.pumpAndSettle();
      expect(find.byType(MmSkeletonPulse), findsNothing);
    });
  });
}
