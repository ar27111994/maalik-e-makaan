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

/// Loads the fonts. Works from mm_ui's own tests (assets keyed by their
/// path) and from packages that depend on mm_ui (keyed `packages/mm_ui/…`).
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
}
