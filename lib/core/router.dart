import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/constants/app_constants.dart';
import '../presentation/admin/beton_screen.dart';
import '../presentation/admin/client_screen.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/admin/admin_shell.dart';
import '../presentation/admin/orders_screen.dart';
import '../presentation/admin/staff_screen.dart';
import '../presentation/admin/history_screen.dart';
import '../presentation/admin/desired_quantity_screen.dart';
import '../presentation/commercial/commercial_shell.dart';
import '../presentation/commercial/commercial_dashboard.dart';
import '../presentation/commercial/create_order_screen.dart';
import '../presentation/commercial/commercial_desired_quantity.dart';
import '../presentation/operator/operator_shell.dart';
import '../presentation/operator/operator_dashboard.dart';
import '../presentation/operator/operator_desired_quantity.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final user = authState.value;
      final isLoggedIn = user != null;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) {
        final role = await ref.read(authServiceProvider).getCurrentUserRole();
        switch (role) {
          case AppConstants.roleAdmin:
            return '/admin';
          case AppConstants.roleCommercial:
            return '/commercial';
          case AppConstants.roleOperator:
            return '/operator';
          default:
            return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),

      // Admin routes
      ShellRoute(
        builder: (ctx, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (ctx, state) => const AdminOrdersScreen()),
          GoRoute(path: '/admin/clients', builder: (ctx, state) => const ClientsScreen()),
          GoRoute(path: '/admin/betons', builder: (ctx, state) => const BetonsScreen()),
          GoRoute(path: '/admin/staff', builder: (ctx, state) => const StaffScreen()),
          GoRoute(path: '/admin/history', builder: (ctx, state) => const HistoryScreen()),
          GoRoute(path: '/admin/quantity', builder: (ctx, state) => const DesiredQuantityScreen()),
        ],
      ),

      // Commercial routes
      ShellRoute(
        builder: (ctx, state, child) => CommercialShell(child: child),
        routes: [
          GoRoute(path: '/commercial', builder: (ctx, state) => const CommercialDashboard()),
          GoRoute(path: '/commercial/create-order', builder: (ctx, state) => const CreateOrderScreen()),
          GoRoute(path: '/commercial/quantity', builder: (ctx, state) => const CommercialDesiredQuantity()),
        ],
      ),

      // Operator routes
      ShellRoute(
        builder: (ctx, state, child) => OperatorShell(child: child),
        routes: [
          GoRoute(path: '/operator', builder: (ctx, state) => const OperatorDashboard()),
          GoRoute(path: '/operator/quantity', builder: (ctx, state) => const OperatorDesiredQuantity()),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});