import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class TruckDetailScreen extends StatefulWidget {
  const TruckDetailScreen({super.key, required this.vendorId});

  final String vendorId;

  @override
  State<TruckDetailScreen> createState() => _TruckDetailScreenState();
}

class _TruckDetailScreenState extends State<TruckDetailScreen> {
  final Map<String, _CartLine> _cart = <String, _CartLine>{};

  Position? _currentPosition;
  bool _placingOrder = false;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  int get _cartCount =>
      _cart.values.fold<int>(0, (totalQty, item) => totalQty + item.quantity);

  double get _cartTotal => _cart.values.fold<double>(
    0,
    (runningTotal, item) => runningTotal + (item.quantity * item.price),
  );

  @override
  void initState() {
    super.initState();
    _prepareLocation();
  }

  Future<void> _prepareLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = position);
    } catch (_) {}
  }

  String _distanceLabel(GeoPoint? truckLocation) {
    final user = _currentPosition;
    if (user == null || truckLocation == null) return '--';

    final meters = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      truckLocation.latitude,
      truckLocation.longitude,
    );

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _addToCart(String itemId, String name, double price) {
    setState(() {
      final existing = _cart[itemId];
      if (existing == null) {
        _cart[itemId] = _CartLine(
          itemId: itemId,
          name: name,
          price: price,
          quantity: 1,
        );
      } else {
        _cart[itemId] = existing.copyWith(quantity: existing.quantity + 1);
      }
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      final existing = _cart[itemId];
      if (existing == null) return;
      if (existing.quantity <= 1) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = existing.copyWith(quantity: existing.quantity - 1);
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_placingOrder || _cart.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to place an order.')),
      );
      return;
    }

    setState(() => _placingOrder = true);

    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.vendorId)
          .get();
      final vendorName = (vendorDoc.data()?['businessName'] ?? 'Food Truck')
          .toString();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final customerName =
          (userData['fullName'] ?? user.displayName ?? 'Cravo Customer')
              .toString();

      final items = _cart.values
          .map(
            (line) => {
              'itemId': line.itemId,
              'name': line.name,
              'quantity': line.quantity,
              'price': line.price,
              'lineTotal': line.quantity * line.price,
            },
          )
          .toList();

      final total = _cartTotal;
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
            'vendorId': widget.vendorId,
            'vendorName': vendorName,
            'customerId': user.uid,
            'customerName': customerName,
            'status': 'placed',
            'items': items,
            'totalAmount': total,
            'createdAt': FieldValue.serverTimestamp(),
            'placedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      setState(() => _cart.clear());
      context.pushReplacement('/order-status/${orderRef.id}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to place order right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorStream = FirebaseFirestore.instance
        .collection('vendors')
        .doc(widget.vendorId)
        .snapshots();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          title: const Text('Truck Details'),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: vendorStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load truck details.',
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
                  'Truck not found.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final truckName = (data['businessName'] ?? 'Food Truck').toString();
            final cuisine = (data['cuisineType'] ?? 'Street Food').toString();
            final rating = (data['rating'] as num?)?.toDouble() ?? 4.5;
            final isLive = (data['isLive'] as bool?) ?? false;
            final ownerName = (data['ownerName'] ?? 'Owner').toString();
            final location = data['location'] as GeoPoint?;
            final latLng = location == null
                ? LatLng(13.0827, 80.2707)
                : LatLng(location.latitude, location.longitude);

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF26344B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              truckName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? const Color(0xFF10361F)
                                  : const Color(0xFF3A4250),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isLive ? 'LIVE' : 'OFFLINE',
                              style: TextStyle(
                                color: isLive ? Colors.greenAccent : _subtle,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cuisine,
                        style: const TextStyle(color: _subtle, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.place_outlined,
                            color: _subtle,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _distanceLabel(location),
                            style: const TextStyle(color: _subtle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TabBar(
                    indicatorColor: _accent,
                    labelColor: Colors.white,
                    unselectedLabelColor: _subtle,
                    tabs: [
                      Tab(text: 'Menu'),
                      Tab(text: 'Info'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MenuTab(
                        vendorId: widget.vendorId,
                        onAdd: _addToCart,
                        onRemove: _removeFromCart,
                        cart: _cart,
                      ),
                      _InfoTab(
                        ownerName: ownerName,
                        cuisine: cuisine,
                        rating: rating,
                        distanceLabel: _distanceLabel(location),
                        latLng: latLng,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: const BoxDecoration(
              color: _card,
              boxShadow: [
                BoxShadow(
                  color: Color(0x3A000000),
                  blurRadius: 14,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_cartCount items',
                        style: const TextStyle(color: _subtle, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rs ${_cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _cartTotal > 0 && !_placingOrder
                        ? _placeOrder
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A3142),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _placingOrder
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Place Order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({
    required this.vendorId,
    required this.onAdd,
    required this.onRemove,
    required this.cart,
  });

  final String vendorId;
  final void Function(String id, String name, double price) onAdd;
  final void Function(String id) onRemove;
  final Map<String, _CartLine> cart;

  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('menus')
        .doc(vendorId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load menu.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Menu will be updated soon.',
              style: TextStyle(color: _subtle),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final available = (data['available'] as bool?) ?? true;
            final name = (data['name'] ?? 'Menu Item').toString();
            final desc = (data['description'] ?? 'Freshly prepared').toString();
            final price = (data['price'] as num?)?.toDouble() ?? 0;
            final qty = cart[doc.id]?.quantity ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF26344B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!available)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B4352),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(color: _subtle, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _subtle),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Rs ${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (qty > 0)
                        Row(
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: available ? () => onRemove(doc.id) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: available
                            ? () => onAdd(doc.id, name, price)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.ownerName,
    required this.cuisine,
    required this.rating,
    required this.distanceLabel,
    required this.latLng,
  });

  final String ownerName;
  final String cuisine;
  final double rating;
  final String distanceLabel;
  final LatLng latLng;

  static const _card = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF26344B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Truck Info',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Owner',
                value: ownerName,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.restaurant_outlined,
                label: 'Cuisine',
                value: cuisine,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.star_rounded,
                label: 'Rating',
                value: rating.toStringAsFixed(1),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Distance',
                value: distanceLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 190,
            child: FlutterMap(
              options: MapOptions(initialCenter: latLng, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.cravo',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latLng,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.orange,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFA4ACBE), size: 18),
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(color: Color(0xFFA4ACBE))),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFF2A3142)
              : const Color(0xFF1A56A0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _CartLine {
  const _CartLine({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String itemId;
  final String name;
  final double price;
  final int quantity;

  _CartLine copyWith({int? quantity}) {
    return _CartLine(
      itemId: itemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}
