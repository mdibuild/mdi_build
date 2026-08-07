import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/supplier.dart';
import 'providers/suppliers_providers.dart';
import 'supplier_form_dialog.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Supplier> _filter(List<Supplier> suppliers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return suppliers;
    }

    return suppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(query) ||
          supplier.contactName.toLowerCase().contains(query) ||
          supplier.email.toLowerCase().contains(query) ||
          supplier.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openForm({Supplier? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SupplierFormDialog(existing: existing),
    );

    if (saved == true) {
      ref.invalidate(activeSuppliersProvider);
      ref.invalidate(archivedSuppliersProvider);
    }
  }

  Future<void> _toggleArchive(Supplier supplier) async {
    await ref.read(suppliersRepositoryProvider).setArchived(
          supplierId: supplier.id,
          archived: !supplier.isArchived,
        );

    ref.invalidate(activeSuppliersProvider);
    ref.invalidate(archivedSuppliersProvider);
  }

  Future<void> _delete(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer fournisseur'),
        content: Text('Supprimer "${supplier.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(suppliersRepositoryProvider).deleteSupplier(supplier.id);

    ref.invalidate(activeSuppliersProvider);
    ref.invalidate(archivedSuppliersProvider);
  }

  Widget _buildList(AsyncValue<List<Supplier>> async, {required bool archivedTab}) {
    return async.when(
      data: (suppliers) {
        final filtered = _filter(suppliers);

        if (filtered.isEmpty) {
          return const Center(child: Text('Aucun fournisseur.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final supplier = filtered[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(supplier.name),
                subtitle: Text([
                  if (supplier.contactName.isNotEmpty) supplier.contactName,
                  if (supplier.phone.isNotEmpty) supplier.phone,
                  if (supplier.email.isNotEmpty) supplier.email,
                ].join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openForm(existing: supplier);
                        break;
                      case 'archive':
                        _toggleArchive(supplier);
                        break;
                      case 'delete':
                        _delete(supplier);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(archivedTab ? 'Désarchiver' : 'Archiver'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur : $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeSuppliersProvider);
    final archivedAsync = ref.watch(archivedSuppliersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fournisseurs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Actifs'),
              Tab(text: 'Archivés'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau fournisseur'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Recherche',
                  hintText: 'Nom, contact, email, téléphone',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildList(activeAsync, archivedTab: false),
                  _buildList(archivedAsync, archivedTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
