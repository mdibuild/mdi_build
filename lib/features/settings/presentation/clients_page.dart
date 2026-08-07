import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/client.dart';
import '../../../shared/presentation/premium_ui.dart';
import 'client_form_dialog.dart';
import 'providers/clients_providers.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Client> _filter(List<Client> clients) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return clients;
    }

    return clients.where((client) {
      return client.name.toLowerCase().contains(query) ||
          client.contactName.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openForm({Client? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(existing: existing),
    );

    if (saved == true) {
      ref.invalidate(activeClientsProvider);
      ref.invalidate(archivedClientsProvider);
    }
  }

  Future<void> _toggleArchive(Client client) async {
    await ref.read(clientsRepositoryProvider).setArchived(
          clientId: client.id,
          archived: !client.isArchived,
        );

    ref.invalidate(activeClientsProvider);
    ref.invalidate(archivedClientsProvider);
  }

  Future<void> _delete(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer client'),
        content: Text('Supprimer "${client.name}" ?'),
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

    await ref.read(clientsRepositoryProvider).deleteClient(client.id);

    ref.invalidate(activeClientsProvider);
    ref.invalidate(archivedClientsProvider);
  }

  Widget _buildList(AsyncValue<List<Client>> async, {required bool archivedTab}) {
    return async.when(
      data: (clients) {
        final filtered = _filter(clients);

        if (filtered.isEmpty) {
          return const Center(child: Text('Aucun client.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final client = filtered[index];

            return PremiumSurfaceCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(client.name),
                subtitle: Text([
                  if (client.contactName.isNotEmpty) client.contactName,
                  if (client.phone.isNotEmpty) client.phone,
                  if (client.email.isNotEmpty) client.email,
                ].join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openForm(existing: client);
                        break;
                      case 'archive':
                        _toggleArchive(client);
                        break;
                      case 'delete':
                        _delete(client);
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
    final activeAsync = ref.watch(activeClientsProvider);
    final archivedAsync = ref.watch(archivedClientsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clients'),
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
          label: const Text('Nouveau client'),
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
