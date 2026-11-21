import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/crm/presentation/pages/crm_page.dart';
import '../../features/dashboard/presentation/pages/home_dashboard_page.dart';
import '../../features/deliveries/presentation/pages/deliveries_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/financials/presentation/pages/financials_page.dart';
import '../../features/invoices/presentation/pages/invoice_detail_page.dart';
import '../../features/parties/presentation/pages/parties_page.dart';
import '../../features/plots/presentation/pages/plots_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/inventory_operations_page.dart';
import '../../features/purchases/presentation/pages/purchases_page.dart';
import '../../features/quotations/presentation/pages/quotations_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/app_shell_page.dart';
import '../../data/local/db/app_database.dart';
import '../app_dependencies.dart';

class AppRouter {
  AppRouter(this.dependencies)
      : router = GoRouter(
          navigatorKey: dependencies.rootNavigatorKey,
          initialLocation: '/login',
          refreshListenable: GoRouterRefreshStream(dependencies.appCubit.stream),
          redirect: (context, state) {
            final isAuthenticated = dependencies.appCubit.state.isAuthenticated;
            final isLoginRoute = state.uri.path == '/login';

            if (!isAuthenticated && !isLoginRoute) {
              return '/login';
            }
            if (isAuthenticated && isLoginRoute) {
              return '/home';
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginPage(),
            ),
            ShellRoute(
              builder: (context, state, child) {
                return AppShellPage(currentPath: state.uri.path, child: child);
              },
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeDashboardPage(),
                ),
                GoRoute(
                  path: '/pos',
                  builder: (context, state) => const PosPage(),
                ),
                GoRoute(
                  path: '/products',
                  builder: (context, state) => const ProductsPage(),
                ),
                GoRoute(
                  path: '/inventory',
                  builder: (context, state) => const InventoryOperationsPage(),
                ),
                GoRoute(
                  path: '/purchases',
                  builder: (context, state) => const PurchasesPage(),
                ),
                GoRoute(
                  path: '/parties',
                  builder: (context, state) => const PartiesPage(),
                ),
                GoRoute(
                  path: '/financials',
                  builder: (context, state) => const FinancialsPage(),
                ),
                GoRoute(
                  path: '/employees',
                  builder: (context, state) => const EmployeesPage(),
                ),
                GoRoute(
                  path: '/plots',
                  builder: (context, state) => const PlotsPage(),
                ),
                GoRoute(
                  path: '/crm',
                  builder: (context, state) => const CrmPage(),
                ),
                GoRoute(
                  path: '/quotations',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return QuotationsPage(
                      preselectedPlot: extra?['preselectedPlot'] as Plot?,
                      preselectedLead: extra?['preselectedLead'] as Lead?,
                    );
                  },
                ),
                GoRoute(
                  path: '/bookings',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return BookingsPage(
                      preselectedPlotId: extra?['preselectedPlotId'] as int?,
                    );
                  },
                ),
                GoRoute(
                  path: '/deliveries',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return DeliveriesPage(
                      preselectedSaleId: extra?['preselectedSaleId'] as int?,
                    );
                  },
                ),
                GoRoute(
                  path: '/reports',
                  builder: (context, state) => const ReportsPage(),
                  routes: [
                    GoRoute(
                      path: 'invoice/:id',
                      builder: (context, state) {
                        final id = int.tryParse(state.pathParameters['id'] ?? '');
                        return InvoiceDetailPage(saleId: id ?? 0);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        );

  final AppDependencies dependencies;
  final GoRouter router;
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
