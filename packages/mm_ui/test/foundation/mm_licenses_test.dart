import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

/// An asset bundle that reads mm_ui's files from the package on disk, under
/// the keys an app's bundle has for them.
class _PackageBundle extends CachingAssetBundle {
  final asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    const prefix = 'packages/mm_ui/';
    if (!key.startsWith(prefix)) throw FlutterError('no asset $key');
    final bytes = File(key.substring(prefix.length)).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  tearDown(MmLicenses.debugReset);

  test('every licence file is in the package and declared as an asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final file in MmLicenses.files.values) {
      expect(File('assets/fonts/$file').existsSync(), isTrue, reason: file);
      expect(pubspec, contains('- assets/fonts/$file'), reason: file);
    }
  });

  test('registers the fonts and icons with the licence page, once', () async {
    final bundle = _PackageBundle();
    MmLicenses.register(bundle: bundle);
    MmLicenses.register(bundle: bundle);
    final entries = await LicenseRegistry.licenses.toList();
    final ours = {
      for (final entry in entries)
        for (final package in entry.packages)
          if (MmLicenses.files.containsKey(package))
            package: entry.paragraphs.map((p) => p.text).join('\n'),
    };
    expect(ours.keys, unorderedEquals(MmLicenses.files.keys));
    expect(
      ours['Atkinson Hyperlegible Next'],
      contains('SIL OPEN FONT LICENSE'),
    );
    expect(ours['Noto Nastaliq Urdu'], contains('SIL OPEN FONT LICENSE'));
    expect(ours['Lucide icons'], contains('ISC License'));
    // Registered once: each file read once.
    expect(bundle.asked, hasLength(MmLicenses.files.length));
    expect(
      bundle.asked,
      everyElement(startsWith('packages/mm_ui/assets/fonts/')),
    );
  });
}
