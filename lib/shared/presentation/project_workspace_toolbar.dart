import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/module_refresh_provider.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/projects/presentation/providers/projects_providers.dart';
import '../../features/projects/presentation/providers/selected_project_provider.dart';

/// Allows standalone pages to retain their selector without duplicating it
/// when they are displayed inside the application workspace.
class ProjectWorkspaceScope extends InheritedWidget {
  const ProjectWorkspaceScope({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProjectWorkspaceScope>() !=
      null;

  @override
  bool updateShouldNotify(ProjectWorkspaceScope oldWidget) => false;
}

/// The same project context and data refresh action in every module.
class ProjectWorkspaceToolbar extends ConsumerWidget {
  const ProjectWorkspaceToolbar({super.key, this.dense = false});

  final bool dense;

  static const _destinations = [
    ('/dashboard', 'Tableau de bord', Icons.dashboard_outlined),
    ('/planning', 'Planning', Icons.calendar_month_outlined),
    ('/checklist', 'Check-list', Icons.checklist_rtl_outlined),
    ('/metrage', 'Métré', Icons.straighten_outlined),
    ('/quantitatif', 'Quantitatif', Icons.calculate_outlined),
    ('/devis', 'Devis', Icons.request_quote_outlined),
    ('/factures', 'Factures', Icons.receipt_long_outlined),
    ('/technique', 'Technique', Icons.engineering_outlined),
    ('/achats', 'Achats', Icons.shopping_cart_outlined),
    ('/documents', 'Documents', Icons.folder_outlined),
    ('/reports', 'Rapports', Icons.description_outlined),
    ('/chat', 'Chat du chantier', Icons.chat_bubble_outline),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final project = ref.watch(selectedProjectProvider).value;
    final theme = Theme.of(context);
    final options = projects.value ?? const [];
    final selectedId =
        options.any((p) => p.id == project?.id) ? project?.id : null;
    final refreshing = projects.isRefreshing;
    final refreshIcon = refreshing
        ? const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.refresh);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 2 : 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = dense || constraints.maxWidth < 600;
          final compactButtonStyle = dense
              ? IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  maximumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(8),
                )
              : null;
          final picker = SizedBox(
            width: compact ? constraints.maxWidth - 100 : 300,
            child: DropdownButtonFormField<String>(
              key: ValueKey(selectedId),
              initialValue: selectedId,
              isExpanded: true,
              isDense: true,
              style: dense ? theme.textTheme.bodySmall : null,
              decoration: InputDecoration(
                labelText: 'Sélection du projet',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                constraints:
                    dense ? const BoxConstraints.tightFor(height: 40) : null,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: dense ? 0 : 8),
              ),
              icon: const Icon(Icons.expand_more),
              hint: Text(projects.isLoading
                  ? 'Chargement des chantiers…'
                  : projects.hasError
                      ? 'Chantiers indisponibles'
                      : 'Choisir un chantier'),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: options.isEmpty
                  ? null
                  : (id) async {
                      if (id == null || id == project?.id) return;
                      try {
                        await ref
                            .read(selectedProjectIdProvider.notifier)
                            .setProjectId(id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Impossible de changer de chantier. Réessayez.')),
                          );
                        }
                      }
                    },
            ),
          );
          final menu = PopupMenuButton<String>(
            tooltip: 'Ouvrir un module pour ce chantier',
            enabled: project != null,
            icon: const Icon(Icons.open_in_new),
            style: compactButtonStyle,
            onSelected: (path) {
              if (path == '/chat') {
                ref
                    .read(chatConversationProvider.notifier)
                    .open(ChatConversation.project);
              }
              context.go(path);
            },
            itemBuilder: (_) => [
              for (final destination in _destinations)
                PopupMenuItem(
                  value: destination.$1,
                  child: Row(children: [
                    Icon(destination.$3, size: 19),
                    const SizedBox(width: 10),
                    Text(destination.$2),
                  ]),
                ),
            ],
          );
          return Row(children: [
            picker,
            if (!compact) const Spacer(),
            menu,
            Tooltip(
              message: 'Actualiser les données du module',
              child: compact
                  ? IconButton(
                      style: compactButtonStyle,
                      onPressed: refreshing
                          ? null
                          : () => ref
                              .read(moduleRefreshRevisionProvider.notifier)
                              .refresh(),
                      icon: refreshIcon,
                    )
                  : TextButton.icon(
                      onPressed: refreshing
                          ? null
                          : () => ref
                              .read(moduleRefreshRevisionProvider.notifier)
                              .refresh(),
                      icon: refreshIcon,
                      label: const Text('Actualiser'),
                    ),
            ),
          ]);
        }),
      ),
    );
  }
}
