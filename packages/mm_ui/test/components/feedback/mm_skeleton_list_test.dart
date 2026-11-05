import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/feedback/mm_skeleton_pulse.dart';

import '../../support/testing.dart';

/// [child] with motion reduced, so the pulse holds still and settles.
Widget _still(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// The circles (avatars) of the rows, top to bottom.
Finder get _avatars => find.byWidgetPredicate(
  (widget) => widget is MmSkeleton && widget.width == MmSkeletonList.avatarSize,
);

void main() {
  group('MmSkeletonList', () {
    testWidgets('shows six tile-shaped rows on a card by default', (
      tester,
    ) async {
      await pumpThemed(tester, _still(const MmSkeletonList()));
      expect(const MmSkeletonList().itemCount, 6);
      expect(_avatars, findsNWidgets(6));
      expect(find.byType(Divider), findsNWidgets(5));
      expect(find.byType(Card), findsOneWidget);
      // Each row: an avatar, a title and a subtitle line, an amount.
      expect(find.byType(MmSkeleton), findsNWidgets(6 * 4));
    });

    testWidgets('shows itemCount rows', (tester) async {
      await pumpThemed(tester, _still(const MmSkeletonList(itemCount: 2)));
      expect(_avatars, findsNWidgets(2));
      expect(find.byType(Divider), findsOneWidget);
    });

    test('an empty skeleton list is a programming error', () {
      expect(() => MmSkeletonList(itemCount: 0), throwsAssertionError);
    });

    testEveryVariant('is one node that announces "Loading"', (
      tester,
      variant,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        _still(const MmSkeletonList(itemCount: 3)),
        variant: variant,
      );
      final loading = MmLocalizations.forLocale(variant.locale).loading;
      final node = tester.getSemantics(find.byType(MmSkeletonList));
      expect(node, isSemantics(label: loading, isLiveRegion: true));
      expect(node.childrenCount, 0);
      handle.dispose();
    });

    testWidgets('all rows pulse together from one animation', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themed(const MmSkeletonList(itemCount: 3)));
      await tester.pump();
      final opacities = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(MmSkeletonList),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((fade) => fade.opacity)
          .toSet();
      expect(opacities, hasLength(1));
      await tester.pump(MmDuration.pulse);
      expect(
        opacities.single.value,
        moreOrLessEquals(MmSkeletonPulse.faintest),
      );
    });

    testWidgets('holds still with reduced motion', (tester) async {
      await pumpThemed(tester, _still(const MmSkeletonList()));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('cuts off rows that do not fit a bounded height', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _still(const SizedBox(height: 150, child: MmSkeletonList())),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmSkeletonList)).height, 150);
      expect(find.byType(ClipRect), findsOneWidget);
    });

    testWidgets('is as tall as its rows in a list', (tester) async {
      await pumpThemed(
        tester,
        _still(ListView(children: const [MmSkeletonList(itemCount: 2)])),
      );
      final list = tester.getSize(find.byType(MmSkeletonList)).height;
      final card = tester.getSize(find.byType(Card)).height;
      expect(list, card);
      expect(list, lessThan(200));
    });

    testWidgets('lays out at 200% text on a 320 dp phone', (tester) async {
      await pumpLargeNarrow(tester, _still(const MmSkeletonList()));
      expect(tester.takeException(), isNull);
      // The rows grow with the text.
      final row = tester.getSize(_avatars.first);
      expect(row, const Size.square(MmSkeletonList.avatarSize));
      expect(
        tester.getSize(find.byType(Card)).height,
        greaterThan(6 * MmSkeletonList.avatarSize),
      );
    });

    testWidgets('mirrors for Urdu: the avatar at the right', (tester) async {
      await pumpThemed(
        tester,
        _still(const MmSkeletonList(itemCount: 1)),
        variant: MmVariant.urdu,
      );
      final card = tester.getRect(find.byType(Card));
      expect(tester.getCenter(_avatars).dx, greaterThan(card.center.dx));
    });
  });
}
