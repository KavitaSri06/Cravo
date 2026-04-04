import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerOrdersTab extends StatelessWidget {
  const CustomerOrdersTab({
    super.key,
    required this.onOpenOrder,
    required this.onBrowseTrucks,
  });

  final ValueChanged<String> onOpenOrder;
  final VoidCallback onBrowseTrucks;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const ColoredBox(
        color: _bg,
        child: Center(
          child: Text(
            'Please login to view your orders.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return ColoredBox(
      color: _bg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load orders.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: _subtle,
                      size: 78,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No orders yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse nearby food trucks and place your first order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subtle),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onBrowseTrucks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56A0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Browse Trucks'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = (data['status'] ?? 'placed').toString();
              final items = (data['items'] as List?) ?? [];
              final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;

              final itemsPreview = items
                  .take(3)
                  .map((item) {
                    if (item is! Map) return 'Item';
                    return (item['name'] ?? 'Food Item').toString();
                  })
                  .join(', ');

              return GestureDetector(
                onTap: () => onOpenOrder(doc.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF26344B)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order ${doc.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21334D),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        itemsPreview.isEmpty ? 'No items' : itemsPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _subtle),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Rs ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: _subtle,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
