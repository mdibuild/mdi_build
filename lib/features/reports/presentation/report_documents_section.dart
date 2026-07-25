import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_document.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/presentation/document_view_page.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

class ReportDocumentsSection extends ConsumerStatefulWidget {
  const ReportDocumentsSection({
    super.key,
    required this.projectId,
    required this.reportId,
  });

  final String projectId;
  final String reportId;

  @override
  ConsumerState<ReportDocumentsSection> createState() =>
      _ReportDocumentsSectionState();
}

class _ReportDocumentsSectionState
    extends ConsumerState<ReportDocumentsSection> {
  late Future<List<ProjectDocument>> _documentsFuture;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _loadDocuments();
  }

  Future<List<ProjectDocument>> _loadDocuments() {
    return ref.read(documentsRepositoryProvider).fetchReportDocuments(
          widget.reportId,
          archived: false,
        );
  }

  void _refresh() {
    setState(() {
      _documentsFuture = _loadDocuments();
    });
  }

  Future<void> _pickAndUploadDocument() async {
    if (_uploading) {
      return;
    }

    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil utilisateur introuvable.')),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier invalide.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final metadata = await showDialog<_DocumentMetadataResult>(
      context: context,
      builder: (_) => _DocumentMetadataDialog(
        initialTitle: file.name,
        initialCategory: _defaultCategory(file.name),
      ),
    );

    if (metadata == null) {
      return;
    }

    final repository = ref.read(documentsRepositoryProvider);
    final now = DateTime.now();
    final safeFileName = _sanitizeFileName(file.name);
    final filePath =
        'projects/${widget.projectId}/reports/${widget.reportId}/${now.microsecondsSinceEpoch}_$safeFileName';

    setState(() {
      _uploading = true;
    });

    try {
      await repository.uploadBytes(
        filePath: filePath,
        bytes: bytes,
        contentType: _resolveMimeType(file.name),
      );

      final document = ProjectDocument(
        id: '',
        companyId: profile.companyId,
        projectId: widget.projectId,
        bucketId: 'project-documents',
        filePath: filePath,
        fileName: file.name,
        mimeType: _resolveMimeType(file.name),
        fileSize: bytes.length,
        title: metadata.title,
        description: metadata.description,
        category: metadata.category,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        reportId: widget.reportId,
      );

      await repository.createDocument(document);

      if (!mounted) {
        return;
      }

      _refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document ajouté au rapport.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _openDocument(ProjectDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewPage(document: document),
      ),
    );
  }

  Future<void> _archiveDocument(ProjectDocument document) async {
    await ref.read(documentsRepositoryProvider).setArchived(
          documentId: document.id,
          archived: !document.isArchived,
        );
    _refresh();
  }

  Future<void> _deleteDocument(ProjectDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer document'),
        content: Text('Supprimer "${document.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(documentsRepositoryProvider).deleteDocument(document);

    if (!mounted) {
      return;
    }

    _refresh();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document supprimé.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents / photos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickAndUploadDocument,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: Text(
                        _uploading ? 'Ajout...' : 'Ajouter une pièce jointe',
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Documents / photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _pickAndUploadDocument,
                    icon: const Icon(Icons.attach_file_outlined),
                    label: Text(
                      _uploading ? 'Ajout...' : 'Ajouter une pièce jointe',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            FutureBuilder<List<ProjectDocument>>(
              future: _documentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Erreur documents : ${snapshot.error}'),
                  );
                }

                final documents = snapshot.data ?? const <ProjectDocument>[];
                if (documents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Aucun document lié à ce rapport.'),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return _ReportDocumentTile(
                      document: document,
                      onOpen: () => _openDocument(document),
                      onArchive: () => _archiveDocument(document),
                      onDelete: () => _deleteDocument(document),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _defaultCategory(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return 'photo';
    }
    if (lower.endsWith('.pdf')) {
      return 'rapport';
    }
    return 'autre';
  }

  String _resolveMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }

  String _sanitizeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}

class _ReportDocumentTile extends StatelessWidget {
  const _ReportDocumentTile({
    required this.document,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
  });

  final ProjectDocument document;
  final VoidCallback onOpen;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final createdAt =
        '${document.createdAt.day.toString().padLeft(2, '0')}/${document.createdAt.month.toString().padLeft(2, '0')}/${document.createdAt.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(document)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(document.fileName),
                      const SizedBox(height: 4),
                      Text(
                        'Catégorie : ${_categoryLabel(document.category)} ÃƒâDAš· Ajouté le $createdAt',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (document.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(document.description),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ouvrir'),
                ),
                TextButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiver'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ProjectDocument document) {
    if (document.isPdf) {
      return Icons.picture_as_pdf_outlined;
    }
    if (document.isImage) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'photo':
        return 'Photo';
      case 'rapport':
        return 'Rapport';
      case 'plan':
        return 'Plan';
      case 'facture':
        return 'Facture';
      case 'bon_commande':
        return 'Bon commande';
      case 'pv':
        return 'PV';
      default:
        return 'Autre';
    }
  }
}

class _DocumentMetadataDialog extends StatefulWidget {
  const _DocumentMetadataDialog({
    required this.initialTitle,
    required this.initialCategory,
  });

  final String initialTitle;
  final String initialCategory;

  @override
  State<_DocumentMetadataDialog> createState() =>
      _DocumentMetadataDialogState();
}

class _DocumentMetadataDialogState extends State<_DocumentMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _DocumentMetadataResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle pièce jointe'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Titre obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: const [
                  DropdownMenuItem(value: 'photo', child: Text('Photo')),
                  DropdownMenuItem(value: 'rapport', child: Text('Rapport')),
                  DropdownMenuItem(value: 'plan', child: Text('Plan')),
                  DropdownMenuItem(value: 'autre', child: Text('Autre')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

class _DocumentMetadataResult {
  const _DocumentMetadataResult({
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final String category;
}
