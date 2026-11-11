import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/bootstrap.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';

void main() {
  testWidgets('a build without its settings explains what is missing', (
    tester,
  ) async {
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
    });

    // Tests are compiled without --dart-define, so the configuration fails.
    await bootstrap();
    await tester.pumpAndSettle();
    expect(find.text('This build is not set up'), findsOneWidget);
    expect(find.text('SUPABASE_URL is required.'), findsOneWidget);
    expect(find.textContaining('--dart-define-from-file'), findsOneWidget);

    // Uncaught errors are reported, not fatal.
    expect(
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
      isTrue,
    );
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('y')));
  });

  testWidgets('on an Urdu device the title is Urdu, the details stay LTR', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ur')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ConfigErrorApp(error: ConfigException('APP_URL', 'is required')),
    );
    await tester.pumpAndSettle();
    final title = find.text('یہ بلڈ سیٹ اپ نہیں');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    final details = find.text('APP_URL is required.');
    expect(Directionality.of(tester.element(details)), TextDirection.ltr);
    expect(
      tester.getSemantics(title),
      matchesSemantics(label: 'یہ بلڈ سیٹ اپ نہیں', isHeader: true),
    );
  });
}
