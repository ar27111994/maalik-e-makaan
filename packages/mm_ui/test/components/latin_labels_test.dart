import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/testing.dart';

/// The font family of the run of text that holds [run], in the paragraph
/// whose text contains it: its span's style merged into its parents'.
String? _faceOf(WidgetTester tester, String run) {
  final paragraphs = tester
      .renderObjectList<RenderParagraph>(
        find.byWidgetPredicate((widget) => widget is RichText),
      )
      .where((paragraph) => paragraph.text.toPlainText().contains(run));
  expect(paragraphs, isNotEmpty, reason: 'no paragraph holds "$run"');
  String? found;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is! TextSpan) return;
    if (span.text?.contains(run) ?? false) found ??= style.fontFamily;
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(paragraphs.first.text, const TextStyle());
  expect(found, isNotNull, reason: 'no single run holds "$run"');
  return found;
}

/// Expects each of [latin] set in the Latin face and each of [urdu] in
/// the Urdu face.
void _expectFaces(
  WidgetTester tester, {
  required List<String> latin,
  List<String> urdu = const [],
}) {
  for (final run in latin) {
    expect(_faceOf(tester, run), contains(MmFontFamily.latin), reason: run);
  }
  for (final run in urdu) {
    expect(_faceOf(tester, run), contains(MmFontFamily.urdu), reason: run);
  }
}

/// Every label a component sets from the app's words keeps Latin words and
/// figures inside the Urdu UI in the Latin face, as `MmScriptText` does,
/// rather than in the Urdu face's own Latin glyphs.
void main() {
  group('Latin words in Urdu labels are set in the Latin face', () {
    Future<void> pumpUrdu(WidgetTester tester, Widget child) =>
        pumpThemed(tester, child, variant: MmVariant.urdu);

    testWidgets('in segmented controls', (tester) async {
      await pumpUrdu(
        tester,
        Column(
          children: [
            MmSegmentedControl<String>(
              segments: const [
                MmSegment(value: 'en', label: 'English'),
                MmSegment(value: 'ur', label: 'اردو'),
              ],
              selected: 'ur',
              onChanged: (_) {},
            ),
            MmSegmentedControl<int>(
              segments: const [
                MmSegment(value: 100, label: '100%'),
                MmSegment(value: 200, label: '200% بڑا'),
              ],
              selected: 100,
              onChanged: (_) {},
            ),
          ],
        ),
      );
      _expectFaces(
        tester,
        latin: ['English', '100%', '200'],
        urdu: ['اردو', 'بڑا'],
      );
    });

    testWidgets('in buttons and the floating action button', (tester) async {
      await pumpUrdu(
        tester,
        const Column(
          children: [
            MmButton(label: 'WhatsApp پر بھیجیں', onPressed: tapped),
            MmFab(label: 'PDF بنائیں', icon: MmIcons.export, onPressed: tapped),
          ],
        ),
      );
      _expectFaces(
        tester,
        latin: ['WhatsApp', 'PDF'],
        urdu: ['بھیجیں', 'بنائیں'],
      );
    });

    testWidgets('in tabs', (tester) async {
      await pumpUrdu(
        tester,
        const DefaultTabController(
          length: 2,
          child: MmTabs(labels: ['Excel', 'خلاصہ']),
        ),
      );
      _expectFaces(tester, latin: ['Excel'], urdu: ['خلاصہ']);
    });

    testWidgets('in filter chips, a label that mixes scripts included', (
      tester,
    ) async {
      await pumpUrdu(
        tester,
        MmFilterChips<int>(
          options: const [
            MmFilterOption(value: 1, label: 'فلیٹ 2B', count: 3),
            MmFilterOption(value: 2, label: 'DHA'),
          ],
          selected: const {1},
          onChanged: (_) {},
        ),
      );
      _expectFaces(tester, latin: ['2B', 'DHA', '3'], urdu: ['فلیٹ']);
    });

    testWidgets('in switch and checkbox tiles', (tester) async {
      await pumpUrdu(
        tester,
        Column(
          children: [
            MmSwitchTile(
              label: 'WhatsApp یاددہانی',
              description: 'SMS بھی بھیجیں',
              value: true,
              onChanged: (_) {},
            ),
            MmCheckboxTile(
              label: 'CNIC کی کاپی',
              description: 'PDF یا تصویر',
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
      );
      _expectFaces(
        tester,
        latin: ['WhatsApp', 'SMS', 'CNIC', 'PDF'],
        urdu: ['یاددہانی', 'کاپی'],
      );
    });

    testWidgets("in a section header's action", (tester) async {
      await pumpUrdu(
        tester,
        const MmSectionHeader(
          title: 'رسیدیں',
          actionLabel: 'PDF',
          onAction: tapped,
        ),
      );
      _expectFaces(tester, latin: ['PDF'], urdu: ['رسیدیں']);
    });

    testWidgets("in a banner's action and an error state's retry", (
      tester,
    ) async {
      await pumpUrdu(
        tester,
        const Column(
          children: [
            MmBanner(
              tone: MmBannerTone.info,
              message: 'رسید تیار ہے',
              actionLabel: 'WhatsApp',
              onAction: tapped,
            ),
            MmErrorState(
              message: 'رابطہ نہیں ہو سکا',
              actionLabel: 'WiFi دوبارہ',
              onRetry: tapped,
            ),
          ],
        ),
      );
      _expectFaces(tester, latin: ['WhatsApp', 'WiFi'], urdu: ['دوبارہ']);
    });

    testWidgets("in an empty state's action", (tester) async {
      await pumpUrdu(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: 'کوئی کرایہ دار نہیں',
          message: 'پہلا کرایہ دار شامل کریں',
          actionLabel: 'CSV درآمد کریں',
          onAction: tapped,
        ),
      );
      _expectFaces(tester, latin: ['CSV'], urdu: ['درآمد']);
    });

    testWidgets("in a snack bar's action", (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMmSnackbar(
                  context,
                  message: 'رسید بھیج دی',
                  actionLabel: 'SMS',
                  onAction: tapped,
                ),
                child: const Text('open'),
              ),
            ),
          ),
          variant: MmVariant.urdu,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      _expectFaces(tester, latin: ['SMS']);
    });

    for (final (name, size) in const [
      ('bottom bar', Size(360, 740)),
      ('rail', Size(700, 800)),
      ('extended rail', Size(1280, 800)),
    ]) {
      testWidgets("in the navigation's $name", (tester) async {
        await pumpScreen(
          tester,
          MmAdaptiveScaffold(
            destinations: const [
              MmDestination(icon: MmIcons.home, label: 'ڈیش بورڈ'),
              MmDestination(icon: MmIcons.reports, label: 'Excel'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            body: const Scaffold(),
          ),
          size: size,
          variant: MmVariant.urdu,
        );
        _expectFaces(tester, latin: ['Excel'], urdu: ['ڈیش']);
      });
    }
  });
}
