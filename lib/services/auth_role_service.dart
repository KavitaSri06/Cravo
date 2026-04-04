import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole { customer, vendor, unknown, conflict }

class AuthRoleService {
  AuthRoleService._();

  static final Map<String, AppUserRole> _roleCache = <String, AppUserRole>{};

  static Future<AppUserRole> resolveCurrentUserRole({
    bool forceRefresh = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return AppUserRole.unknown;
    return resolveRoleForUid(uid, forceRefresh: forceRefresh);
  }

  static Future<AppUserRole> resolveRoleForUid(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _roleCache.containsKey(uid)) {
      return _roleCache[uid]!;
    }

    try {
      final reads = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance.collection('vendors').doc(uid).get(),
      ]);

      final userDoc = reads[0];
      final vendorDoc = reads[1];

      final userExists = userDoc.exists;
      final vendorExists = vendorDoc.exists;

      final role = switch ((userExists, vendorExists)) {
        (true, false) => AppUserRole.customer,
        (false, true) => AppUserRole.vendor,
        (false, false) => AppUserRole.unknown,
        (true, true) => AppUserRole.conflict,
      };

      _roleCache[uid] = role;
      return role;
    } catch (_) {
      return AppUserRole.unknown;
    }
  }

  static String routeForRole(AppUserRole role) {
    return switch (role) {
      AppUserRole.customer => '/home',
      AppUserRole.vendor => '/vendor-home',
      AppUserRole.unknown || AppUserRole.conflict => '/login',
    };
  }

  static void clearCacheForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _roleCache.remove(uid);
  }

  static void clearAllCache() {
    _roleCache.clear();
  }
}
