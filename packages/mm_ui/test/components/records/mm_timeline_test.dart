import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _paid = MmTimelineItem(
  dateLabel: '7 Oct 2026',
  title: 'Payment received',
  subtitle: 'Rs 45,000 by bank transfer',
  icon: MmIcons.payment,
  tone: MmTimelineTone.paid,
);
const _due = MmTimelineItem(
  dateLabel: '5 Oct 2026',
  title: 'October rent due',
  subtitle: 'Rs 45,000',
  tone: MmTimelineTone.dueSoon,
);
const _movedIn = MmTimelineItem(
  dateLabel: '1 Aug 2025',
  title: 'Ali Raza moved in',
);

Widget _timeline(List<MmTimelineItem> items) =>
    SizedBox(width: 296, child: MmTimeline(items: items));

/// The markers, in order: the circles of dots and icon rings.
Finder get _markers => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).shape == BoxShape.circle,
);

BoxDecoration _markerAt(WidgetTester tester, int index) =>
    tester.widget<DecoratedBox>(_markers.at(index)).decoration as BoxDecoration;

/// The stretches of rail, in order.
Finder _rails(Color rule) => find.byWidgetPredicate(
  (widget) => widget is ColoredBox && widget.color == rule,
);

void main() {
  group('MmTimelineTone', () {
    test('has a strong colour, a container and an on-container colour', () {
      for (final colors in [
        MmColorModes.light,
        MmColorModes.dark,
        MmColorModes.lightHighContrast,
        MmColorModes.darkHighContrast,
      ]) {
        final expected = {
          MmTimelineTone.neutral: (
            colors.outline,
            colors.surfaceSunken,
            colors.ink,
          ),
          MmTimelineTone.primary: (
            colors.primary,
            colors.primaryContainer,
            colors.onPrimaryContainer,
          ),
          MmTimelineTone.paid: (
            colors.paid,
            colors.paidContainer,
            colors.onPaidContainer,
          ),
          MmTimelineTone.dueSoon: (
            colors.dueSoon,
            colors.dueSoonContainer,
            colors.onDueSoonContainer,
          ),
          MmTimelineTone.overdue: (
            colors.overdue,
            colors.overdueContainer,
            colors.onOverdueContainer,
          ),
          MmTimelineTone.credit: (
            colors.credit,
            colors.creditContainer,
            colors.onCreditContainer,
          ),
        };
        for (final MapEntry(key: tone, value: (strong, container, on))
            in expected.entries) {
          expect(tone.colorIn(colors), strong);
          expect(tone.containerIn(colors), container);
          expect(tone.onContainerIn(colors), on);
        }
      }
    });
  });

  group('MmTimelineItem', () {
    test('is equal to an item with the same fields', () {
      const copy = MmTimelineItem(
        dateLabel: '7 Oct 2026',
        title: 'Payment received',
        subtitle: 'Rs 45,000 by bank transfer',
        icon: MmIcons.payment,
        tone: MmTimelineTone.paid,
      );
      expect(copy, _paid);
      expect(copy.hashCode, _paid.hashCode);
      expect(_paid, isNot(_due));
      expect(_movedIn.tone, MmTimelineTone.neutral);
      expect(_movedIn.icon, isNull);
      expect(_movedIn.subtitle, isNull);
    });
  });

  group('MmTimeline', () {
    testEveryVariant('sets the date muted, the title in ink, the detail '
        'muted', (tester, variant) async {
      await pumpThemed(tester, _timeline([_paid]), variant: variant);
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final date = styleOf(tester, _paid.dateLabel);
      expect(date.color, colors.inkMuted);
      expect(date.fontSize, text.bodySmall!.fontSize);
      final title = styleOf(tester, _paid.title);
      expect(title.color, colors.ink);
      expect(title.fontSize, text.titleMedium!.fontSize);
      final subtitle = styleOf(tester, _paid.subtitle!);
      expect(subtitle.color, colors.inkMuted);
      expect(subtitle.fontSize, text.bodyMedium!.fontSize);
      final dateRect = tester.getRect(find.text(_paid.dateLabel));
      final titleRect = tester.getRect(find.text(_paid.title));
      expect(titleRect.top, dateRect.bottom);
      expect(tester.getRect(find.text(_paid.subtitle!)).top, titleRect.bottom);
    });

    testEveryVariant('draws an icon in a ringed circle or a dot in the '
        'tone', (tester, variant) async {
      await pumpThemed(tester, _timeline([_paid, _due]), variant: variant);
      final colors = colorsOf(variant);
      final ring = _markerAt(tester, 0);
      expect(ring.color, colors.paidContainer);
      expect(ring.border, Border.all(color: colors.paid));
      final icon = tester.widget<Icon>(find.byIcon(MmIcons.payment));
      expect(icon.color, colors.onPaidContainer);
      expect(icon.size, MmSize.iconSm);
      expect(
        tester.getSize(_markers.at(0)),
        const Size.square(MmTimeline.iconMarker),
      );
      final dot = _markerAt(tester, 1);
      expect(dot.color, colors.dueSoon);
      expect(dot.border, isNull);
      expect(
        tester.getSize(_markers.at(1)),
        const Size.square(MmTimeline.dotMarker),
      );
    });

    testEveryVariant('centres each marker on its date line', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _timeline([_paid, _due]), variant: variant);
      for (final (index, item) in [_paid, _due].indexed) {
        expect(
          tester.getCenter(_markers.at(index)).dy,
          moreOrLessEquals(
            tester.getCenter(find.text(item.dateLabel)).dy,
            epsilon: 0.01,
          ),
        );
      }
    });

    testWidgets('runs one rail from the first marker to the last', (
      tester,
    ) async {
      await pumpThemed(tester, _timeline([_paid, _due, _movedIn]));
      final rails = _rails(MmColorModes.light.rule);
      // Below the first marker, above and below the middle one, above the
      // last.
      expect(rails, findsNWidgets(4));
      final segments = [
        for (var i = 0; i < 4; i++) tester.getRect(rails.at(i)),
      ];
      final markers = [
        for (var i = 0; i < 3; i++) tester.getRect(_markers.at(i)),
      ];
      expect(segments[0].top, markers[0].bottom);
      expect(segments[0].bottom, segments[1].top);
      expect(segments[1].bottom, markers[1].top);
      expect(segments[2].top, markers[1].bottom);
      expect(segments[2].bottom, segments[3].top);
      expect(segments[3].bottom, markers[2].top);
      for (final segment in segments) {
        expect(segment.width, MmTimeline.railWidth);
        expect(segment.center.dx, markers[0].center.dx);
      }
      expect(markers[0].center.dx, markers[1].center.dx);
    });

    testWidgets('a single item has no rail', (tester) async {
      await pumpThemed(tester, _timeline([_movedIn]));
      expect(_rails(MmColorModes.light.rule), findsNothing);
    });

    testWidgets('puts the rail on the start side, mirrored in Urdu', (
      tester,
    ) async {
      await pumpThemed(tester, _timeline([_paid, _due]));
      var timeline = tester.getRect(find.byType(MmTimeline));
      expect(
        tester.getCenter(_markers.first).dx,
        timeline.left + MmTimeline.markerColumn / 2,
      );
      expect(
        tester.getRect(find.text(_paid.title)).left,
        timeline.left + MmTimeline.markerColumn + MmSpace.s3,
      );

      const urdu = MmTimelineItem(
        dateLabel: '7 اکتوبر 2026',
        title: 'ادائیگی موصول ہوئی',
        icon: MmIcons.payment,
      );
      await pumpThemed(
        tester,
        _timeline([urdu, urdu]),
        variant: MmVariant.urdu,
      );
      timeline = tester.getRect(find.byType(MmTimeline));
      expect(
        tester.getCenter(_markers.first).dx,
        timeline.right - MmTimeline.markerColumn / 2,
      );
      expect(
        tester.getRect(find.text(urdu.title).first).right,
        timeline.right - MmTimeline.markerColumn - MmSpace.s3,
      );
    });

    testWidgets('is a list of items, each one node reading the date, the '
        'title and the detail', (tester) async {
      await pumpThemed(tester, _timeline([_paid, _movedIn]));
      final list = tester.getSemantics(find.byType(MmTimeline));
      expect(list.getSemanticsData().role, SemanticsRole.list);
      final items = childrenInOrder(list);
      expect(items, hasLength(2));
      expect(
        items[0],
        matchesSemantics(
          label: '7 Oct 2026, Payment received, Rs 45,000 by bank transfer',
        ),
      );
      expect(items[0].getSemanticsData().role, SemanticsRole.listItem);
      expect(
        items[1],
        matchesSemantics(label: '1 Aug 2025, Ali Raza moved in'),
      );
    });

    testWidgets('an empty timeline shows nothing', (tester) async {
      await pumpThemed(tester, _timeline(const []));
      expect(tester.getSize(find.byType(MmTimeline)).height, 0);
      expect(_markers, findsNothing);
    });

    testWidgets('at 200% on a 320 dp phone, wraps without overflowing', (
      tester,
    ) async {
      const long = MmTimelineItem(
        dateLabel: '1 Sep 2026',
        title: 'Lease renewed for 11 months at Rs 45,000',
        subtitle: 'House 12, Street 4, Gulberg III, Lahore',
        icon: MmIcons.lease,
        tone: MmTimelineTone.primary,
      );
      await pumpLargeNarrow(
        tester,
        const MmTimeline(items: [long, _due, _movedIn]),
        height: 1000,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmTimeline)).width, 288);
      final title = tester.getRect(find.text(long.title));
      expect(title.height, greaterThan(2 * 20 * 2));
      // The rail stretches with the wrapped item.
      final rail = tester.getRect(_rails(MmColorModes.light.rule).first);
      expect(
        rail.bottom,
        greaterThanOrEqualTo(tester.getRect(find.text(long.subtitle!)).bottom),
      );
    });

    testWidgets('sets Latin data in the Latin face in the Urdu UI and '
        'Urdu data with Nastaliq in the English UI', (tester) async {
      await pumpThemed(
        tester,
        _timeline(const [
          MmTimelineItem(dateLabel: '1 اگست 2025', title: 'Ali Raza'),
        ]),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.latin),
      );

      await pumpThemed(
        tester,
        _timeline(const [
          MmTimelineItem(dateLabel: '1 Aug 2025', title: 'علی رضا'),
        ]),
      );
      expect(styleOf(tester, 'علی رضا').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
    });
  });
}
