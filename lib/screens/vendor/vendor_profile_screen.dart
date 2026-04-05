import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cravo/services/auth_role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // This should not happen if routed correctly
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF0A0F1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendor-home'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Vendor not found.'));
          }

          final vendorData = snapshot.data!.data() as Map<String, dynamic>;
          final businessName = vendorData['businessName'] ?? 'N/A';
          final ownerName = vendorData['ownerName'] ?? 'N/A';
          final email = vendorData['email'] ?? 'N/A';
          final cuisineType = vendorData['cuisineType'] ?? 'N/A';
          final rating = vendorData['rating']?.toString() ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade800,
                  child: Text(
                    businessName.isNotEmpty
                        ? businessName[0].toUpperCase()
                        : 'V',
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ownerName,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(cuisineType),
                  backgroundColor: Colors.blue.shade900,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                _buildStatsSection(uid, rating),
                const SizedBox(height: 24),
                _buildSettingsSection(context),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      AuthRoleService.clearAllCache();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    child: const Text(
                      'Logout',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(String vendorId, String rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCard(label: 'Total Orders', future: _getOrderCount(vendorId)),
        _StatCard(
          label: 'Completed',
          future: _getOrderCount(vendorId, status: 'collected'),
        ),
        _StatCard(label: 'Rating', value: rating),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Business Info',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.edit, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Editing coming soon!')),
              );
            },
          ),
          const Divider(color: Colors.grey, height: 1),
          ListTile(
            title: const Text(
              'Cuisine Type',
              style: TextStyle(color: Colors.white),
            ),
            trailing: Text(
              'Indian', // Placeholder
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getOrderCount(String vendorId, {String? status}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId);
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String? value;
  final Future<int>? future;

  const _StatCard({required this.label, this.value, this.future});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            else
              FutureBuilder<int>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Text(
                    (snapshot.data ?? 0).toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
