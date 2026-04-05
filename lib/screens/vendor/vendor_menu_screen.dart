import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  final String? vendorId = FirebaseAuth.instance.currentUser?.uid;

  static const _bg = Color(0xFF0A0F1E);
  static const _accent = Color(0xFF4DA3FF);

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
    return 'Unable to load menu items.';
  }

  @override
  Widget build(BuildContext context) {
    if (vendorId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1E),
        body: Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('My Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendor-home'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('menus')
            .doc(vendorId)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4DA3FF)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                _friendlyError(snapshot.error!),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No menu items yet',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first item to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddItemSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DA3FF),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final item = doc.data() as Map<String, dynamic>;
              return _buildMenuItemCard(doc, item);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMenuItemCard(DocumentSnapshot doc, Map<String, dynamic> item) {
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade900,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text("Are you sure you want to delete '${item['name']}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await doc.reference.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("'${item['name']}' deleted successfully")),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
          }
        }
      },
      child: Card(
        color: const Color(0xFF111827),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade800),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Rs ${(item['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4DA3FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: (item['available'] as bool?) ?? true,
                    onChanged: (bool value) async {
                      try {
                        await doc.reference.update({'available': value});
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating status: $e'),
                            ),
                          );
                        }
                      }
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
              if ((item['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item['description'].toString(),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
              if ((item['category'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A52),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['category'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _AddItemForm(vendorId: vendorId!),
      ),
    );
  }
}

class _AddItemForm extends StatefulWidget {
  final String vendorId;
  const _AddItemForm({required this.vendorId});

  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Main Course';
  bool _available = true;
  bool _saving = false;

  static const _categories = [
    'Main Course',
    'Snacks',
    'Beverages',
    'Desserts',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('menus')
          .doc(widget.vendorId)
          .collection('items')
          .add({
            'name': _nameController.text.trim(),
            'price': double.tryParse(_priceController.text.trim()) ?? 0,
            'description': _descController.text.trim(),
            'category': _category,
            'available': _available,
            'vendorId': widget.vendorId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving item: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Item',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Item Name'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Price (Rs)'),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Price is required';
              if (double.tryParse(v!.trim()) == null) {
                return 'Enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: _inputDecoration('Description (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: const Color(0xFF111827),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Category'),
            items: _AddItemFormState._categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'Main Course'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Available', style: TextStyle(color: Colors.white)),
              const Spacer(),
              Switch(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                activeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFA4ACBE)),
      filled: true,
      fillColor: const Color(0xFF0A0F1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF26344B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF26344B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4DA3FF)),
      ),
    );
  }
}
