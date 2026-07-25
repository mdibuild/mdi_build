import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ? 'Pilotage global de lâDAÃ¢âDAž¢activité'
                : 'Projet courant : ${project.name}';

            return ListView(
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
                          ),
                          PremiumMetricTile(
                            label: 'Tâches',
                            value: '${metrics.tasksCount}',
                            icon: Icons.event_note_outlined,
                          ),
                          PremiumMetricTile(
                            label: 'Achats',
                            value: '${metrics.purchasesCount}',
                            icon: Icons.shopping_cart_outlined,
                          ),
                          PremiumMetricTile(
                            label: 'Rapports',
                            value: '${metrics.reportsCount}',
                            icon: Icons.description_outlined,
                          ),
                          PremiumMetricTile(
                            label: 'Documents',
                            value: '${metrics.documentsCount}',
                            icon: Icons.folder_outlined,
                          ),
                          PremiumMetricTile(
                            label: 'Devis',
                            value: '${metrics.quotesCount}',
                            icon: Icons.request_quote_outlined,
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
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.warning_amber_outlined,
                        label: 'Tâches en retard',
                        value: '${metrics.lateTasksCount}',
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Rapports automatiques',
                        value: '${metrics.autoReportsCount}',
                        color: AppColors.info,
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.edit_note_outlined,
                        label: 'Rapports manuels',
                        value: '${metrics.manualReportsCount}',
                        color: AppColors.purple,
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
                                const Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: AppColors.petrol,
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
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.petrol,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
