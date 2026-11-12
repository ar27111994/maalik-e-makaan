import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

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
            colors.inkMuted,
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

    test('agrees with the status colours of the same name', () {
      for (final colors in [MmColorModes.light, MmColorModes.dark]) {
        for (final (tone, status) in [
          (MmTimelineTone.neutral, MmStatus.neutral),
          (MmTimelineTone.paid, MmStatus.paid),
          (MmTimelineTone.dueSoon, MmStatus.dueSoon),
          (MmTimelineTone.overdue, MmStatus.overdue),
          (MmTimelineTone.credit, MmStatus.credit),
        ]) {
          expect(tone.colorIn(colors), status.colorIn(colors), reason: '$tone');
          expect(tone.containerIn(colors), status.containerIn(colors));
          expect(tone.onContainerIn(colors), status.onContainerIn(colors));
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
      expect(_movedIn.semanticLabel, isNull);
      const spoken = MmTimelineItem(
        dateLabel: '7 Oct 2026',
        title: 'Payment received',
        subtitle: 'Rs 45,000 by bank transfer',
        icon: MmIcons.payment,
        tone: MmTimelineTone.paid,
        semanticLabel: '7 Oct 2026, Payment received, 45000 rupees',
      );
      expect(spoken, isNot(_paid));
      expect(spoken.hashCode, isNot(_paid.hashCode));
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
      // Markers grow with the text, by half at 200%.
      final grow = variant == MmVariant.largeText
          ? MmIconLabel.maxIconScale
          : 1.0;
      final ring = _markerAt(tester, 0);
      expect(ring.color, colors.paidContainer);
      expect(ring.border, Border.all(color: colors.paid));
      final icon = tester.widget<Icon>(find.byIcon(MmIcons.payment));
      expect(icon.color, colors.onPaidContainer);
      expect(icon.size, MmSize.iconSm * grow);
      expect(
        tester.getSize(_markers.at(0)),
        Size.square(MmTimeline.iconMarker * grow),
      );
      final dot = _markerAt(tester, 1);
      expect(dot.color, colors.dueSoon);
      expect(dot.border, isNull);
      expect(
        tester.getSize(_markers.at(1)),
        Size.square(MmTimeline.dotMarker * grow),
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
        title: 'ادائیگی مل گئی',
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
      expect(readingOrder(list), [
        '7 Oct 2026, Payment received, Rs 45,000 by bank transfer',
        '1 Aug 2025, Ali Raza moved in',
      ]);
      final item = tester.getSemantics(find.text(_paid.title));
      expect(item.getSemanticsData().role, SemanticsRole.listItem);
      expect(
        item,
        matchesSemantics(
          label: '7 Oct 2026, Payment received, Rs 45,000 by bank transfer',
        ),
      );
    });

    testWidgets('reads the semantic label of an item in place of its words', (
      tester,
    ) async {
      const spoken =
          '7 Oct 2026, Payment received, 45000 rupees by bank '
          'transfer';
      await pumpThemed(
        tester,
        _timeline(const [
          MmTimelineItem(
            dateLabel: '7 Oct 2026',
            title: 'Payment received',
            subtitle: 'Rs 45,000 by bank transfer',
            semanticLabel: spoken,
          ),
          _movedIn,
        ]),
      );
      expect(readingOrder(tester.getSemantics(find.byType(MmTimeline))), [
        spoken,
        '1 Aug 2025, Ali Raza moved in',
      ]);
      // The figures as shown stay on screen.
      expect(find.text('Rs 45,000 by bank transfer'), findsOneWidget);
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

    testWidgets('at 200% grows its markers by half, keeping the rail and the '
        'words in step', (tester) async {
      await pumpLargeNarrow(tester, const MmTimeline(items: [_paid, _due]));
      const grow = MmIconLabel.maxIconScale;
      const column = MmTimeline.markerColumn * grow;
      expect(
        tester.widget<Icon>(find.byIcon(MmIcons.payment)).size,
        MmSize.iconSm * grow,
      );
      expect(
        tester.getSize(_markers.at(0)),
        const Size.square(MmTimeline.iconMarker * grow),
      );
      expect(
        tester.getSize(_markers.at(1)),
        const Size.square(MmTimeline.dotMarker * grow),
      );
      final timeline = tester.getRect(find.byType(MmTimeline));
      final rail = tester.getRect(_rails(MmColorModes.light.rule).first);
      expect(rail.center.dx, timeline.left + column / 2);
      for (var i = 0; i < 2; i++) {
        expect(tester.getCenter(_markers.at(i)).dx, timeline.left + column / 2);
      }
      expect(
        tester.getRect(find.text(_paid.title)).left,
        timeline.left + column + MmSpace.s3,
      );
      // Still centred on the date line.
      expect(
        tester.getCenter(_markers.at(0)).dy,
        moreOrLessEquals(
          tester.getCenter(find.text(_paid.dateLabel)).dy,
          epsilon: 0.01,
        ),
      );
    });

    testWidgets('at 200% on a 320 dp phone, fits long words in English and '
        'Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final say = sayIn(context);
            return MmTimeline(
              items: [
                MmTimelineItem(
                  dateLabel: say('1 Sep 2026', '1 ستمبر 2026'),
                  title: say(
                    'Lease renewed for 11 months at Rs\u00A045,000',
                    'کرایہ نامہ 11 مہینے کے لیے 45,000\u00A0روپے پر رینیو',
                  ),
                  subtitle: say(
                    'House 12, Street 4, Gulberg III, Lahore',
                    'مکان 12، گلی 4، گلبرگ III، لاہور',
                  ),
                  icon: MmIcons.lease,
                  tone: MmTimelineTone.primary,
                ),
                MmTimelineItem(
                  dateLabel: say('1 Aug 2025', '1 اگست 2025'),
                  title: say(
                    'Ali Raza moved in with his family',
                    'علی رضا اپنے خاندان کے ساتھ منتقل ہوئے',
                  ),
                ),
              ],
            );
          },
        ),
        height: 1200,
      );
    });

    testWidgets('keeps an amount joined by a no-break space on one line', (
      tester,
    ) async {
      // At some widths an ordinary space lets the currency word start a
      // new line apart from its figures; the no-break space never does.
      Future<bool> together(double width, String space) async {
        final subtitle = 'بینک ٹرانسفر سے 45,000$spaceروپے';
        await pumpThemed(
          tester,
          SizedBox(
            width: width,
            child: MmTimeline(
              items: [
                MmTimelineItem(
                  dateLabel: '7 اکتوبر 2026',
                  title: 'ادائیگی مل گئی',
                  subtitle: subtitle,
                ),
              ],
            ),
          ),
          variant: MmVariant.urdu,
        );
        return onOneLine(tester, subtitle, '45,000$spaceروپے');
      }

      // From the narrowest column that holds the amount and its currency
      // (96 dp of text beside the markers) to a 320 dp phone.
      final widths = [for (var w = 140.0; w <= 320; w += 4) w];
      var brokeWithSpace = false;
      for (final width in widths) {
        expect(await together(width, '\u00A0'), isTrue, reason: '$width');
        brokeWithSpace |= !await together(width, ' ');
      }
      expect(brokeWithSpace, isTrue);
    });

    testWidgets('sets the figures inside Urdu words in the Latin face', (
      tester,
    ) async {
      const item = MmTimelineItem(
        dateLabel: '1 ستمبر 2026',
        title: 'کرایہ نامہ 11 مہینے کے لیے رینیو',
        subtitle: 'بینک ٹرانسفر سے 45,000\u00A0روپے',
      );
      await pumpThemed(
        tester,
        _timeline(const [item]),
        variant: MmVariant.urdu,
      );
      expect(latinRunsIn(tester, item.dateLabel), ['1 ', ' 2026']);
      expect(latinRunsIn(tester, item.title), [' 11 ']);
      expect(latinRunsIn(tester, item.subtitle!), [' 45,000\u00A0']);
      expect(urduRunsIn(tester, item.title), [
        'کرایہ نامہ',
        'مہینے کے لیے رینیو',
      ]);
    });

    testWidgets('sets Latin data in the Latin face in the Urdu UI and '
        'Urdu data in the Urdu face in the English UI', (tester) async {
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
