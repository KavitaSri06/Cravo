import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_role_service.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  final String? _vendorId = FirebaseAuth.instance.currentUser?.uid;
  bool _migrationTriggered = false;
  bool _isVendorApproved = true;

  static const _bg = Color(0xFF0A0F1E);
  static const _card = Color(0xFF111827);
  static const _primary = Color(0xFF1A56A0);
  static const _accent = Color(0xFF4DA3FF);
  static const _subtle = Color(0xFFA4ACBE);

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkVendorApproved();
    _ensureMenuRootDoc();
    _migrateLegacyAvailabilityField();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>>? _itemsRef() {
    if (_vendorId == null) return null;
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(_vendorId)
        .collection('items');
  }

  Future<void> _checkVendorApproved() async {
    if (_vendorId == null) return;

    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(_vendorId)
          .get();
      if (!mounted) return;

      setState(() {
        _isVendorApproved = (vendorDoc.data()?['isApproved'] as bool?) ?? false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVendorApproved = true);
    }
  }

  Future<void> _ensureMenuRootDoc() async {
    if (_vendorId == null) return;

    final rootRef = FirebaseFirestore.instance
        .collection('menus')
        .doc(_vendorId);
    try {
      await rootRef.set({
        'vendorId': _vendorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // If rules block this, item writes will show detailed error messages.
    }
  }

  Future<void> _migrateLegacyAvailabilityField() async {
    if (_migrationTriggered) return;
    _migrationTriggered = true;

    final ref = _itemsRef();
    if (ref == null) return;

    try {
      final snapshot = await ref.get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      var updates = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hasLegacy = data.containsKey('available');
        final hasNew = data.containsKey('isAvailable');

        if (hasLegacy && !hasNew) {
          final legacyValue = (data['available'] as bool?) ?? true;
          batch.update(doc.reference, {
            'isAvailable': legacyValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updates++;
        }
      }

      if (updates == 0) return;
      await batch.commit();
    } catch (_) {
      // Silent fail: legacy fallback read logic still supports old documents.
    }
  }

  Future<void> _updateAvailability(String itemId, bool value) async {
    final ref = _itemsRef();
    if (ref == null) return;

    try {
      await ref.doc(itemId).update({
        'isAvailable': value,
        'available': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${e.code}: ${e.message ?? 'Unable to update availability.'}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update availability.')),
      );
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final ref = _itemsRef();
    if (ref == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _card,
          title: const Text(
            'Delete item',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to remove this menu item?',
            style: TextStyle(color: _subtle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: _subtle)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.doc(itemId).delete();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete item.')));
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

  Future<void> _saveItem({String? itemId}) async {
    final ref = _itemsRef();
    if (ref == null) return;

    if (!_isVendorApproved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vendor account pending approval. You cannot add menu items yet.',
          ),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final normalizedPrice = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(normalizedPrice) ?? 0;

    if (name.isEmpty || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid item details.')),
      );
      return;
    }

    await _ensureMenuRootDoc();

    final payload = <String, dynamic>{
      'name': name,
      'price': price,
      'isAvailable': _isAvailable,
      'available': _isAvailable,
      'vendorId': _vendorId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (itemId == null) {
        await ref.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await ref.doc(itemId).update(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${e.code}: ${e.message ?? (itemId == null ? 'Unable to add menu item.' : 'Unable to update menu item.')}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            itemId == null
                ? 'Unable to add menu item.'
                : 'Unable to update menu item.',
          ),
        ),
      );
    }
  }

  void _openItemDialog({DocumentSnapshot<Map<String, dynamic>>? itemDoc}) {
    final isEdit = itemDoc != null;
    final data = itemDoc?.data() ?? {};

    _nameController.clear();
    _priceController.clear();
    _isAvailable = true;

    if (isEdit) {
      _nameController.text = (data['name'] ?? '').toString();
      _priceController.text = ((data['price'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(0);
      _isAvailable =
          (data['isAvailable'] as bool?) ??
          (data['available'] as bool?) ??
          true;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _card,
              title: Text(
                isEdit ? 'Edit Menu Item' : 'Add Menu Item',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Item Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Price'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _isAvailable,
                      activeColor: _accent,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Available',
                        style: TextStyle(color: Colors.white),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => _isAvailable = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: _subtle)),
                ),
                ElevatedButton(
                  onPressed: () => _saveItem(itemId: itemDoc?.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _subtle),
      filled: true,
      fillColor: const Color(0xFF151F32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF26344B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _itemsRef();
    if (ref == null) {
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
          title: const Text('Vendor Menu'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final message = snapshot.error is FirebaseException
                  ? '${(snapshot.error as FirebaseException).code}: ${(snapshot.error as FirebaseException).message ?? 'Unable to load menu items.'}'
                  : 'Unable to load menu items.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.restaurant_menu_outlined,
                      color: _subtle,
                      size: 72,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No menu items yet. Tap + to add your first dish.',
                      style: TextStyle(color: _subtle),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (!_isVendorApproved)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: Colors.redAccent.withValues(alpha: 0.18),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vendor account pending approval. Menu write actions may be blocked.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final name = (data['name'] ?? 'Street Bite').toString();
                      final price = (data['price'] as num?)?.toDouble() ?? 0;
                      final isAvailable =
                          (data['isAvailable'] as bool?) ??
                          (data['available'] as bool?) ??
                          true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF26344B)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rs ${price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: _accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isAvailable,
                              activeColor: _accent,
                              onChanged: (value) =>
                                  _updateAvailability(doc.id, value),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              color: _card,
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openItemDialog(itemDoc: doc);
                                } else if (value == 'delete') {
                                  _deleteItem(doc.id);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isVendorApproved ? _openItemDialog : null,
          backgroundColor: _primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
