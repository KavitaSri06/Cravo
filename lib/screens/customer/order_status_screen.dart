import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  int _statusIndex(String status) {
    switch (status) {
      case 'confirmed':
        return 1;
      case 'ready':
        return 2;
      case 'collected':
        return 3;
      default:
        return 0;
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '--';
    final dt = value.toDate();
    final hh = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final mm = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $period';
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Order Status'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to track this order.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(
              child: Text(
                'Order not found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final status = (data['status'] ?? 'placed').toString();
          final activeIndex = _statusIndex(status);
          final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;

          final steps = [
            ('Placed', Icons.receipt_long_outlined, data['placedAt'] ?? data['createdAt']),
            ('Confirmed', Icons.check_circle_outline, data['confirmedAt']),
            ('Ready', Icons.local_dining_outlined, data['readyAt']),
            ('Collected', Icons.shopping_bag_outlined, data['collectedAt']),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _card,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.greenAccent,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Order ID: ${widget.orderId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: List.generate(steps.length, (index) {
                    final (label, icon, time) = steps[index];
                    final isCompleted = index < activeIndex;
                    final isActive = index == activeIndex;
                    final color = isCompleted
                        ? Colors.green
                        : isActive
                            ? _accent
                            : const Color(0xFF4A556B);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isActive || isCompleted
                                    ? Colors.white
                                    : _subtle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimestamp(time),
                            style: const TextStyle(color: _subtle, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text(
                        'No items found for this order.',
                        style: TextStyle(color: _subtle),
                      )
                    else
                      ...items.map((item) {
                        final name = (item['name'] ?? 'Menu item').toString();
                        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                        final line = (item['lineTotal'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$name x$qty',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                'Rs ${line.toStringAsFixed(0)}',
                                style: const TextStyle(color: _subtle),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(color: Color(0xFF2A3447), height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Amount',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          'Rs ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [_primary, _accent]),
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
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
