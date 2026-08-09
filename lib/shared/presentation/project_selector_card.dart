import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/projects/presentation/providers/projects_providers.dart';
import '../../features/projects/presentation/providers/selected_project_provider.dart';
import 'premium_ui.dart';

/// Sélecteur de projet réutilisable : change le projet actif dans toute
/// l'app (Devis, Chat, Métré, Planning...) via [selectedProjectIdProvider].
class ProjectSelectorCard extends ConsumerWidget {
  const ProjectSelectorCard({
    super.key,
    required this.currentProjectId,
    this.labelText = 'Projet',
  });

  final String currentProjectId;
  final String labelText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      data: (projects) {
        return PremiumSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: DropdownButtonFormField<String>(
            initialValue: currentProjectId,
            decoration: InputDecoration(
              labelText: labelText,
              prefixIcon: const Icon(Icons.apartment_outlined),
              border: InputBorder.none,
            ),
            items: [
              for (final project in projects)
                DropdownMenuItem(value: project.id, child: Text(project.name)),
            ],
            onChanged: (value) {
              if (value == null || value == currentProjectId) {
                return;
              }
              ref.read(selectedProjectIdProvider.notifier).setProjectId(value);
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}
