import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_role_service.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/order_status_screen.dart';
import '../screens/customer/truck_detail_screen.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/register_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/vendor/vendor_home_screen.dart';
import '../screens/vendor/vendor_menu_screen.dart';
import '../screens/vendor/vendor_orders_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final path = state.matchedLocation;
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final authRoutes = {'/login', '/register'};
    final publicRoutes = {'/', '/login', '/register'};
    final vendorRoutes = {'/vendor-home', '/vendor-orders', '/vendor-menu'};
    final customerRoutes = {'/home'};
    final isAuthRoute = authRoutes.contains(path);
    final isPublicRoute = publicRoutes.contains(path);
    final isVendorRoute = vendorRoutes.contains(path);
    final isCustomerProtectedRoute =
        customerRoutes.contains(path) ||
        path.startsWith('/truck-detail/') ||
        path.startsWith('/order-status/');

    if (!loggedIn) {
      if (isPublicRoute) return null;
      return '/login';
    }

    final role = await AuthRoleService.resolveCurrentUserRole();
    if (role == AppUserRole.conflict) {
      await FirebaseAuth.instance.signOut();
      AuthRoleService.clearAllCache();
      return '/login';
    }

    if (role == AppUserRole.unknown) {
      await FirebaseAuth.instance.signOut();
      AuthRoleService.clearAllCache();
      return '/login';
    }

    if (isAuthRoute) {
      return AuthRoleService.routeForRole(role);
    }

    if (role == AppUserRole.customer && isVendorRoute) {
      return '/home';
    }

    if (role == AppUserRole.vendor && isCustomerProtectedRoute) {
      return '/vendor-home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/truck-detail/:vendorId',
      builder: (context, state) =>
          TruckDetailScreen(vendorId: state.pathParameters['vendorId'] ?? ''),
    ),
    GoRoute(
      path: '/order-status/:orderId',
      builder: (context, state) =>
          OrderStatusScreen(orderId: state.pathParameters['orderId'] ?? ''),
    ),
    GoRoute(
      path: '/vendor-home',
      builder: (context, state) => const VendorHomeScreen(),
    ),
    GoRoute(
      path: '/vendor-orders',
      builder: (context, state) => const VendorOrdersScreen(),
    ),
    GoRoute(
      path: '/vendor-menu',
      builder: (context, state) => const VendorMenuScreen(),
    ),
  ],
);
