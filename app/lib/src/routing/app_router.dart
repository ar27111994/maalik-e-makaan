import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/shell/app_shell.dart';
import 'package:maalik_e_makaan/src/shell/pending_screen.dart';

/// Builds a screen for a route; screens are plugged in as features land.
typedef ScreenBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
);

/// The app's router: redirects follow the language choice and the session
/// (see [redirectFor]) and are re-evaluated whenever either changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(settingsProvider, (_, _) => refresh.value++)
    ..listen(authStatusProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.uri,
      languageChosen: ref.read(settingsProvider).languageChosen,
      auth: ref.read(authRepositoryProvider).status,
    ),
    routes: [
      _screen(Routes.welcome, PendingScreen.welcome),
      _screen(Routes.signIn, PendingScreen.signIn),
      _screen(Routes.signUp, PendingScreen.signUp),
      _screen(Routes.forgotPassword, PendingScreen.forgotPassword),
      _screen(Routes.checkEmail, PendingScreen.checkEmail),
      _screen(Routes.updatePassword, PendingScreen.updatePassword),
      _screen(Routes.authCallback, PendingScreen.authCallback),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final (path, builder) in [
            (Routes.home, PendingScreen.home),
            (Routes.tenants, PendingScreen.tenants),
            (Routes.money, PendingScreen.money),
            (Routes.properties, PendingScreen.properties),
            (Routes.more, PendingScreen.more),
          ])
            StatefulShellBranch(routes: [_screen(path, builder)]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

GoRoute _screen(String path, ScreenBuilder builder) =>
    GoRoute(path: path, builder: builder);
