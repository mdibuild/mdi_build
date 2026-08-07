import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/supplier.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import 'providers/suppliers_providers.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({super.key, this.existing});

  final Supplier? existing;

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  late final TextEditingController nameController;
  late final TextEditingController contactController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;
  late final TextEditingController taxIdController;
  late final TextEditingController notesController;

  bool _saving = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.existing;
    nameController = TextEditingController(text: supplier?.name ?? '');
    contactController = TextEditingController(text: supplier?.contactName ?? '');
    phoneController = TextEditingController(text: supplier?.phone ?? '');
    emailController = TextEditingController(text: supplier?.email ?? '');
    addressController = TextEditingController(text: supplier?.address ?? '');
    taxIdController = TextEditingController(text: supplier?.taxId ?? '');
    notesController = TextEditingController(text: supplier?.notes ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    taxIdController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du fournisseur est requis.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(suppliersRepositoryProvider);
      final now = DateTime.now();

      if (isEditing) {
        await repository.updateSupplier(
          widget.existing!.copyWith(
            name: name,
            contactName: contactController.text.trim(),
            phone: phoneController.text.trim(),
            email: emailController.text.trim(),
            address: addressController.text.trim(),
            taxId: taxIdController.text.trim(),
            notes: notesController.text.trim(),
            updatedAt: now,
          ),
        );
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        if (profile == null) {
          throw Exception('Profil utilisateur introuvable.');
        }

        await repository.createSupplier(
          Supplier(
            id: '',
            companyId: profile.companyId,
            name: name,
            contactName: contactController.text.trim(),
            phone: phoneController.text.trim(),
            email: emailController.text.trim(),
            address: addressController.text.trim(),
            taxId: taxIdController.text.trim(),
            notes: notesController.text.trim(),
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      ref.invalidate(activeSuppliersProvider);
      ref.invalidate(archivedSuppliersProvider);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Modifier fournisseur' : 'Nouveau fournisseur',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom / raison sociale'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxIdController,
                  decoration: const InputDecoration(labelText: 'ICE / identifiant fiscal'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
