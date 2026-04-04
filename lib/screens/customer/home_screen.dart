import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'customer_orders_tab.dart';
import 'customer_profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  void _openTruck(String vendorId) {
    context.push('/truck-detail/$vendorId');
  }

  void _openOrder(String orderId) {
    context.push('/order-status/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedTab == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedTab != 0) {
          setState(() => _selectedTab = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1E),
        body: IndexedStack(
          index: _selectedTab,
          children: [
            _CustomerHomeMapTab(onOpenTruck: _openTruck),
            CustomerOrdersTab(
              onOpenOrder: _openOrder,
              onBrowseTrucks: () => setState(() => _selectedTab = 0),
            ),
            CustomerProfileTab(
              onBrowseTrucks: () => setState(() => _selectedTab = 0),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) {
            setState(() => _selectedTab = index);
          },
          backgroundColor: const Color(0xFF111827),
          indicatorColor: const Color(0xFF1A56A0),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHomeMapTab extends StatefulWidget {
  const _CustomerHomeMapTab({required this.onOpenTruck});

  final ValueChanged<String> onOpenTruck;

  @override
  State<_CustomerHomeMapTab> createState() => _CustomerHomeMapTabState();
}

class _CustomerHomeMapTabState extends State<_CustomerHomeMapTab> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  bool _locationReady = false;
  String? _selectedCuisine;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  void initState() {
    super.initState();
    _prepareLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      setState(() {
        _currentPosition = position;
        _locationReady = true;
      });
    } catch (_) {}
  }

  Future<void> _recenterToUser() async {
    if (_currentPosition == null) {
      await _prepareLocation();
    }

    final current = _currentPosition;
    if (current == null) return;

    _mapController.move(LatLng(current.latitude, current.longitude), 15);
  }

  String _distanceLabel(GeoPoint? point) {
    final user = _currentPosition;
    if (user == null || point == null) return '--';

    final meters = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      point.latitude,
      point.longitude,
    );

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openFilterSheet(List<String> cuisines) async {
    String? tempCuisine = _selectedCuisine;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Trucks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempCuisine == null,
                        selectedColor: _primary,
                        labelStyle: TextStyle(
                          color: tempCuisine == null ? Colors.white : _subtle,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempCuisine = null),
                      ),
                      ...cuisines.map((cuisine) {
                        final selected = tempCuisine == cuisine;
                        return ChoiceChip(
                          label: Text(cuisine),
                          selected: selected,
                          selectedColor: _primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : _subtle,
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              tempCuisine = selected ? null : cuisine;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedCuisine = tempCuisine);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .where('isLive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final cuisines =
            allDocs
                .map((doc) => (doc.data()['cuisineType'] ?? '').toString())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        final search = _searchController.text.trim().toLowerCase();
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data();
          final loc = data['location'];
          if (loc is! GeoPoint) return false;

          final name = (data['businessName'] ?? '').toString().toLowerCase();
          final cuisine = (data['cuisineType'] ?? '').toString();

          final matchesSearch =
              search.isEmpty ||
              name.contains(search) ||
              cuisine.toLowerCase().contains(search);
          final matchesCuisine =
              _selectedCuisine == null || cuisine == _selectedCuisine;

          return matchesSearch && matchesCuisine;
        }).toList();

        final markers = filteredDocs.map((doc) {
          final data = doc.data();
          final location = data['location'] as GeoPoint;

          return Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => widget.onOpenTruck(doc.id),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
            ),
          );
        }).toList();

        final center = _currentPosition == null
            ? LatLng(13.0827, 80.2707)
            : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _locationReady ? 14.5 : 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.cravo',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF26344B)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search trucks or cuisines',
                            hintStyle: TextStyle(color: _subtle),
                            prefixIcon: Icon(Icons.search, color: _subtle),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26344B)),
                      ),
                      child: IconButton(
                        tooltip: 'Filter',
                        onPressed: () => _openFilterSheet(cuisines),
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DraggableScrollableSheet(
              minChildSize: 0.17,
              initialChildSize: 0.25,
              maxChildSize: 0.45,
              builder: (context, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x50000000),
                        blurRadius: 20,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF32425A),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Nearby Food Trucks',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${filteredDocs.length} live',
                            style: const TextStyle(color: _subtle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filteredDocs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No matching trucks nearby. Try adjusting filters.',
                            style: TextStyle(color: _subtle),
                          ),
                        )
                      else
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filteredDocs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data();
                              final name =
                                  (data['businessName'] ?? 'Food Truck')
                                      .toString();
                              final cuisine =
                                  (data['cuisineType'] ?? 'Street Food')
                                      .toString();
                              final rating =
                                  (data['rating'] as num?)?.toDouble() ?? 4.5;
                              final location = data['location'] as GeoPoint?;

                              return GestureDetector(
                                onTap: () => widget.onOpenTruck(doc.id),
                                child: Container(
                                  width: 250,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _card,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF26344B),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10361F),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'LIVE',
                                              style: TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        cuisine,
                                        style: const TextStyle(color: _subtle),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.place_outlined,
                                            color: _subtle,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _distanceLabel(location),
                                            style: const TextStyle(
                                              color: _subtle,
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 190,
              child: FloatingActionButton.small(
                heroTag: 'my-location-btn',
                backgroundColor: _primary,
                onPressed: _recenterToUser,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
