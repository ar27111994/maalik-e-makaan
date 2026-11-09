import 'package:flutter/widgets.dart';

/// The gallery's own words in English and Urdu.
///
/// Components never hard-code what people read: the app passes its own
/// localisations. The gallery stands in for the app, so it picks the
/// English or Urdu wording of each label, message and sample record here.
extension GalleryCopy on BuildContext {
  /// Whether the gallery is shown in Urdu.
  bool get isUrdu => Localizations.localeOf(this).languageCode == 'ur';

  /// [en] in the English gallery, [ur] in the Urdu one.
  String tr(String en, String ur) => isUrdu ? ur : en;
}
