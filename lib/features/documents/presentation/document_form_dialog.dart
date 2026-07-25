import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_document.dart';
import '../../../core/services/supabase_service.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/documents_providers.dart';

class DocumentFormDialog extends ConsumerStatefulWidget {
  const DocumentFormDialog({
    super.key,
    this.taskId,
    this.purchaseId,
  });

  final String? taskId;
  final String? purchaseId;

  @override
  ConsumerState<DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends ConsumerState<DocumentFormDialog> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  String category = 'autre';
  bool saving = false;

  PlatformFile? selectedFile;
  Uint8List? selectedBytes;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible de lire le fichier sélectionné.')),
      );
      return;
    }

    setState(() {
      selectedFile = file;
      selectedBytes = file.bytes;
      if (titleController.text.trim().isEmpty) {
        titleController.text = _defaultTitleFromFileName(file.name);
      }
    });
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (project == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun projet courant sélectionné.')),
        );
      }
      return;
    }

    if (profile == null || authUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return;
    }

    if (selectedFile == null || selectedBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis un fichier.')),
        );
      }
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisis un titre.')),
        );
      }
      return;
    }

    setState(() => saving = true);

    final repository = ref.read(documentsRepositoryProvider);
    final bucketId = 'project-documents';
    final mimeType = _guessMimeType(selectedFile!.name);
    final storagePath = repository.buildStoragePath(
      projectId: project.id,
      fileName: selectedFile!.name,
      taskId: widget.taskId,
      purchaseId: widget.purchaseId,
    );

    try {
      await repository.uploadFileBytes(
        bucketId: bucketId,
        storagePath: storagePath,
        bytes: selectedBytes!,
        mimeType: mimeType,
      );

      final document = ProjectDocument(
        id: '',
        companyId: profile.companyId,
        projectId: project.id,
        taskId: widget.taskId,
        purchaseId: widget.purchaseId,
        title: title,
        description: descriptionController.text.trim(),
        category: category,
        bucketId: bucketId,
        fileName: selectedFile!.name,
        filePath: storagePath,
        fileSize: selectedBytes!.length,
        mimeType: mimeType,
        uploadedBy: authUser.id,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createDocument(document);

      ref.invalidate(activeDocumentsProvider);
      ref.invalidate(archivedDocumentsProvider);

      if ((widget.taskId ?? '').isNotEmpty) {
        ref.invalidate(taskDocumentsProvider(widget.taskId!));
      }

      if ((widget.purchaseId ?? '').isNotEmpty) {
        ref.invalidate(purchaseDocumentsProvider(widget.purchaseId!));
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document enregistré.')),
      );
    } catch (error) {
      await repository.deleteFile(
        bucketId: bucketId,
        filePath: storagePath,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nouveau document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: selectedFile == null
                                  ? const Text('Aucun fichier sélectionné.')
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(_fileIcon(selectedFile!.name)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedFile!.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatFileSize(
                                              selectedBytes?.length ?? 0),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: saving ? null : pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Choisir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'plan', child: Text('Plan')),
                    DropdownMenuItem(value: 'photo', child: Text('Photo')),
                    DropdownMenuItem(value: 'facture', child: Text('Facture')),
                    DropdownMenuItem(
                        value: 'bon_commande', child: Text('Bon commande')),
                    DropdownMenuItem(value: 'pv', child: Text('PV')),
                    DropdownMenuItem(value: 'rapport', child: Text('Rapport')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rattachement',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Tâche : ${(widget.taskId ?? '').isEmpty ? '-' : widget.taskId!}'),
                        const SizedBox(height: 4),
                        Text(
                            'Achat : ${(widget.purchaseId ?? '').isEmpty ? '-' : widget.purchaseId!}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : save,
                        icon: const Icon(Icons.save_outlined),
                        label:
                            Text(saving ? 'Enregistrement...' : 'Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _defaultTitleFromFileName(String value) {
    final dotIndex = value.lastIndexOf('.');
    if (dotIndex <= 0) {
      return value;
    }
    return value.substring(0, dotIndex);
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    return 'application/octet-stream';
  }

  IconData _fileIcon(String fileName) {
    final mimeType = _guessMimeType(fileName);

    if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_outlined;
    }
    if (mimeType.startsWith('image/')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes o';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}
