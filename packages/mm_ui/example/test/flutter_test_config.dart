import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/fonts.dart';

/// Loads mm_ui's real fonts before every test, as mm_ui's own tests do, so
/// text is measured (and overflow found) with Atkinson Hyperlegible Next,
/// Noto Sans Arabic, Noto Nastaliq Urdu (the Urdu wordmark) and the MmIcons
/// glyphs rather than the test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadMmFonts();
  await testMain();
}
