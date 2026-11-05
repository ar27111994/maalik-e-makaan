import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/shell/pending_screen.dart';
import 'package:mm_ui/mm_ui.dart';

void main() {
  final builders = <String, Widget Function(BuildContext, GoRouterState)>{
    'Welcome to Maalik-e-Makaan': PendingScreen.welcome,
    'Sign in': PendingScreen.signIn,
    'Create your account': PendingScreen.signUp,
    'Reset your password': PendingScreen.forgotPassword,
    'Check your e-mail': PendingScreen.checkEmail,
    'Choose a new password': PendingScreen.updatePassword,
    'Signing you in…': PendingScreen.authCallback,
    'Home': PendingScreen.home,
    'Tenants': PendingScreen.tenants,
    'Money': PendingScreen.money,
    'Properties': PendingScreen.properties,
    'More': PendingScreen.more,
  };

  for (final MapEntry(key: name, value: builder) in builders.entries) {
    testWidgets('$name says it is being built', (tester) async {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: builder)],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: MmTheme.data(brightness: Brightness.light),
          localizationsDelegates: appLocalizationsDelegates,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('$name is being built'), findsOneWidget);
      expect(
        find.text('This part of the app arrives in the next update.'),
        findsOneWidget,
      );
    });
  }
}
