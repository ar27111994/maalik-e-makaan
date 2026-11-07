import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui_gallery/src/settings.dart';

import 'support/gallery_harness.dart';

/// Every page of the gallery, scrolled top to bottom, in every variant on a
/// phone, and in English and Urdu on a desktop window: no exception, no
/// overflow, and the accessibility guidelines met at every stop.
void main() {
  for (final family in GalleryFamily.values) {
    group('${family.name} page', () {
      for (final variant in GalleryVariant.values) {
        testWidgets('on a phone, ${variant.name}', (tester) async {
          await pumpGallery(tester, family: family, settings: variant.settings);
          expect(await checkWholePage(tester), greaterThan(0));
        });
      }
      for (final variant in [GalleryVariant.light, GalleryVariant.urdu]) {
        testWidgets('on a desktop, ${variant.name}', (tester) async {
          await pumpGallery(
            tester,
            family: family,
            settings: variant.settings,
            size: desktop,
          );
          expect(await checkWholePage(tester), greaterThan(0));
        });
      }
    });
  }
}
