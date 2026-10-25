import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/enums/record_status.dart';
import '../../../core/models/project.dart';
import '../../../core/providers/module_refresh_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../../shared/presentation/premium_ui.dart';
import 'providers/current_profile_provider.dart';
import 'providers/projects_providers.dart';
import 'providers/selected_project_provider.dart';
import '../../../shared/presentation/party_pickers.dart';

final companyProjectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
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
  String _searchQuery = '';
  String _filter = 'all';
  bool _currentOnly = false;
  String? _selectingProjectId;

  List<Map<String, dynamic>> _filterProjects(List<Map<String, dynamic>> rows) {
    final query = _searchQuery.trim().toLowerCase();
    final currentId = ref.read(selectedProjectProvider).asData?.value?.id;

    return rows.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      final name = (row['name'] ?? row['title'] ?? 'Projet').toString();
      final client =
          (row['client_name'] ?? row['client'] ?? '').toString().toLowerCase();
      final location =
          (row['location'] ?? row['address'] ?? row['site_name'] ?? '')
              .toString()
              .toLowerCase();

      final filterOk = _filter == 'all' || status == _filter;

      final textOk = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          client.contains(query) ||
          location.contains(query) ||
          status.contains(query);

      return filterOk && textOk && (!_currentOnly || row['id'] == currentId);
    }).toList();
  }

  Future<void> _selectProject(Map<String, dynamic> row, {String? route}) async {
    final projectId = row['id'] as String;
    setState(() => _selectingProjectId = projectId);
    try {
      await ref
          .read(selectedProjectIdProvider.notifier)
          .setProjectId(projectId);
      await ref.read(selectedProjectProvider.future);
      if (!mounted) return;
      if (route != null) {
        context.go(route);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${_projectLabel(row)} sélectionné pour le travail.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sélection impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _selectingProjectId = null);
    }
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

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: Text(
          'Supprimer "${_projectLabel(row)}" ? Cette action est définitive.',
        ),
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

    try {
      await ref
          .read(projectsRepositoryProvider)
          .deleteProject(row['id'] as String);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : $error')),
        );
      }
      return;
    }
    ref.invalidate(companyProjectsProvider);
    ref.invalidate(projectsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Projet supprimé.')),
    );
  }

  Future<void> _changeProjectStatus(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
    RecordStatus newStatus,
  ) async {
    final project = Project.fromMap(row);
    if (newStatus == project.status) {
      return;
    }

    await ref
        .read(projectsRepositoryProvider)
        .updateProject(project.copyWith(status: newStatus));
    ref.invalidate(companyProjectsProvider);
    ref.invalidate(projectsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${project.name} : ${newStatus.label}')),
    );
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

    return ProjectModuleScaffold(
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
                    trailing: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.push('/projects/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Nouveau projet'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/planning'),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Planning'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModuleFilterBar(
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    searchHint: 'Nom, client, lieu, statut',
                    resultLabel:
                        '${filtered.length} projet(s) sur ${rows.length}',
                    onReset: () => setState(() {
                      _searchQuery = '';
                      _filter = 'all';
                      _currentOnly = false;
                    }),
                    filters: [
                      ModuleFilterDropdown<String>(
                        value: _filter,
                        label: 'Statut',
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Tous les statuts')),
                          for (final status in RecordStatus.values)
                            DropdownMenuItem(
                                value: status.dbValue,
                                child: Text(status.label)),
                        ],
                        onChanged: (value) =>
                            setState(() => _filter = value ?? 'all'),
                      ),
                      FilterChip(
                        selected: _currentOnly,
                        label: const Text('Projet courant'),
                        onSelected: (value) =>
                            setState(() => _currentOnly = value),
                      ),
                    ],
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
                            final isCurrent = currentProject?.id == row['id'];
                            final selecting = _selectingProjectId != null;

                            return Container(
                              key: ValueKey(row['id']),
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.palette.surfaceAlt,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isCurrent
                                      ? context.palette.petrol
                                      : context.palette.border,
                                  width: isCurrent ? 2 : 1,
                                ),
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
                                      IconButton(
                                        tooltip: 'Modifier',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => context.push(
                                          '/projects/new',
                                          extra: Project.fromMap(row),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: context.palette.danger,
                                        ),
                                        onPressed: () =>
                                            _deleteProject(context, ref, row),
                                      ),
                                      PopupMenuButton<RecordStatus>(
                                        tooltip: 'Changer le statut',
                                        onSelected: (value) =>
                                            _changeProjectStatus(
                                                context, ref, row, value),
                                        itemBuilder: (context) => [
                                          for (final value
                                              in RecordStatus.values)
                                            PopupMenuItem(
                                              value: value,
                                              child: Text(value.label),
                                            ),
                                        ],
                                        child: PremiumStatusBadge(
                                          label: status,
                                          backgroundColor: _statusBg(status),
                                          foregroundColor: _statusFg(status),
                                          icon: Icons.expand_more,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (isCurrent) ...[
                                    Chip(
                                      avatar: Icon(Icons.check_circle_outline,
                                          color: context.palette.petrol,
                                          size: 18),
                                      label: const Text('Projet courant'),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  PremiumInfoLine(
                                    label: 'Client',
                                    value: _clientLabel(row),
                                  ),
                                  if (row['client_id'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: PartyContactChips.client(
                                          row['client_id'].toString()),
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
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/dashboard'),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Ouvrir le chantier'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting || isCurrent
                                            ? null
                                            : () => _selectProject(row),
                                        icon: const Icon(
                                            Icons.check_circle_outline),
                                        label: Text(isCurrent
                                            ? 'Projet sélectionné'
                                            : 'Choisir pour travailler'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/planning'),
                                        icon: const Icon(
                                            Icons.calendar_month_outlined),
                                        label: const Text('Planning'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/reports'),
                                        icon: const Icon(
                                            Icons.description_outlined),
                                        label: const Text('Rapports'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/documents'),
                                        icon: const Icon(Icons.folder_outlined),
                                        label: const Text('Documents'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/achats'),
                                        icon: const Icon(
                                            Icons.shopping_cart_outlined),
                                        label: const Text('Achats'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/metrage'),
                                        icon: const Icon(
                                            Icons.straighten_outlined),
                                        label: const Text('Métré'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/quantitatif'),
                                        icon: const Icon(
                                            Icons.table_chart_outlined),
                                        label: const Text('Quantitatif'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: selecting
                                            ? null
                                            : () => _selectProject(row,
                                                route: '/devis'),
                                        icon: const Icon(
                                            Icons.request_quote_outlined),
                                        label: const Text('Devis'),
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
