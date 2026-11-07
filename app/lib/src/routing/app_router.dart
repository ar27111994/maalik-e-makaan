import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/presentation/auth_callback_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/check_email_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/forgot_password_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/sign_in_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/sign_up_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/update_password_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/welcome_screen.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/delete_account_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/create_portfolio_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/settings/presentation/settings_screen.dart';
import 'package:maalik_e_makaan/src/shell/app_shell.dart';
import 'package:maalik_e_makaan/src/shell/more_screen.dart';
import 'package:maalik_e_makaan/src/shell/pending_screen.dart';

/// The app's router: redirects follow the language choice, the session and
/// whether the user has a portfolio (see [redirectFor]), and are evaluated
/// again whenever one of them changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void changed(Object? _, Object? _) => refresh.value++;
  ref
    ..listen(settingsProvider.select((s) => s.languageChosen), changed)
    ..listen(authStatusProvider, changed)
    ..listen(portfolioGateProvider, changed);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.uri,
      languageChosen: ref.read(settingsProvider).languageChosen,
      auth: ref.read(authStatusProvider),
      portfolios: ref.read(portfolioGateProvider),
    ),
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: Routes.checkEmail,
        builder: (context, state) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: Routes.updatePassword,
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: Routes.authCallback,
        builder: (context, state) => AuthCallbackScreen(link: state.uri),
      ),
      GoRoute(
        path: Routes.createPortfolio,
        builder: (context, state) => const CreatePortfolioScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          _branch(Routes.home, PendingScreen.dashboard),
          _branch(Routes.properties, PendingScreen.properties),
          _branch(Routes.tenants, PendingScreen.tenants),
          _branch(Routes.money, PendingScreen.money),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: _child(Routes.settings, Routes.more),
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: _child(Routes.deleteAccount, Routes.settings),
                        builder: (context, state) =>
                            const DeleteAccountScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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

StatefulShellBranch _branch(String path, WidgetBuilder builder) =>
    StatefulShellBranch(
      routes: [
        GoRoute(path: path, builder: (context, state) => builder(context)),
      ],
    );

/// The segment of [path] below [parent], for a nested route.
String _child(String path, String parent) => path.substring(parent.length + 1);
