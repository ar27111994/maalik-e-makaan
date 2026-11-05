import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_field_error.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';

import '../support/testing.dart';

void main() {
  group('MmFieldLabel', () {
    testEveryVariant('says Required or Optional after the label, muted', (
      tester,
      variant,
    ) async {
      final strings = MmLocalizations.forLocale(variant.locale);
      final colors = variant.colors;
      await pumpThemed(
        tester,
        const Column(
          children: [
            MmFieldLabel(label: 'Tenant', required: true),
            MmFieldLabel(label: 'Unit', optional: true),
            MmFieldLabel(label: 'Notes'),
          ],
        ),
        variant: variant,
      );
      expect(
        find.text('Tenant  ${strings.requiredField}', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Unit  ${strings.optionalField}', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Notes', findRichText: true), findsOneWidget);
      // The label in ink, the marker after it in muted ink.
      final span = paragraphOf(tester, 'Tenant').text as TextSpan;
      expect(span.style!.color, colors.ink);
      final label = span.children!.single as TextSpan;
      final marker = label.children!.single as TextSpan;
      expect(marker.style!.color, colors.inkMuted);
    });

    testWidgets('mutes the whole label of a disabled field', (tester) async {
      await pumpThemed(
        tester,
        const MmFieldLabel(label: 'Tenant', enabled: false),
      );
      expect(styleOf(tester, 'Tenant').color, MmColorModes.light.inkMuted);
    });

    testWidgets('is hidden from assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmFieldLabel(label: 'Tenant', required: true),
      );
      expect(find.bySemanticsLabel(RegExp('Tenant')), findsNothing);
      handle.dispose();
    });

    testWidgets('markerOf names the marker in the ambient language', (
      tester,
    ) async {
      final markers = <String?>[];
      Widget reader() => Builder(
        builder: (context) {
          markers
            ..add(
              MmFieldLabel.markerOf(context, required: true, optional: false),
            )
            ..add(
              MmFieldLabel.markerOf(context, required: false, optional: true),
            )
            ..add(
              MmFieldLabel.markerOf(context, required: false, optional: false),
            );
          return const SizedBox();
        },
      );
      await pumpThemed(tester, reader());
      await pumpThemed(tester, reader(), variant: MmVariant.urdu);
      expect(markers, [
        'Required',
        'Optional',
        null,
        MmLocalizations.urdu.requiredField,
        MmLocalizations.urdu.optionalField,
        null,
      ]);
    });

    test('a field is not both required and optional', () {
      expect(
        () => MmFieldLabel(label: 'Tenant', required: true, optional: true),
        throwsAssertionError,
      );
    });
  });

  group('MmFieldError', () {
    testEveryVariant('shows the error icon and words in the overdue colour', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFieldError('Enter the unit number'),
        variant: variant,
      );
      final colors = variant.colors;
      expect(styleOf(tester, 'Enter the unit number').color, colors.overdue);
      expect(
        tester.widget<Icon>(find.byIcon(MmIcons.error)).color,
        colors.overdue,
      );
    });

    testWidgets('is a live region read as its message', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        Semantics(
          container: true,
          child: const MmFieldError('Enter the unit number'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmFieldError)),
        isSemantics(label: 'Enter the unit number', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
