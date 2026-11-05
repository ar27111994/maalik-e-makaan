import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/bootstrap.dart';

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
}
