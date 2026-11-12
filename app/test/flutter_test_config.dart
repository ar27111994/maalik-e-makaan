import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/fonts.dart';

/// Loads the design system's real fonts (Atkinson, Noto Sans Arabic, the
/// Nastaliq of the Urdu wordmark, the icons) before every test file, so
/// goldens show the true rendering and layouts are measured with real
/// glyphs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadMmFonts();
  await testMain();
}
