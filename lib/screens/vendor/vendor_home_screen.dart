// FULL FIXED VERSION

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_role_service.dart';

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
  int _bottomNavIndex = 0;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadInitialLiveState();
  }

  Future<void> _loadInitialLiveState() async {
    if (_vendorId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .get();

      final data = doc.data() ?? {};
      final live = (data['isLive'] as bool?) ?? false;

      setState(() => _isLive = live);

      if (live) {
        _pulseController.repeat(reverse: true);
        _startLocationBroadcast();
      }
    } catch (e) {
      debugPrint("Load live state error: $e");
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// 🔥 FIXED GO LIVE FUNCTION
  Future<void> _setLiveStatus(bool live) async {
    if (_vendorId == null) return;

    setState(() => _isLiveLoading = true);

    try {
      if (live) {
        /// Try location but don't fail if it errors
        try {
          await _pushCurrentLocation();
        } catch (e) {
          debugPrint("Location error: $e");
        }

        await FirebaseFirestore.instance
            .collection('vendors')
            .doc(_vendorId)
            .set({
          'isLive': true,
          'lastLiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _startLocationBroadcast();
        _pulseController.repeat(reverse: true);
      } else {
        _locationTimer?.cancel();

        await FirebaseFirestore.instance
            .collection('vendors')
            .doc(_vendorId)
            .set({
          'isLive': false,
          'lastOfflineAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _pulseController.stop();
      }

      if (!mounted) return;
      setState(() => _isLive = live);
    } catch (e) {
      debugPrint("Live toggle error: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update live status')),
      );
    } finally {
      if (mounted) setState(() => _isLiveLoading = false);
    }
  }

  Future<void> _pushCurrentLocation() async {
    if (_vendorId == null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .set({
        'location': GeoPoint(position.latitude, position.longitude),
        'isLive': true,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Push location error: $e");
    }
  }

  void _startLocationBroadcast() {
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _pushCurrentLocation();
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    AuthRoleService.clearAllCache();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_vendorId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text('Please login as a vendor',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Text(
            _isLive ? "🟢 LIVE - Customers can see you" : "🔴 Offline",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (index) {
          setState(() => _bottomNavIndex = index);

          if (index == 1) context.go('/vendor-orders');
          if (index == 2) context.go('/vendor-menu');
          if (index == 3) context.go('/vendor-profile'); // ✅ FIXED
        },
        backgroundColor: _card,
        indicatorColor: _primary,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: _isLive ? Colors.red : Colors.green,
        onPressed: () => _setLiveStatus(!_isLive),
        child: Icon(_isLive ? Icons.power_settings_new : Icons.wifi),
      ),
    );
  }
}