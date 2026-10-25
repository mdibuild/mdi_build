import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/project_quote.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/project_selector_card.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/devis_providers.dart';

class DevisListPage extends ConsumerStatefulWidget {
  const DevisListPage({super.key});

  @override
  ConsumerState<DevisListPage> createState() => _DevisListPageState();
}

class _DevisListPageState extends ConsumerState<DevisListPage> {
  String _searchQuery = '';
  String _status = 'all';
  String _mode = 'all';

  List<ProjectQuote> _filterQuotes(List<ProjectQuote> quotes) {
    final query = _searchQuery.trim().toLowerCase();
    return quotes.where((quote) {
      final text =
          '${quote.title} ${_statusLabel(quote.status)} ${_modeLabel(quote.mode)}';
      return (query.isEmpty || text.toLowerCase().contains(query)) &&
          (_status == 'all' || quote.status == _status) &&
          (_mode == 'all' || quote.mode == _mode);
    }).toList();
  }

  void _openQuote(
    BuildContext context, {
    ProjectQuote? quote,
  }) {
    if (quote == null) {
      context.push('/devis/new');
    } else {
      context.push('/devis/${quote.id}/edit');
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    ProjectQuote quote,
    String newStatus,
  ) async {
    if (newStatus == quote.status) {
      return;
    }

    try {
      final repository = ref.read(devisRepositoryProvider);
      final items = await repository.fetchQuoteItems(quote.id);
      await repository.updateQuote(
        quote.copyWith(status: newStatus),
        items,
      );
      ref.invalidate(projectQuotesProvider(quote.projectId));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${quote.title} : ${_statusLabel(newStatus)}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur statut : $error')),
      );
    }
  }

  Future<void> _deleteQuote(
    BuildContext context,
    WidgetRef ref,
    ProjectQuote quote,
  ) async {
    try {
      await ref.read(devisRepositoryProvider).deleteQuote(quote.id);
      ref.invalidate(projectQuotesProvider(quote.projectId));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devis supprimé.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);

    return ProjectModuleScaffold(
      appBar: AppBar(title: const Text('Devis')),
      body: selectedProjectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Choisis un projet pour voir ses devis.'),
              ),
            );
          }

          final quotesAsync = ref.watch(projectQuotesProvider(project.id));

          return quotesAsync.when(
            data: (quotes) {
              final filtered = _filterQuotes(quotes);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PremiumHeroHeader(
                    title: 'Devis',
                    subtitle: 'Projet courant : ${project.name}',
                    trailing: FilledButton.icon(
                      onPressed: () => _openQuote(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau devis'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProjectSelectorCard(
                    currentProjectId: project.id,
                    labelText: 'Projet affecté',
                  ),
                  const SizedBox(height: 16),
                  ModuleFilterBar(
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    searchHint: 'Titre, statut, mode du devis…',
                    resultLabel:
                        '${filtered.length} devis sur ${quotes.length}',
                    onReset: () => setState(() {
                      _searchQuery = '';
                      _status = 'all';
                      _mode = 'all';
                    }),
                    filters: [
                      ModuleFilterDropdown<String>(
                        value: _status,
                        label: 'Statut',
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Tous les statuts')),
                          for (final status in [
                            'brouillon',
                            'envoye',
                            'signe',
                            'annule',
                            'archive'
                          ])
                            DropdownMenuItem(
                                value: status,
                                child: Text(_statusLabel(status))),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? 'all'),
                      ),
                      ModuleFilterDropdown<String>(
                        value: _mode,
                        label: 'Mode',
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Tous les modes')),
                          for (final mode in ['piece', 'corps_etat', 'mixte'])
                            DropdownMenuItem(
                                value: mode, child: Text(_modeLabel(mode))),
                        ],
                        onChanged: (value) =>
                            setState(() => _mode = value ?? 'all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    PremiumSurfaceCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(quotes.isEmpty
                              ? 'Aucun devis pour ce projet.'
                              : 'Aucun devis ne correspond aux filtres.'),
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (quote) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuoteCard(
                          key: ValueKey(quote.id),
                          quote: quote,
                          onOpen: () => _openQuote(context, quote: quote),
                          onChangeStatus: (status) =>
                              _changeStatus(context, ref, quote, status),
                          onDelete: () => _deleteQuote(context, ref, quote),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erreur devis : $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur projet : $error')),
      ),
    );
  }
}

class _QuoteCard extends StatefulWidget {
  const _QuoteCard({
    super.key,
    required this.quote,
    required this.onOpen,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final ProjectQuote quote;
  final VoidCallback onOpen;
  final ValueChanged<String> onChangeStatus;
  final Future<void> Function() onDelete;

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> {
  bool _confirmingDelete = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;

    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Changer le statut',
                onSelected: widget.onChangeStatus,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'brouillon', child: Text('Brouillon')),
                  PopupMenuItem(value: 'envoye', child: Text('Envoyé')),
                  PopupMenuItem(value: 'signe', child: Text('Signé')),
                  PopupMenuItem(value: 'annule', child: Text('Annulé')),
                  PopupMenuItem(value: 'archive', child: Text('Archivé')),
                ],
                child: PremiumStatusBadge(
                  label: _statusLabel(quote.status),
                  backgroundColor: _statusColor(context.palette, quote.status)
                      .withValues(alpha: 0.14),
                  foregroundColor: _statusColor(context.palette, quote.status),
                  icon: Icons.expand_more,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _modeLabel(quote.mode),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (_confirmingDelete)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Supprimer définitivement ce devis ?',
                  style: TextStyle(
                    color: context.palette.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _deleting
                      ? null
                      : () async {
                          setState(() => _deleting = true);
                          await widget.onDelete();
                          if (mounted) {
                            setState(() {
                              _deleting = false;
                              _confirmingDelete = false;
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.palette.danger,
                  ),
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(_deleting ? 'Suppression...' : 'Oui, supprimer'),
                ),
                TextButton(
                  onPressed: _deleting
                      ? null
                      : () => setState(() => _confirmingDelete = false),
                  child: const Text('Annuler'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ouvrir'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _confirmingDelete = true),
                  icon:
                      Icon(Icons.delete_outline, color: context.palette.danger),
                  label: Text(
                    'Supprimer',
                    style: TextStyle(color: context.palette.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.palette.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _modeLabel(String value) {
  switch (value) {
    case 'piece':
      return 'Par pièce';
    case 'corps_etat':
      return 'Par corps d’état';
    case 'mixte':
      return 'Mixte';
    default:
      return value;
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'brouillon':
      return 'Brouillon';
    case 'envoye':
      return 'Envoyé';
    case 'signe':
      return 'Signé';
    case 'annule':
      return 'Annulé';
    case 'archive':
      return 'Archivé';
    default:
      return value;
  }
}

Color _statusColor(AppPaletteColors colors, String value) {
  switch (value) {
    case 'brouillon':
      return colors.textSoft;
    case 'envoye':
      return colors.info;
    case 'signe':
      return colors.success;
    case 'annule':
      return colors.danger;
    case 'archive':
      return colors.purple;
    default:
      return colors.petrol;
  }
}
