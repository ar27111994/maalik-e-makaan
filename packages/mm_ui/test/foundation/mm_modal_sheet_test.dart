import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_modal_sheet.dart';

import '../support/testing.dart';

/// Opens a sheet headed "Property" whose body closes it with 'chosen',
/// and adds what it completes with to [results].
void _open(BuildContext context, List<String?> results) {
  unawaited(
    showMmModalSheet<String>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MmSheetHeader(title: 'Property'),
          TextButton(
            onPressed: () => Navigator.pop(context, 'chosen'),
            child: const Text('Gulberg Heights'),
          ),
        ],
      ),
    ).then(results.add),
  );
}

Finder get _sheet => find
    .descendant(of: find.byType(BottomSheet), matching: find.byType(Material))
    .first;

void main() {
  group('showMmModalSheet', () {
    testWidgets('completes with the value it is closed with, or null', (
      tester,
    ) async {
      final results = <String?>[];
      await pumpOverlay(tester, (context) => _open(context, results));
      await tester.tap(find.text('Gulberg Heights'));
      await tester.pumpAndSettle();
      expect(results, ['chosen']);
      _open(tester.element(find.byType(Scaffold)), results);
      await tester.pumpAndSettle();
      // The header's close button dismisses it.
      await tester.tap(find.byIcon(MmIcons.close));
      await tester.pumpAndSettle();
      expect(results, ['chosen', null]);
    });

    testWidgets('is at most the widest a sheet grows, centred', (tester) async {
      await pumpOverlay(
        tester,
        (context) => _open(context, []),
        size: const Size(1200, 800),
      );
      final sheet = tester.getRect(_sheet);
      expect(sheet.width, MmSize.sheetMax);
      expect(sheet.center.dx, 600);
    });

    testWidgets('slides in over the standard time', (tester) async {
      await pumpOverlay(tester, (context) => _open(context, []));
      expect(
        ModalRoute.of(tester.element(_sheet))!.transitionDuration,
        MmDuration.standard,
      );
    });

    testWidgets('opens at once when the platform asks for less motion', (
      tester,
    ) async {
      late BuildContext page;
      await pumpScreen(
        tester,
        withoutAnimations(
          Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      _open(page, []);
      await tester.pump();
      expect(
        ModalRoute.of(tester.element(_sheet))!.transitionDuration,
        Duration.zero,
      );
    });

    testEveryVariant('has an edge in dark and high-contrast modes', (
      tester,
      variant,
    ) async {
      await pumpOverlay(
        tester,
        (context) => _open(context, []),
        variant: variant,
      );
      // The sheet's own paper, shaped by the theme.
      final shape =
          tester
                  .widget<Material>(
                    find
                        .descendant(
                          of: find.byType(BottomSheet),
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .shape!
              as RoundedRectangleBorder;
      final framed =
          variant.brightness == Brightness.dark || variant.highContrast;
      expect(
        shape.side,
        framed ? BorderSide(color: variant.colors.outline) : BorderSide.none,
      );
      expect(
        shape.side,
        MmTheme.overlayEdge(
          variant.colors,
          brightness: variant.brightness,
          highContrast: variant.highContrast,
        ),
      );
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MmRadius.lg)),
      );
    });
  });

  group('MmSheetHeader', () {
    testWidgets('a heading and a close button named Close', (tester) async {
      await pumpThemed(
        tester,
        const MmSheetHeader(title: 'Record a payment from Ali Raza'),
      );
      expect(
        tester.getSemantics(find.text('Record a payment from Ali Raza')),
        matchesSemantics(
          label: 'Record a payment from Ali Raza',
          isHeader: true,
        ),
      );
      expect(
        tester.getSemantics(find.byIcon(MmIcons.close)),
        matchesSemantics(
          label: 'Close',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('a long title wraps beside the button', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmSheetHeader(
          title: 'Record the rent Ayesha Khan paid for Flat A-1, Gulberg',
        ),
      );
      final title = tester.getRect(
        find.text('Record the rent Ayesha Khan paid for Flat A-1, Gulberg'),
      );
      // Urdu, right to left, is the last language checked.
      expect(
        title.left,
        greaterThanOrEqualTo(tester.getRect(find.byType(IconButton)).right),
      );
    });
  });

  group('MmSheetHeader', () {
    for (final (variant, title) in [
      (MmVariant.light, 'Property'),
      (MmVariant.urdu, 'جائیداد'),
      (MmVariant.largeText, 'Property'),
    ]) {
      testWidgets('centres the close button on the first line of the title, '
          'its glyph growing with the text (${variant.name})', (tester) async {
        late TextStyle style;
        await pumpThemed(
          tester,
          Builder(
            builder: (context) {
              style = Theme.of(context).textTheme.titleLarge!;
              return MmSheetHeader(title: title);
            },
          ),
          variant: variant,
        );
        final scale = variant == MmVariant.largeText ? 2.0 : 1.0;
        final line = style.fontSize! * scale * style.height!;
        final paragraph = paragraphOf(tester, title);
        final firstLine = paragraph.localToGlobal(Offset.zero).dy + line / 2;
        final button = tester.getRect(find.byType(IconButton));
        expect(button.center.dy, closeTo(firstLine, 0.01));
        // The title keeps at least 8 dp above it.
        expect(
          paragraph.localToGlobal(Offset.zero).dy -
              tester.getTopLeft(find.byType(MmSheetHeader)).dy,
          greaterThanOrEqualTo(MmSpace.s2),
        );
        final glyph = tester.widget<RichText>(
          find.descendant(
            of: find.byIcon(MmIcons.close),
            matching: find.byType(RichText),
          ),
        );
        expect(
          glyph.text.style!.fontSize,
          MmSize.iconLg * (scale > 1.5 ? 1.5 : scale),
        );
        expect(button.height, greaterThanOrEqualTo(MmSize.minTarget));
      });
    }
  });
}
