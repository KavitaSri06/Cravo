import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../screens/customer/home_screen.dart';
import '../screens/customer/order_status_screen.dart';
import '../screens/customer/truck_detail_screen.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/register_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/vendor/vendor_home_screen.dart';
import '../screens/vendor/vendor_menu_screen.dart';
import '../screens/vendor/vendor_orders_screen.dart';
import '../screens/vendor/vendor_profile_screen.dart';
import '../services/auth_role_service.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final path = state.matchedLocation;
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    // Define route categories
    final publicRoutes = ['/', '/login', '/register'];
    final customerRoutes = [
      '/home',
      '/truck-detail/:vendorId',
      '/order-status/:orderId',
    ];
    final vendorRoutes = [
      '/vendor-home',
      '/vendor-orders',
      '/vendor-menu',
      '/vendor-profile',
    ];

    final isPublic = publicRoutes.contains(path);
    final isCustomer =
        customerRoutes.contains(
          path.split('/').firstWhere((s) => s.isNotEmpty, orElse: () => ''),
        ) ||
        path.startsWith('/truck-detail/') ||
        path.startsWith('/order-status/');
    final isVendor = vendorRoutes.contains(path);

    if (!loggedIn) {
      // If not logged in, only allow public routes. Redirect others to login.
      return isPublic ? null : '/login';
    }

    // User is logged in
    final role = await AuthRoleService.resolveCurrentUserRole();

    // If role is unknown or conflicted, log out and redirect to login
    if (role == AppUserRole.unknown || role == AppUserRole.conflict) {
      await FirebaseAuth.instance.signOut();
      AuthRoleService.clearAllCache();
      return '/login';
    }

    // If logged in, trying to access auth pages (login/register), redirect to their home
    if (path == '/login' || path == '/register') {
      return AuthRoleService.routeForRole(role);
    }

    // Role-based route protection
    if (role == AppUserRole.customer && isVendor) {
      return '/home'; // Customer trying to access vendor route
    }
    if (role == AppUserRole.vendor && isCustomer) {
      return '/vendor-home'; // Vendor trying to access customer route
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Customer Routes
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/truck-detail/:vendorId',
      builder: (context, state) =>
          TruckDetailScreen(vendorId: state.pathParameters['vendorId']!),
    ),
    GoRoute(
      path: '/order-status/:orderId',
      builder: (context, state) =>
          OrderStatusScreen(orderId: state.pathParameters['orderId']!),
    ),

    // Vendor Routes
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
    GoRoute(
      path: '/vendor-profile',
      builder: (context, state) => const VendorProfileScreen(),
    ),
  ],
);
