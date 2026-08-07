import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/presentation/premium_ui.dart';
import 'providers/current_profile_provider.dart';
import 'providers/selected_project_provider.dart';

final companyProjectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return const <Map<String, dynamic>>[];
  }

  final client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> loadWithUpdatedAt() async {
    final rows = await client
        .from('projects')
        .select()
        .eq('company_id', profile.companyId)
        .order('updated_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadWithCreatedAt() async {
    final rows = await client
        .from('projects')
        .select()
        .eq('company_id', profile.companyId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadWithoutOrder() async {
    final rows = await client
        .from('projects')
        .select()
        .eq('company_id', profile.companyId);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  try {
    return await loadWithUpdatedAt();
  } catch (_) {
    try {
      return await loadWithCreatedAt();
    } catch (_) {
      return loadWithoutOrder();
    }
  }
});

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterProjects(List<Map<String, dynamic>> rows) {
    final query = _searchController.text.trim().toLowerCase();

    return rows.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      final name = (row['name'] ?? row['title'] ?? 'Projet').toString();
      final client =
          (row['client_name'] ?? row['client'] ?? '').toString().toLowerCase();
      final location =
          (row['location'] ?? row['address'] ?? row['site_name'] ?? '')
              .toString()
              .toLowerCase();

      bool filterOk;
      switch (_filter) {
        case 'active':
          filterOk = !status.contains('archive');
          break;
        case 'archived':
          filterOk = status.contains('archive');
          break;
        default:
          filterOk = true;
      }

      final textOk = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          client.contains(query) ||
          location.contains(query) ||
          status.contains(query);

      return filterOk && textOk;
    }).toList();
  }

  double _progressOf(Map<String, dynamic> row) {
    final raw = row['completion_percentage'] ??
        row['progress'] ??
        row['completion'] ??
        0;
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;

    if (value > 1) {
      return (value / 100).clamp(0, 1);
    }

    return value.clamp(0, 1);
  }

  String _projectLabel(Map<String, dynamic> row) {
    return (row['name'] ?? row['title'] ?? 'Projet').toString();
  }

  String _clientLabel(Map<String, dynamic> row) {
    return (row['client_name'] ?? row['client'] ?? 'Client non renseigné')
        .toString();
  }

  String _locationLabel(Map<String, dynamic> row) {
    return (row['location'] ?? row['address'] ?? row['site_name'] ?? '-')
        .toString();
  }

  String _dateLabel(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString();
    if (text.length >= 10) {
      return text.substring(0, 10);
    }
    return text;
  }

  Color _statusBg(String value) {
    final colors = context.palette;
    final lower = value.toLowerCase();
    if (lower.contains('archive')) {
      return colors.surfaceAlt;
    }
    if (lower.contains('term') || lower.contains('livr')) {
      return const Color(0xFFEAF7EE);
    }
    return colors.yellowSoft;
  }

  Color _statusFg(String value) {
    final colors = context.palette;
    final lower = value.toLowerCase();
    if (lower.contains('archive')) {
      return colors.textSoft;
    }
    if (lower.contains('term') || lower.contains('livr')) {
      return colors.success;
    }
    return colors.petrol;
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectAsync = ref.watch(selectedProjectProvider);
    final projectsAsync = ref.watch(companyProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
      ),
      body: currentProjectAsync.when(
        data: (currentProject) {
          return projectsAsync.when(
            data: (rows) {
              final filtered = _filterProjects(rows);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PremiumHeroHeader(
                    title: 'Portefeuille chantiers',
                    subtitle: currentProject == null
                        ? 'Vue globale de l’entreprise'
                        : 'Projet courant : ${currentProject.name}',
                    trailing: ElevatedButton.icon(
                      onPressed: () => context.go('/planning'),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Planning'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PremiumSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionHeader(
                          title: 'Filtrer les projets',
                          subtitle: 'Navigation simple pour smartphone',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Recherche',
                            hintText: 'Nom, client, lieu, statut',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 14),
                        PremiumActionRow(
                          children: [
                            FilterChip(
                              selected: _filter == 'all',
                              label: const Text('Tous'),
                              onSelected: (_) =>
                                  setState(() => _filter = 'all'),
                            ),
                            FilterChip(
                              selected: _filter == 'active',
                              label: const Text('Actifs'),
                              onSelected: (_) =>
                                  setState(() => _filter = 'active'),
                            ),
                            FilterChip(
                              selected: _filter == 'archived',
                              label: const Text('Archivés'),
                              onSelected: (_) =>
                                  setState(() => _filter = 'archived'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PremiumSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumSectionHeader(
                          title: 'Chantiers',
                          subtitle: '${filtered.length} résultat(s)',
                        ),
                        const SizedBox(height: 16),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('Aucun projet pour ce filtre.'),
                            ),
                          )
                        else
                          ...filtered.map((row) {
                            final status =
                                (row['status'] ?? 'en cours').toString();
                            final progress = _progressOf(row);
                            final startDate = _dateLabel(row['start_date']);
                            final endDate = _dateLabel(row['end_date']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.palette.surfaceAlt,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: context.palette.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _projectLabel(row),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      PremiumStatusBadge(
                                        label: status,
                                        backgroundColor: _statusBg(status),
                                        foregroundColor: _statusFg(status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  PremiumInfoLine(
                                    label: 'Client',
                                    value: _clientLabel(row),
                                  ),
                                  const SizedBox(height: 10),
                                  PremiumInfoLine(
                                    label: 'Lieu',
                                    value: _locationLabel(row),
                                  ),
                                  const SizedBox(height: 10),
                                  PremiumInfoLine(
                                    label: 'Période',
                                    value: '$startDate → $endDate',
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 12,
                                      backgroundColor: context.palette.border,
                                      color: progress >= 0.8
                                          ? context.palette.success
                                          : context.palette.petrol,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(progress * 100).round()}% d’avancement',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 14),
                                  PremiumActionRow(
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () =>
                                            context.go('/planning'),
                                        icon: const Icon(
                                            Icons.calendar_month_outlined),
                                        label: const Text('Planning'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => context.go('/reports'),
                                        icon: const Icon(
                                            Icons.description_outlined),
                                        label: const Text('Rapports'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            context.go('/documents'),
                                        icon: const Icon(Icons.folder_outlined),
                                        label: const Text('Documents'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => context.go('/achats'),
                                        icon: const Icon(
                                            Icons.shopping_cart_outlined),
                                        label: const Text('Achats'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erreur projets : $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erreur projet courant : $error')),
      ),
    );
  }
}
