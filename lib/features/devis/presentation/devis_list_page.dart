import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/project_quote.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'devis_page.dart';
import 'providers/devis_providers.dart';

class DevisListPage extends ConsumerWidget {
  const DevisListPage({super.key});

  Future<void> _openQuote(
    BuildContext context,
    WidgetRef ref, {
    ProjectQuote? quote,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DevisPage(quote: quote)),
    );
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

    await ref.read(devisRepositoryProvider).updateQuote(
          quote.copyWith(status: newStatus),
        );
    ref.invalidate(projectQuotesProvider(quote.projectId));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${quote.title} : ${_statusLabel(newStatus)}')),
    );
  }

  Future<void> _deleteQuote(
    BuildContext context,
    WidgetRef ref,
    ProjectQuote quote,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le devis'),
        content: Text(
          'Supprimer "${quote.title}" ? Cette action est définitive.',
        ),
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

    await ref.read(devisRepositoryProvider).deleteQuote(quote.id);
    ref.invalidate(projectQuotesProvider(quote.projectId));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devis supprimé.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
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
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PremiumHeroHeader(
                    title: 'Devis',
                    subtitle: 'Projet courant : ${project.name}',
                    trailing: FilledButton.icon(
                      onPressed: () => _openQuote(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau devis'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (quotes.isEmpty)
                    const PremiumSurfaceCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Aucun devis pour ce projet.'),
                        ),
                      ),
                    )
                  else
                    ...quotes.map(
                      (quote) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumSurfaceCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      quote.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Changer le statut',
                                    onSelected: (value) => _changeStatus(
                                        context, ref, quote, value),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'brouillon',
                                        child: Text('Brouillon'),
                                      ),
                                      PopupMenuItem(
                                        value: 'envoye',
                                        child: Text('Envoyé'),
                                      ),
                                      PopupMenuItem(
                                        value: 'signe',
                                        child: Text('Signé'),
                                      ),
                                      PopupMenuItem(
                                        value: 'annule',
                                        child: Text('Annulé'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text('Archivé'),
                                      ),
                                    ],
                                    child: PremiumStatusBadge(
                                      label: _statusLabel(quote.status),
                                      backgroundColor: _statusColor(
                                              context.palette, quote.status)
                                          .withValues(alpha: 0.14),
                                      foregroundColor: _statusColor(
                                          context.palette, quote.status),
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
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _openQuote(context, ref, quote: quote),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Ouvrir'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _deleteQuote(context, ref, quote),
                                    icon: Icon(Icons.delete_outline,
                                        color: context.palette.danger),
                                    label: Text(
                                      'Supprimer',
                                      style: TextStyle(
                                          color: context.palette.danger),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: context.palette.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
