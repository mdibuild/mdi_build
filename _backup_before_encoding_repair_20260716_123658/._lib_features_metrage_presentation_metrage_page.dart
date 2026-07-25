import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/record_status.dart';
import '../../../core/models/opening_item.dart';
import '../../../core/models/space_item.dart';
import '../../../core/widgets/app_scaffold_title.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/spaces_providers.dart';
import 'widgets/opening_form.dart';
import 'widgets/space_form.dart';

class MetragePage extends ConsumerWidget {
  const MetragePage({super.key});

  Future<void> _openCreateSpaceDialog(
      BuildContext context, WidgetRef ref, String projectId) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Nouvel ÃƒÆ’Ã‚Â©lÃƒÆ’Ã‚Â©ment de mÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©'),
          content: SizedBox(
            width: 420,
            child: SpaceForm(
              onSubmit: (value) async {
                final selectedProject =
                    await ref.read(selectedProjectProvider.future);
                if (selectedProject == null) {
                  return;
                }

                final item = SpaceItem(
                  id: '',
                  companyId: selectedProject.companyId,
                  projectId: projectId,
                  type: value.type,
                  name: value.name,
                  levelName: value.levelName,
                  length: value.length,
                  width: value.width,
                  height: value.height,
                  quantity: value.quantity,
                  status: RecordStatus.brouillon,
                );
                await ref.read(spacesRepositoryProvider).createSpace(item);
                ref.invalidate(spacesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditSpaceDialog(
      BuildContext context, WidgetRef ref, SpaceItem space) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier espace ÃƒÂ¢DAÃ‚Â¢ ${space.name}'),
          content: SizedBox(
            width: 420,
            child: SpaceForm(
              initialValue: space,
              onSubmit: (value) async {
                final updated = SpaceItem(
                  id: space.id,
                  companyId: space.companyId,
                  projectId: space.projectId,
                  type: value.type,
                  name: value.name,
                  levelName: value.levelName,
                  length: value.length,
                  width: value.width,
                  height: value.height,
                  quantity: value.quantity,
                  status: space.status,
                  openings: space.openings,
                );
                await ref.read(spacesRepositoryProvider).updateSpace(updated);
                ref.invalidate(spacesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSpace(
      BuildContext context, WidgetRef ref, SpaceItem space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer espace'),
        content: Text('Supprimer "${space.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(spacesRepositoryProvider).deleteSpace(space.id);
    ref.invalidate(spacesProvider);
  }

  Future<void> _openCreateOpeningDialog(
      BuildContext context, WidgetRef ref, SpaceItem space) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nouvelle ouverture ÃƒÂ¢DAÃ‚Â¢ ${space.name}'),
          content: SizedBox(
            width: 420,
            child: OpeningForm(
              onSubmit: (value) async {
                final opening = OpeningItem(
                  id: '',
                  companyId: space.companyId,
                  projectId: space.projectId,
                  spaceId: space.id,
                  name: value.name,
                  openingType: value.openingType,
                  width: value.width,
                  height: value.height,
                  quantity: value.quantity,
                );
                await ref.read(spacesRepositoryProvider).createOpening(opening);
                ref.invalidate(spacesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditOpeningDialog(BuildContext context, WidgetRef ref,
      SpaceItem space, OpeningItem opening) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier ouverture ÃƒÂ¢DAÃ‚Â¢ ${opening.name}'),
          content: SizedBox(
            width: 420,
            child: OpeningForm(
              initialValue: opening,
              onSubmit: (value) async {
                final updated = OpeningItem(
                  id: opening.id,
                  companyId: opening.companyId,
                  projectId: opening.projectId,
                  spaceId: opening.spaceId,
                  name: value.name,
                  openingType: value.openingType,
                  width: value.width,
                  height: value.height,
                  quantity: value.quantity,
                );
                await ref.read(spacesRepositoryProvider).updateOpening(updated);
                ref.invalidate(spacesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteOpening(
      BuildContext context, WidgetRef ref, OpeningItem opening) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ouverture'),
        content: Text('Supprimer "${opening.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(spacesRepositoryProvider).deleteOpening(opening.id);
    ref.invalidate(spacesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(spacesProvider);
    final selectedProjectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            selectedProjectAsync.when(
              data: (project) => AppScaffoldTitle(
                title: 'MÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©',
                subtitle: project == null
                    ? 'Choisis un projet dans le module Projets.'
                    : 'Projet courant : ${project.name}',
                action: project == null
                    ? null
                    : ElevatedButton.icon(
                        onPressed: () =>
                            _openCreateSpaceDialog(context, ref, project.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un espace'),
                      ),
              ),
              loading: () => const AppScaffoldTitle(
                  title: 'MÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©',
                  subtitle: 'Chargement projet courant...'),
              error: (_, __) => const AppScaffoldTitle(
                  title: 'MÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©',
                  subtitle: 'Projet courant indisponible.'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: spacesAsync.when(
                data: (spaces) {
                  if (spaces.isEmpty) {
                    return const Card(
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Aucun espace pour ce projet.'))),
                    );
                  }

                  return Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: spaces.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = spaces[index];
                        return ExpansionTile(
                          title: Text(
                              '${item.name} ÃƒÂ¢DAÃ‚Â¢ ${item.type.label}'),
                          subtitle: Text(
                            'Sol=${item.floorArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â² ÃƒÂ¢DAÃ‚Â¢ Murs nets=${item.netWallArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²',
                          ),
                          trailing: Text(item.status.label),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Chip(
                                    label: Text(
                                        'Brut murs: ${item.grossWallArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²')),
                                Chip(
                                    label: Text(
                                        'Ouvertures: ${item.openingsArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²')),
                                Chip(
                                    label: Text(
                                        'Net murs: ${item.netWallArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²')),
                                Chip(
                                    label: Text(
                                        'Plafond: ${item.ceilingArea.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²')),
                                Chip(
                                    label: Text(
                                        'PÃƒÆ’Ã‚Â©rimÃƒÆ’Ã‚Â¨tre: ${item.perimeter.toStringAsFixed(2)} ml')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openCreateOpeningDialog(
                                      context, ref, item),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter ouverture'),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _openEditSpaceDialog(context, ref, item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Modifier espace'),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _deleteSpace(context, ref, item),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Supprimer espace'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (item.openings.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Aucune ouverture.'),
                              )
                            else
                              Column(
                                children: [
                                  for (final opening in item.openings)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          '${opening.name} ÃƒÂ¢DAÃ‚Â¢ ${opening.openingType}'),
                                      subtitle: Text(
                                          '${opening.width} ÃƒÆ’Ã¢DAâDA ${opening.height} ÃƒÆ’Ã¢DAâDA ${opening.quantity}'),
                                      trailing: Wrap(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                              '${opening.area.toStringAsFixed(2)} mÃƒâDAšÃ‚Â²'),
                                          IconButton(
                                            onPressed: () =>
                                                _openEditOpeningDialog(context,
                                                    ref, item, opening),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteOpening(
                                                context, ref, opening),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erreur: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
