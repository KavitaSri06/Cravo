import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_role_service.dart';

class CustomerProfileTab extends StatelessWidget {
  const CustomerProfileTab({super.key, required this.onBrowseTrucks});

  final VoidCallback onBrowseTrucks;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _subtle = Color(0xFFA4ACBE);

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      AuthRoleService.clearAllCache();
      if (!context.mounted) return;
      context.go('/login');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to logout right now. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const ColoredBox(
        color: _bg,
        child: Center(
          child: Text(
            'Please login to view your profile.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();

    return ColoredBox(
      color: _bg,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4DA3FF)),
            );
          }

          final data = snapshot.data?.data() ?? {};
          final fullName = (data['fullName'] ?? 'Cravo User').toString();
          final email =
              (data['email'] ??
                      FirebaseAuth.instance.currentUser?.email ??
                      '--')
                  .toString();
          final initial = fullName.trim().isEmpty
              ? 'C'
              : fullName.trim().substring(0, 1).toUpperCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: _primary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: _subtle)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF26344B)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Edit Profile',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'UI only for now',
                        style: TextStyle(color: _subtle),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _subtle,
                        size: 14,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Profile editing will be available soon.',
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFF27344A), height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.local_shipping_outlined,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Browse Food Trucks',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _subtle,
                        size: 14,
                      ),
                      onTap: onBrowseTrucks,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
