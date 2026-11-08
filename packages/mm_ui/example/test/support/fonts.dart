import 'dart:io';

import 'package:flutter/services.dart';

/// The fonts mm_ui bundles, registered under the family names its text
/// styles and icons use (`packages/mm_ui/<family>`), so tests and goldens
/// render real glyphs instead of the test font's boxes.
const _fonts = {
  'AtkinsonHyperlegibleNext':
      'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
  'NotoNastaliqUrdu': 'assets/fonts/NotoNastaliqUrdu-Variable.ttf',
  'MmIcons': 'assets/fonts/MmIcons.ttf',
};

/// Where Material's own icon font is: in the bundle of an app that sets
/// `uses-material-design` (the gallery, the app), and in the Flutter SDK
/// beside the test runner (`bin/cache/artifacts/material_fonts`) for mm_ui,
/// which bundles no fonts but its own.
const _materialIconsAsset = 'fonts/MaterialIcons-Regular.otf';

/// The Flutter SDK's copy of Material's icon font, found from the test
/// runner (`bin/cache/artifacts/engine/<platform>/flutter_tester`).
File get _materialIconsInSdk {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  return File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

/// Loads the fonts, and Material's icon font, which stock widgets the
/// components open draw their arrows with (the date picker's month arrows),
/// so goldens show those glyphs as people see them rather than boxes. Works
/// from mm_ui's own tests (assets keyed by their path) and from packages
/// that depend on mm_ui (keyed `packages/mm_ui/…`).
Future<void> loadMmFonts() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest.listAssets().toSet();
  for (final MapEntry(key: family, value: asset) in _fonts.entries) {
    final key = assets.contains('packages/mm_ui/$asset')
        ? 'packages/mm_ui/$asset'
        : asset;
    final loader = FontLoader('packages/mm_ui/$family')
      ..addFont(rootBundle.load(key));
    await loader.load();
  }
  final materialIcons = assets.contains(_materialIconsAsset)
      ? rootBundle.load(_materialIconsAsset)
      : _materialIconsInSdk.readAsBytes().then(ByteData.sublistView);
  await (FontLoader('MaterialIcons')..addFont(materialIcons)).load();
}
