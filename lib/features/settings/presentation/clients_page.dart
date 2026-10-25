import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/client.dart';
import '../../../core/enums/entity_type.dart';
import '../../../shared/presentation/module_filters.dart';
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
  String _entityFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Client> _filter(List<Client> clients) {
    final query = _searchController.text.trim().toLowerCase();
    return clients.where((client) {
      final typeMatch =
          _entityFilter == 'all' || client.entityType.dbValue == _entityFilter;
      final textMatch = client.name.toLowerCase().contains(query) ||
          client.contactName.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query) ||
          client.address.toLowerCase().contains(query);
      return typeMatch && textMatch;
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer client'),
        content: Text('Supprimer "${client.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: PremiumButtonStyles.destructive(context),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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

  Widget _buildList(AsyncValue<List<Client>> async,
      {required bool archivedTab}) {
    return async.when(
      data: (clients) {
        final filtered = _filter(clients);

        if (filtered.isEmpty) {
          return const Center(child: Text('Aucun client pour ces filtres.'));
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
                    const PopupMenuItem(
                        value: 'delete', child: Text('Supprimer')),
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
      child: ProjectModuleScaffold(
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
        body: AdaptiveHeaderColumn(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ModuleFilterBar(
                searchQuery: _searchController.text,
                searchHint: 'Nom, contact, email, téléphone…',
                onSearchChanged: (value) =>
                    setState(() => _searchController.text = value),
                filters: [
                  ModuleFilterDropdown<String>(
                    value: _entityFilter,
                    label: 'Type',
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('Tous les types')),
                      for (final type in EntityType.values)
                        DropdownMenuItem(
                            value: type.dbValue, child: Text(type.label)),
                    ],
                    onChanged: (value) =>
                        setState(() => _entityFilter = value ?? 'all'),
                  ),
                ],
                onReset: () => setState(() {
                  _searchController.clear();
                  _entityFilter = 'all';
                }),
                resultLabel:
                    '${_filter(activeAsync.value ?? []).length} actif(s) · '
                    '${_filter(archivedAsync.value ?? []).length} archivé(s)',
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
