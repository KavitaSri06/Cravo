import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_role_service.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  final String? _vendorId = FirebaseAuth.instance.currentUser?.uid;
  late final TabController _tabController;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Access denied by Firestore rules. Publish updated rules and try again.';
      }
      if (error.code == 'failed-precondition') {
        return 'Firestore index required. Create the index from Firebase Console.';
      }
      return 'Firestore error: ${error.code}';
    }
    return 'Unable to load orders.';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (status == 'confirmed')
        payload['confirmedAt'] = FieldValue.serverTimestamp();
      if (status == 'ready') payload['readyAt'] = FieldValue.serverTimestamp();
      if (status == 'collected')
        payload['collectedAt'] = FieldValue.serverTimestamp();
      if (status == 'rejected')
        payload['rejectedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(payload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status.')),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      AuthRoleService.clearAllCache();
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to logout right now. Please try again.'),
        ),
      );
    }
  }

  void _goBackToVendorHome() {
    if (!mounted) return;
    context.go('/vendor-home');
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterOrders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int tab,
  ) {
    if (tab == 3) return docs;

    final status = switch (tab) {
      0 => 'placed',
      1 => 'confirmed',
      2 => 'ready',
      _ => '',
    };

    return docs.where((doc) => (doc.data()['status'] ?? '') == status).toList();
  }

  String _readableTime(Timestamp? ts) {
    if (ts == null) return '--';
    final dt = ts.toDate();
    final hh = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final mm = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_vendorId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'Please login as vendor.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: _vendorId)
        .snapshots();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBackToVendorHome();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBackToVendorHome,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: const Text('Vendor Orders'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: _subtle,
            indicatorColor: _accent,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Confirmed'),
              Tab(text: 'Ready'),
              Tab(text: 'All'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _friendlyError(snapshot.error!),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            final docs = (snapshot.data?.docs ?? []).toList()
              ..sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                return bMs.compareTo(aMs);
              });

            return TabBarView(
              controller: _tabController,
              children: List.generate(4, (tabIndex) {
                final filtered = _filterOrders(docs, tabIndex);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inbox_rounded, size: 76, color: _subtle),
                        SizedBox(height: 10),
                        Text(
                          'No orders in this section yet.',
                          style: TextStyle(color: _subtle),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final status = (data['status'] ?? 'placed').toString();
                    final customerName =
                        (data['customerName'] ?? 'Cravo Customer').toString();
                    final items = (data['items'] as List?) ?? [];
                    final total =
                        (data['totalAmount'] as num?)?.toDouble() ?? 0;
                    final createdAt = data['createdAt'] as Timestamp?;

                    final summary = items
                        .take(2)
                        .map((e) {
                          if (e is! Map) return 'Item';
                          return (e['name'] ?? 'Food Item').toString();
                        })
                        .join(', ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF27344A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order ${doc.id.substring(0, 6).toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF21334D),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            customerName,
                            style: const TextStyle(color: _subtle),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.isEmpty ? 'No items listed' : summary,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Rs ${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: _accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _readableTime(createdAt),
                                style: const TextStyle(color: _subtle),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (status == 'placed')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(doc.id, 'confirmed'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(doc.id, 'rejected'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          if (status == 'confirmed')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(doc.id, 'ready'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                ),
                                child: const Text('Mark Ready'),
                              ),
                            ),
                          if (status == 'ready')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _updateStatus(doc.id, 'collected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B7280),
                                ),
                                child: const Text('Mark Collected'),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
