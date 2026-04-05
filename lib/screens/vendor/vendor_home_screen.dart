import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen>
    with SingleTickerProviderStateMixin {
  final String? _vendorId = FirebaseAuth.instance.currentUser?.uid;
  late final AnimationController _pulseController;
  Timer? _locationTimer;

  bool _isLive = false;
  bool _isLiveLoading = false;
  bool _isPushingLocation = false;
  int _bottomNavIndex = 0;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadInitialLiveState();
  }

  Future<void> _loadInitialLiveState() async {
    if (_vendorId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .get();
      if (mounted) {
        setState(() {
          _isLive = doc.data()?['isLive'] ?? false;
          if (_isLive) {
            _startLocationBroadcast();
          } else {
            _pulseController.stop();
          }
        });
      }
    } catch (e) {
      // handle error
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleLiveStatus() async {
    if (_vendorId == null || _isLiveLoading) return;
    setState(() => _isLiveLoading = true);

    final newStatus = !_isLive;
    try {
      if (newStatus) {
        final pushed = await _pushCurrentLocation(showFeedback: true);
        if (!pushed) {
          return;
        }
        _startLocationBroadcast();
        _pulseController.repeat(reverse: true);
      } else {
        _locationTimer?.cancel();
        _pulseController.stop();
      }
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .update({
            'isLive': newStatus,
            if (newStatus) 'lastLiveAt': FieldValue.serverTimestamp(),
            if (!newStatus) 'lastOfflineAt': FieldValue.serverTimestamp(),
          });
      if (mounted) setState(() => _isLive = newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLiveLoading = false);
    }
  }

  Future<bool> _pushCurrentLocation({bool showFeedback = false}) async {
    if (_vendorId == null || _isPushingLocation) return false;
    _isPushingLocation = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location services to go live.'),
            ),
          );
        }
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to go live.'),
            ),
          );
        }
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 6),
      );
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .update({
            'location': GeoPoint(position.latitude, position.longitude),
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } on TimeoutException {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location request timed out. Try again.'),
          ),
        );
      }
      return false;
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update location: $e')),
        );
      }
      return false;
    } finally {
      _isPushingLocation = false;
    }
  }

  void _startLocationBroadcast() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pushCurrentLocation(),
    );
  }

  void _onBottomNavTapped(int index) {
    if (_bottomNavIndex == index) return;

    // Optimistically update the UI for responsiveness
    setState(() => _bottomNavIndex = index);

    // Use a short delay to allow the UI to update before navigating
    Future.delayed(const Duration(milliseconds: 50), () {
      switch (index) {
        case 0:
          // Already on the home dashboard, do nothing.
          break;
        case 1:
          context.go('/vendor-orders');
          break;
        case 2:
          context.go('/vendor-menu');
          break;
        case 3:
          context.go('/vendor-profile');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body:
          _buildDashboard(), // Always show dashboard, nav is handled by go_router
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleLiveStatus,
        backgroundColor: _isLive ? Colors.red : Colors.green,
        child: _isLiveLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Icon(_isLive ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF111827),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.home, label: 'Home', index: 0),
            _buildNavItem(icon: Icons.receipt, label: 'Orders', index: 1),
            const SizedBox(width: 40), // The notch
            _buildNavItem(icon: Icons.menu_book, label: 'Menu', index: 2),
            _buildNavItem(icon: Icons.person, label: 'Profile', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    // The home screen is at index 0. We use the router's current location to determine
    // if we are on a sub-page, and if so, we don't highlight any nav item.
    final router = GoRouter.of(context);
    final isCurrentRouteVendorHome =
        router.routerDelegate.currentConfiguration.fullPath == '/vendor-home';
    final isSelected =
        (index == 0 && isCurrentRouteVendorHome) || _bottomNavIndex == index;

    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? const Color(0xFF4DA3FF) : Colors.grey,
      ),
      onPressed: () => _onBottomNavTapped(index),
      tooltip: label,
    );
  }

  Widget _buildDashboard() {
    final today = DateTime.now();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoLiveCard(),
            const SizedBox(height: 24),
            const Text(
              "Today's Stats",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('vendorId', isEqualTo: _vendorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildStatsRow(0, 0);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = data['createdAt'] as Timestamp?;
                  if (createdAt == null) return false;
                  return _isSameDay(createdAt.toDate(), today);
                }).toList();

                final earnings = orders
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['status'] != 'rejected';
                    })
                    .fold<double>(0.0, (sum, doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final amount =
                          (data['totalAmount'] as num?)?.toDouble() ?? 0;
                      return sum + amount;
                    });

                return _buildStatsRow(orders.length, earnings);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Orders",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/vendor-orders'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentOrders(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoLiveCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _isLive ? const Color(0xFF0D2818) : const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            if (_isLive)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(
                            0.7 * _pulseController.value,
                          ),
                          blurRadius: 10,
                          spreadRadius: 5 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      color: Colors.white,
                      size: 30,
                    ),
                  );
                },
              )
            else
              const Icon(
                Icons.power_settings_new,
                color: Colors.grey,
                size: 60,
              ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLive ? 'You are LIVE 🟢' : 'You are Offline',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLive
                        ? 'Customers can see your location'
                        : 'Tap the button below to go live',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  if (_isLive) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Broadcasting location...',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int orderCount, double earnings) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            title: "Today's Orders",
            value: orderCount.toString(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatMiniCard(
            title: "Today's Earnings",
            value: 'Rs ${earnings.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vendors')
                .doc(_vendorId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const _StatMiniCard(title: 'Rating', value: '-');
              final rating = snapshot.data?['rating'] ?? 0.0;
              return _StatMiniCard(
                title: 'Rating',
                value: rating.toStringAsFixed(1),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: _vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load recent orders right now.',
            style: TextStyle(color: Colors.grey),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
          ..sort((a, b) {
            final aTs =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTs =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.toDate().compareTo(aTs.toDate());
          });
        final recentDocs = docs.take(3).toList();

        if (recentDocs.isEmpty) {
          return const Text(
            'No recent orders.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = recentDocs[index];
            final data = order.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'unknown';
            final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
            final timestamp = data['createdAt'] as Timestamp?;
            return Card(
              color: const Color(0xFF111827),
              child: ListTile(
                title: Text(
                  'Order #${order.id.substring(0, 6)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  timestamp != null
                      ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
                      : 'No time',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF4DA3FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(label: Text(status), padding: EdgeInsets.zero),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatMiniCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
