import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole { customer, vendor, unknown, conflict }

class AuthRoleService {
  static final Map<String, AppUserRole> _cache = {};

  static Future<AppUserRole> resolveCurrentUserRole({
    bool forceRefresh = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AppUserRole.unknown;
    }

    if (!forceRefresh && _cache.containsKey(user.uid)) {
      return _cache[user.uid]!;
    }

    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final vendorDoc = FirebaseFirestore.instance
          .collection('vendors')
          .doc(user.uid);

      final userDocSnapshot = await userDoc.get();
      final vendorDocSnapshot = await vendorDoc.get();

      final isCustomer =
          userDocSnapshot.exists &&
          userDocSnapshot.data()?['role'] == 'customer';
      final isVendor =
          vendorDocSnapshot.exists &&
          vendorDocSnapshot.data()?['role'] == 'vendor';

      AppUserRole role;
      if (isCustomer && isVendor) {
        role = AppUserRole.conflict;
      } else if (isCustomer) {
        role = AppUserRole.customer;
      } else if (isVendor) {
        role = AppUserRole.vendor;
      } else {
        role = AppUserRole.unknown;
      }

      _cache[user.uid] = role;
      return role;
    } catch (e) {
      // Handle potential Firestore errors, e.g., network issues
      return AppUserRole.unknown;
    }
  }

  static String routeForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.customer:
        return '/home';
      case AppUserRole.vendor:
        return '/vendor-home';
      case AppUserRole.unknown:
      case AppUserRole.conflict:
        return '/login';
    }
  }

  static void clearAllCache() {
    _cache.clear();
  }
}
