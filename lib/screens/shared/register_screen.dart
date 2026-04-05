import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _customerFormKey = GlobalKey<FormState>();
  final _vendorFormKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPasswordController = TextEditingController();
  final _customerConfirmController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _vendorEmailController = TextEditingController();
  final _vendorPasswordController = TextEditingController();

  String _selectedCuisine = 'Indian';
  bool _isLoading = false;
  bool _customerObscure = true;
  bool _vendorObscure = true;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPasswordController.dispose();
    _customerConfirmController.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _vendorEmailController.dispose();
    _vendorPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _subtle),
      prefixIcon: Icon(icon, color: _subtle),
      suffixIcon: suffix,
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F2A3D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }

  Future<void> _registerCustomer() async {
    if (!_customerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _customerEmailController.text.trim(),
            password: _customerPasswordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'fullName': _customerNameController.text.trim(),
            'email': _customerEmailController.text.trim(),
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error during registration.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerVendor() async {
    if (!_vendorFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _vendorEmailController.text.trim(),
            password: _vendorPasswordController.text.trim(),
          );

      GeoPoint location = const GeoPoint(13.0827, 80.2707);
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            final pos = await Geolocator.getCurrentPosition(
              timeLimit: const Duration(seconds: 6),
            );
            location = GeoPoint(pos.latitude, pos.longitude);
          }
        }
      } catch (_) {
        // Keep fallback location if current location cannot be resolved.
      }

      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(credential.user!.uid)
          .set({
            'businessName': _businessNameController.text.trim(),
            'ownerName': _ownerNameController.text.trim(),
            'email': _vendorEmailController.text.trim(),
            'cuisineType': _selectedCuisine,
            'role': 'vendor',
            'isApproved': false,
            'isLive': false,
            'rating': 4.6,
            'location': location,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      context.go('/vendor-home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error during registration.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [_buildCustomerForm(), _buildVendorForm()];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join Cravo and power your street food journey.',
                style: TextStyle(color: _subtle, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF263249)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [_primary, _accent]),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: _subtle,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Customer'),
                    Tab(text: 'Vendor'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 520,
                child: TabBarView(controller: _tabController, children: tabs),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [_primary, _accent]),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_tabController.index == 0) {
                              _registerCustomer();
                            } else {
                              _registerVendor();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: _subtle),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Form(
      key: _customerFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _customerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Full Name',
              icon: Icons.person_outline,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              hint: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Email is required';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPasswordController,
            obscureText: _customerObscure,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _customerObscure = !_customerObscure),
                icon: Icon(
                  _customerObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _subtle,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Password is required';
              if ((value ?? '').length < 6)
                return 'Minimum 6 characters required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerConfirmController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Confirm Password',
              icon: Icons.verified_user_outlined,
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Confirm password';
              if (value != _customerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVendorForm() {
    return Form(
      key: _vendorFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _businessNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Business Name',
              icon: Icons.storefront_outlined,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Business name is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ownerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Owner Name',
              icon: Icons.person_outline,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Owner name is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vendorEmailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              hint: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Email is required';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vendorPasswordController,
            obscureText: _vendorObscure,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              hint: 'Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _vendorObscure = !_vendorObscure),
                icon: Icon(
                  _vendorObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _subtle,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Password is required';
              if ((value ?? '').length < 6)
                return 'Minimum 6 characters required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCuisine,
            style: const TextStyle(color: Colors.white),
            dropdownColor: _card,
            iconEnabledColor: _subtle,
            decoration: _fieldDecoration(
              hint: 'Cuisine Type',
              icon: Icons.restaurant_menu,
            ),
            items: const [
              DropdownMenuItem(value: 'Indian', child: Text('Indian')),
              DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
              DropdownMenuItem(value: 'Fast Food', child: Text('Fast Food')),
              DropdownMenuItem(value: 'Desserts', child: Text('Desserts')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCuisine = value);
            },
          ),
        ],
      ),
    );
  }
}
