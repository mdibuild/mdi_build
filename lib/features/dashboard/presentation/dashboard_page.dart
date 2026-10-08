import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/dashboard_metrics.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.palette;
    final projectAsync = ref.watch(selectedProjectProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: metricsAsync.when(
        data: (metrics) => projectAsync.when(
          data: (project) {
            final subtitle = project == null
                ? 'Pilotage global de l’activité'
                : 'Projet courant : ${project.name}';

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardMetricsProvider);
                await ref.read(dashboardMetricsProvider.future);
              },
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumHeroHeader(
                  title: 'MD Build',
                  subtitle: subtitle,
                  trailing: ElevatedButton.icon(
                    onPressed: () => context.go('/reports'),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Rapports'),
                  ),
                ),
                const SizedBox(height: 16),
                PremiumSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumSectionHeader(
                        title: 'Vue exécutive',
                        subtitle: 'Chiffres clés et signaux à surveiller',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          PremiumMetricTile(
                            label: 'Projets',
                            value: '${metrics.projectsCount}',
                            icon: Icons.apartment_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Projets',
                              icon: Icons.apartment_outlined,
                              total: metrics.projectsCount,
                              items: metrics.projectsPreview,
                              route: '/projects',
                            ),
                          ),
                          PremiumMetricTile(
                            label: 'Tâches',
                            value: '${metrics.tasksCount}',
                            icon: Icons.event_note_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Tâches',
                              icon: Icons.event_note_outlined,
                              total: metrics.tasksCount,
                              items: metrics.tasksPreview,
                              route: '/planning',
                            ),
                          ),
                          PremiumMetricTile(
                            label: 'Achats',
                            value: '${metrics.purchasesCount}',
                            icon: Icons.shopping_cart_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Achats',
                              icon: Icons.shopping_cart_outlined,
                              total: metrics.purchasesCount,
                              items: metrics.purchasesPreview,
                              route: '/achats',
                            ),
                          ),
                          PremiumMetricTile(
                            label: 'Rapports',
                            value: '${metrics.reportsCount}',
                            icon: Icons.description_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Rapports',
                              icon: Icons.description_outlined,
                              total: metrics.reportsCount,
                              items: metrics.reportsPreview,
                              route: '/reports',
                            ),
                          ),
                          PremiumMetricTile(
                            label: 'Documents',
                            value: '${metrics.documentsCount}',
                            icon: Icons.folder_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Documents',
                              icon: Icons.folder_outlined,
                              total: metrics.documentsCount,
                              items: metrics.documentsPreview,
                              route: '/documents',
                            ),
                          ),
                          PremiumMetricTile(
                            label: 'Devis',
                            value: '${metrics.quotesCount}',
                            icon: Icons.request_quote_outlined,
                            onTap: () => _showMetricDetail(
                              context,
                              title: 'Devis',
                              icon: Icons.request_quote_outlined,
                              total: metrics.quotesCount,
                              items: metrics.quotesPreview,
                              route: '/devis',
                            ),
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
                      const PremiumSectionHeader(
                        title: 'Pilotage opérationnel',
                        subtitle: 'Suivi simple pour chef de projet',
                      ),
                      const SizedBox(height: 18),
                      _StatusRow(
                        icon: Icons.check_circle_outline,
                        label: 'Tâches terminées',
                        value: '${metrics.doneTasksCount}',
                        color: colors.success,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.warning_amber_outlined,
                        label: 'Tâches en retard',
                        value: '${metrics.lateTasksCount}',
                        color: colors.danger,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Rapports automatiques',
                        value: '${metrics.autoReportsCount}',
                        color: colors.info,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.edit_note_outlined,
                        label: 'Rapports manuels',
                        value: '${metrics.manualReportsCount}',
                        color: colors.purple,
                      ),
                      if (metrics.tasksCount > 0) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'Avancement des tâches',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const Spacer(),
                            Text(
                              '${((metrics.doneTasksCount / metrics.tasksCount) * 100).round()} %',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value:
                                metrics.doneTasksCount / metrics.tasksCount,
                            minHeight: 10,
                            backgroundColor: colors.surfaceAlt,
                            color: colors.success,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${metrics.doneTasksCount} terminée(s) sur ${metrics.tasksCount}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumSectionHeader(
                        title: 'Accès rapide',
                        subtitle: 'Parcours métier prioritaire',
                      ),
                      const SizedBox(height: 16),
                      PremiumActionRow(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/projects'),
                            icon: const Icon(Icons.business_outlined),
                            label: const Text('Projets'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/planning'),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('Planning'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/devis'),
                            icon: const Icon(Icons.request_quote_outlined),
                            label: const Text('Devis'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/achats'),
                            icon: const Icon(Icons.shopping_cart_outlined),
                            label: const Text('Achats'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/documents'),
                            icon: const Icon(Icons.folder_outlined),
                            label: const Text('Documents'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/reports'),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Rapports'),
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
                      const PremiumSectionHeader(
                        title: 'Points de vigilance',
                        subtitle: 'Lecture rapide des signaux métier',
                      ),
                      const SizedBox(height: 14),
                      if (metrics.highlights.isEmpty)
                        const Text('Aucun indicateur disponible.')
                      else
                        ...metrics.highlights.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: colors.petrol,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    line,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumSectionHeader(
                        title: 'Rapports récents',
                        subtitle: 'Production récente et suivi direction',
                      ),
                      const SizedBox(height: 14),
                      if (metrics.recentReportTitles.isEmpty)
                        const Text('Aucun rapport récent.')
                      else
                        ...metrics.recentReportTitles.map(
                          (title) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  color: colors.petrol,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur projet : $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur dashboard : $error')),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

/// Affiche une fiche détaillée (bottom sheet) pour une tuile du dashboard :
/// un aperçu des éléments de la catégorie, sans quitter le tableau de bord,
/// avec un bouton facultatif pour ouvrir la section complète.
void _showMetricDetail(
  BuildContext context, {
  required String title,
  required IconData icon,
  required int total,
  required List<DashboardListItem> items,
  required String route,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = sheetContext.palette;

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (innerContext, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.petrolSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: colors.petrol),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$title ($total)',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun élément à afficher.\n'
                            'Sélectionnez un projet pour voir le détail.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(sheetContext).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final item = items[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, size: 18, color: colors.petrol),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: Theme.of(sheetContext)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            style: Theme.of(sheetContext)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go(route);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir la section'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
