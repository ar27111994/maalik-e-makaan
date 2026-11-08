import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Only the public library: the helper and the token are part of its API.
import 'package:mm_ui/mm_ui.dart';

/// The size [MmIconSize.withText] gives [size] at [scale] text.
Future<double> _sizeAt(WidgetTester tester, double scale, double size) async {
  late double result;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Builder(
        builder: (context) {
          result = MmIconSize.withText(context, size);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('MmIconSize.withText', () {
    testWidgets('grows an icon beside words with the text', (tester) async {
      expect(await _sizeAt(tester, 1, MmSize.iconLg), MmSize.iconLg);
      expect(await _sizeAt(tester, 1.25, MmSize.iconLg), MmSize.iconLg * 1.25);
    });

    testWidgets('up to one and a half times, so it never crowds the words', (
      tester,
    ) async {
      expect(MmIconSize.maxScale, 1.5);
      expect(await _sizeAt(tester, 2, MmSize.iconLg), MmSize.iconLg * 1.5);
      expect(await _sizeAt(tester, 3, MmSize.iconMd), MmSize.iconMd * 1.5);
    });

    testWidgets('never shrinks an icon below its size', (tester) async {
      expect(await _sizeAt(tester, 0.85, MmSize.iconLg), MmSize.iconLg * 0.85);
    });
  });

  test('a photo preview has a size token', () {
    expect(MmSize.preview, 160);
  });
}
