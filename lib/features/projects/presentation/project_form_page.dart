import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/record_status.dart';
import '../../../core/models/project.dart';
import '../../../core/services/supabase_service.dart';
import 'providers/current_profile_provider.dart';
import 'providers/projects_providers.dart';

class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({
    super.key,
    this.project,
  });

  final Project? project;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  late final TextEditingController nameController;
  late final TextEditingController clientController;
  late final TextEditingController locationController;
  late final TextEditingController descriptionController;
  late final TextEditingController budgetController;

  bool saving = false;

  bool get isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    nameController = TextEditingController(text: project?.name ?? '');
    clientController = TextEditingController(text: project?.clientName ?? '');
    locationController = TextEditingController(text: project?.location ?? '');
    descriptionController =
        TextEditingController(text: project?.description ?? '');
    budgetController = TextEditingController(
      text: project == null ? '0' : project.budgetInitial.toStringAsFixed(0),
    );
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => saving = true);

    try {
      final authUser = SupabaseService.client.auth.currentUser;
      if (authUser == null) {
        throw Exception('Aucune session Supabase active.');
      }

      debugPrint('AUTH USER ID = ${authUser.id}');
      debugPrint('AUTH USER EMAIL = ${authUser.email}');

      final profile = await ref.read(currentProfileProvider.future);
      debugPrint('PROFILE FOUND = ${profile != null}');
      debugPrint('PROFILE COMPANY ID = ${profile?.companyId}');
      debugPrint('PROFILE EMAIL = ${profile?.email}');
      debugPrint('PROFILE FULL NAME = ${profile?.fullName}');

      if (profile == null) {
        throw Exception('Profil utilisateur introuvable dans Supabase.');
      }

      final project = Project(
        id: widget.project?.id ?? '',
        companyId: widget.project?.companyId ?? profile.companyId,
        name: nameController.text.trim(),
        clientName: clientController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        budgetInitial: double.tryParse(budgetController.text.trim()) ?? 0,
        progress: widget.project?.progress ?? 0,
        status: widget.project?.status ?? RecordStatus.brouillon,
      );

      debugPrint('PROJECT COMPANY ID = ${project.companyId}');
      debugPrint('PROJECT NAME = ${project.name}');

      final repository = ref.read(projectsRepositoryProvider);

      if (isEditing) {
        await repository.updateProject(project);
      } else {
        await repository.createProject(project);
      }

      ref.invalidate(projectsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet enregistré.')),
      );
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Erreur création projet: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création projet: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    clientController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier projet' : 'Nouveau projet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom du projet'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientController,
              decoration: const InputDecoration(labelText: 'Client'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Localisation'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              decoration: const InputDecoration(labelText: 'Budget initial'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: Text(
                saving
                    ? 'Enregistrement...'
                    : (isEditing ? 'Mettre à jour' : 'Créer le projet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
