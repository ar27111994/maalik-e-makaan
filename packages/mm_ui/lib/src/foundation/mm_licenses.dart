import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licences of the fonts and icons mm_ui ships, for the app's licence
/// page (`showLicensePage`).
///
/// Flutter's own licence collection covers the pub packages, but not the
/// font files: Atkinson Hyperlegible Next, Noto Sans Arabic and Noto
/// Nastaliq Urdu are under the SIL Open Font License, and the icons come
/// from Lucide (ISC), whose notices must travel with every copy. Call
/// [register] once, before the app runs:
///
/// ```dart
/// MmLicenses.register();
/// runApp(const MyApp());
/// ```
abstract final class MmLicenses {
  /// The licence files, by the name the licence page lists them under.
  static const Map<String, String> files = {
    'Atkinson Hyperlegible Next': 'OFL-AtkinsonHyperlegibleNext.txt',
    'Noto Sans Arabic': 'OFL-NotoSansArabic.txt',
    'Noto Nastaliq Urdu': 'OFL-NotoNastaliqUrdu.txt',
    'Lucide icons': 'LICENSE-lucide.txt',
  };

  /// Where the licence files are in the app's asset bundle.
  static String assetOf(String file) => 'packages/mm_ui/assets/fonts/$file';

  static bool _registered = false;

  /// Adds the fonts' and icons' licences to [LicenseRegistry], read from
  /// [bundle] (the app's own by default) when the licence page asks for
  /// them. Calling it again adds nothing more.
  static void register({AssetBundle? bundle}) {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() => _entries(bundle ?? rootBundle));
  }

  static Stream<LicenseEntry> _entries(AssetBundle bundle) async* {
    for (final MapEntry(key: name, value: file) in files.entries) {
      final text = await bundle.loadString(assetOf(file), cache: false);
      yield LicenseEntryWithLineBreaks([name], text);
    }
  }

  /// Forgets that [register] ran, so a test can register again.
  @visibleForTesting
  static void debugReset() => _registered = false;
}
