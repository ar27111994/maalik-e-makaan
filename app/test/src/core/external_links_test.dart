import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final link = Uri(scheme: 'tel', path: '+923000000000');

  test('opens the link in another app and passes on the answer', () async {
    final asked = <(Uri, LaunchMode)>[];
    for (final answer in [true, false]) {
      final opened = await openExternally(
        link,
        launch: (link, {mode = LaunchMode.platformDefault}) async {
          asked.add((link, mode));
          return answer;
        },
      );
      expect(opened, answer);
    }
    expect(asked, [
      (link, LaunchMode.externalApplication),
      (link, LaunchMode.externalApplication),
    ]);
  });

  test('no app for the link on Android is false, not an exception', () async {
    final opened = await openExternally(
      link,
      launch: (link, {mode = LaunchMode.platformDefault}) =>
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    );
    expect(opened, isFalse);
  });

  test('other errors are not hidden', () {
    expect(
      openExternally(
        link,
        launch: (link, {mode = LaunchMode.platformDefault}) =>
            throw StateError('bug'),
      ),
      throwsStateError,
    );
  });
}
