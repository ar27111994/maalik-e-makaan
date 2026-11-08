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
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/handovers/presentation/cash_book_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/dashboard_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/payment_score_section.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/reports_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/search_screen.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/tax_year_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_form_screen.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/tenancy_list.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/lease_money_section.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/record_payment_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/notifications/presentation/notifications_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/bill_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/reading_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utilities_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_account_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_form_screen.dart';
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
import 'package:mm_ui/mm_ui.dart';

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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                    routes: [
                      GoRoute(
                        path: _child(Routes.taxYear, Routes.reports),
                        builder: (context, state) => const TaxYearScreen(),
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
                      extras: (property) => DocumentsSection(
                        owner: (
                          entity: DocumentEntity.property,
                          id: property.id,
                        ),
                        canAdd: !property.archived,
                      ),
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
                          extras: (summary) => _sections([
                            TenancyList(
                              unitId: summary.unit.id,
                              canStart:
                                  !summary.unit.archived &&
                                  summary.occupancy?.leaseId == null,
                            ),
                            DocumentsSection(
                              owner: (
                                entity: DocumentEntity.unit,
                                id: summary.unit.id,
                              ),
                              canAdd: !summary.unit.archived,
                            ),
                          ]),
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
                      extras: (detail) => _sections([
                        LeaseMoneySection(leaseId: detail.lease.id),
                        DocumentsSection(
                          owner: (
                            entity: DocumentEntity.lease,
                            id: detail.lease.id,
                          ),
                        ),
                      ]),
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
                      extras: (tenant) => _sections([
                        TenancyList(tenantId: tenant.id),
                        PaymentScoreSection(tenantId: tenant.id),
                        DocumentsSection(
                          owner: (entity: DocumentEntity.tenant, id: tenant.id),
                          canAdd: !tenant.archived,
                        ),
                      ]),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.money,
                builder: (context, state) => const MoneyScreen(),
                routes: [
                  GoRoute(
                    path: _child(Routes.cash, Routes.money),
                    builder: (context, state) => const CashBookScreen(),
                  ),
                  GoRoute(
                    path: 'leases/:leaseId',
                    builder: (context, state) => TenancyLedgerScreen(
                      leaseId: state.pathParameters['leaseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'pay',
                        builder: (context, state) => RecordPaymentScreen(
                          leaseId: state.pathParameters['leaseId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'receipts/:paymentId',
                        builder: (context, state) => ReceiptScreen(
                          leaseId: state.pathParameters['leaseId']!,
                          paymentId: state.pathParameters['paymentId']!,
                        ),
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
                    path: _child(Routes.notifications, Routes.more),
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  ..._operations,
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

/// Expenses, utilities and maintenance, under More.
final List<RouteBase> _operations = [
  GoRoute(
    path: _child(Routes.expenses, Routes.more),
    builder: (context, state) => const ExpensesScreen(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) =>
            ExpenseFormScreen(requestId: state.uri.queryParameters['request']),
      ),
      GoRoute(
        path: ':expenseId',
        builder: (context, state) => ExpenseDetailScreen(
          expenseId: state.pathParameters['expenseId']!,
          extras: (expense) => DocumentsSection(
            owner: (entity: DocumentEntity.expense, id: expense.id),
          ),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ExpenseFormScreen(expenseId: state.pathParameters['expenseId']),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: _child(Routes.utilities, Routes.more),
    builder: (context, state) => const UtilitiesScreen(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => const UtilityFormScreen(),
      ),
      GoRoute(
        path: 'bills/:billId',
        builder: (context, state) => BillScreen(
          billId: state.pathParameters['billId']!,
          extras: (bill) => DocumentsSection(
            owner: (entity: DocumentEntity.utilityBill, id: bill.id),
          ),
        ),
      ),
      GoRoute(
        path: 'readings/:readingId',
        builder: (context, state) => ReadingScreen(
          readingId: state.pathParameters['readingId']!,
          extras: (detail) => DocumentsSection(
            owner: (entity: DocumentEntity.meterReading, id: detail.reading.id),
          ),
        ),
      ),
      GoRoute(
        path: ':accountId',
        builder: (context, state) =>
            UtilityAccountScreen(accountId: state.pathParameters['accountId']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                UtilityFormScreen(accountId: state.pathParameters['accountId']),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: _child(Routes.maintenance, Routes.more),
    builder: (context, state) => const MaintenanceScreen(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => MaintenanceFormScreen(
          propertyId: state.uri.queryParameters['property'],
          unitId: state.uri.queryParameters['unit'],
        ),
      ),
      GoRoute(
        path: ':requestId',
        builder: (context, state) => MaintenanceDetailScreen(
          requestId: state.pathParameters['requestId']!,
          extras: (request) => DocumentsSection(
            owner: (entity: DocumentEntity.maintenanceRequest, id: request.id),
          ),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => MaintenanceFormScreen(
              requestId: state.pathParameters['requestId'],
            ),
          ),
        ],
      ),
    ],
  ),
];

/// Sections of a detail screen from later features, one under another.
Widget _sections(List<Widget> sections) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (index, section) in sections.indexed) ...[
      if (index > 0) const SizedBox(height: MmSpace.s8),
      section,
    ],
  ],
);

/// The segment of [path] below [parent], for a nested route.
String _child(String path, String parent) => path.substring(parent.length + 1);
