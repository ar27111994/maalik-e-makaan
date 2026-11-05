import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';

import '../support/testing.dart';

/// A row with one focusable control, ringed by [MmFocusWithin].
Widget _row({double radius = MmRadius.sm}) => MmFocusWithin(
  radius: radius,
  child: CheckboxListTile(
    title: const Text('Rent includes electricity'),
    value: true,
    onChanged: (_) {},
  ),
);

/// The decoration [MmFocusWithin] paints over its row.
BoxDecoration _ring(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(MmFocusWithin),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

/// Records whether [MmFocusHighlight] says focus is drawn, each build.
class _Probe extends StatefulWidget {
  const new({required this.seen});

  final List<bool> seen;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with MmFocusHighlight<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.seen.add(showsFocusHighlights);
    return const SizedBox();
  }
}

void main() {
  group('MmFocusHighlight', () {
    testWidgets('follows the highlight mode, rebuilding only on a change', (
      tester,
    ) async {
      final seen = <bool>[];
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpThemed(tester, _Probe(seen: seen));
      expect(seen, [false]);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(seen, [false, true]);
      // The same mode again is not a change.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(seen, [false, true]);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pump();
      expect(seen, [false, true, false]);
    });

    testWidgets('stops listening when its state is disposed', (tester) async {
      final seen = <bool>[];
      await pumpThemed(tester, _Probe(seen: seen));
      await pumpThemed(tester, const SizedBox());
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(seen, hasLength(1));
    });
  });

  group('MmFocusWithin', () {
    testEveryVariant('rings the row while its control has keyboard focus', (
      tester,
      variant,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, _row(), variant: variant);
      expect(_ring(tester).border, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ring = _ring(tester);
      expect(
        ring.border,
        Border.all(color: variant.colors.focus, width: MmSize.focusRing),
      );
      expect(
        ring.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.sm)),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_ring(tester).border, isNull);
    });

    testWidgets('draws no ring for focus that came from a tap', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpThemed(tester, _row());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_ring(tester).border, isNull);
      // Switching to the keyboard shows the ring on the focused row.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpAndSettle();
      expect(_ring(tester).border, isNotNull);
    });

    testWidgets('takes a corner radius, adds no focus stop or semantics', (
      tester,
    ) async {
      useKeyboardHighlights();
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, _row(radius: MmRadius.md));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _ring(tester).borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.md)),
      );
      // The first Tab reached the row's control, not the ring.
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        focused.findAncestorWidgetOfExactType<CheckboxListTile>(),
        isNotNull,
      );
      // The row is read as the tile, with nothing of the ring's own.
      expect(
        tester.getSemantics(find.byType(CheckboxListTile)),
        isSemantics(label: 'Rent includes electricity', isChecked: true),
      );
      handle.dispose();
    });
  });
}
