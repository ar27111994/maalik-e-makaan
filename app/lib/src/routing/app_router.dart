import 'dart:async';

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
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_form_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/tenancy_list.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/create_portfolio_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_details_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/properties_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/property_form_screen.dart';
import 'package:maalik_e_makaan/src/features/properties/presentation/unit_screens.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/accept_invitation_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/invite_member_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/team_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_form_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenants_screen.dart';
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
  // The token of an invitation link just opened, until the device keeps it
  // (providers cannot change while the router builds the first page).
  String? captured;
  void changed(Object? _, Object? _) => refresh.value++;
  ref
    ..listen(settingsProvider.select((s) => s.languageChosen), changed)
    ..listen(authStatusProvider, changed)
    ..listen(portfolioGateProvider, changed)
    ..listen(pendingInvitationProvider.select((token) => token != null), (
      _,
      _,
    ) {
      // Kept now: the link's token no longer needs holding here.
      captured = null;
      refresh.value++;
    });

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      // An invitation link carries its token in the fragment: keep it on
      // the device and drop it from the address, so it never reaches a
      // `from` parameter (or a server log) on the way to signing in.
      if (state.uri.path == Routes.invite) {
        final token = invitationToken(state.uri);
        if (token != null) {
          captured = token;
          unawaited(
            Future(
              () => ref.read(pendingInvitationProvider.notifier).hold(token),
            ),
          );
          return Routes.invite;
        }
      }
      return redirectFor(
        location: state.uri,
        languageChosen: ref.read(settingsProvider).languageChosen,
        auth: ref.read(authStatusProvider),
        portfolios: ref.read(portfolioGateProvider),
        invitationPending:
            captured != null || ref.read(pendingInvitationProvider) != null,
      );
    },
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
      GoRoute(
        path: Routes.invite,
        builder: (context, state) => const AcceptInvitationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          _branch(Routes.home, PendingScreen.dashboard),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.properties,
                builder: (context, state) => const PropertiesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const PropertyFormScreen(),
                  ),
                  GoRoute(
                    path: ':propertyId',
                    builder: (context, state) => PropertyDetailScreen(
                      propertyId: state.pathParameters['propertyId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => PropertyFormScreen(
                          propertyId: state.pathParameters['propertyId'],
                        ),
                      ),
                      GoRoute(
                        path: 'units/new',
                        builder: (context, state) => UnitFormScreen(
                          propertyId: state.pathParameters['propertyId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'units/:unitId',
                        builder: (context, state) => UnitDetailScreen(
                          propertyId: state.pathParameters['propertyId']!,
                          unitId: state.pathParameters['unitId']!,
                          extras: (summary) => TenancyList(
                            unitId: summary.unit.id,
                            canStart:
                                !summary.unit.archived &&
                                summary.occupancy?.leaseId == null,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (context, state) => UnitFormScreen(
                              propertyId: state.pathParameters['propertyId']!,
                              unitId: state.pathParameters['unitId'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.leases,
                redirect: (context, state) =>
                    state.uri.path == Routes.leases ? Routes.tenants : null,
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => LeaseFormScreen(
                      unitId: state.uri.queryParameters['unit'],
                      tenantId: state.uri.queryParameters['tenant'],
                    ),
                  ),
                  GoRoute(
                    path: ':leaseId',
                    builder: (context, state) => LeaseDetailScreen(
                      leaseId: state.pathParameters['leaseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => LeaseFormScreen(
                          leaseId: state.pathParameters['leaseId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: Routes.tenants,
                builder: (context, state) => const TenantsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const TenantFormScreen(),
                  ),
                  GoRoute(
                    path: ':tenantId',
                    builder: (context, state) => TenantDetailScreen(
                      tenantId: state.pathParameters['tenantId']!,
                      extras: (tenant) => TenancyList(tenantId: tenant.id),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => TenantFormScreen(
                          tenantId: state.pathParameters['tenantId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          _branch(Routes.money, PendingScreen.money),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: _child(Routes.team, Routes.more),
                    builder: (context, state) => const TeamScreen(),
                    routes: [
                      GoRoute(
                        path: _child(Routes.inviteMember, Routes.team),
                        builder: (context, state) => InviteMemberScreen(
                          draft: state.extra is InviteDraft
                              ? state.extra! as InviteDraft
                              : null,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: _child(Routes.portfolioDetails, Routes.more),
                    builder: (context, state) => const PortfolioDetailsScreen(),
                  ),
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
