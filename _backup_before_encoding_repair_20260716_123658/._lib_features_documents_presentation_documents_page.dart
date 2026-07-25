import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_document.dart';
import '../../../core/services/supabase_service.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'document_form_dialog.dart';
import 'document_view_page.dart';
import 'providers/documents_providers.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  final TextEditingController searchController = TextEditingController();

  String categoryFilter = 'toutes';
  String relationFilter = 'toutes';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openNewDocumentDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const DocumentFormDialog(),
    );

    if (created == true) {
      ref.invalidate(activeDocumentsProvider);
      ref.invalidate(archivedDocumentsProvider);
    }
  }

  Future<void> _openDocument(
    BuildContext context,
    ProjectDocument document,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewPage(document: document),
      ),
    );
  }

  Future<void> _toggleArchive(ProjectDocument document) async {
    await ref.read(documentsRepositoryProvider).setArchived(
          documentId: document.id,
          archived: !document.isArchived,
        );

    ref.invalidate(activeDocumentsProvider);
    ref.invalidate(archivedDocumentsProvider);
  }

  Future<void> _deleteDocument(
    BuildContext context,
    ProjectDocument document,
  ) async {
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
          ElevatedButton(
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

    ref.invalidate(activeDocumentsProvider);
    ref.invalidate(archivedDocumentsProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document supprimÃƒÆ’Ã‚Â©.')),
    );
  }

  Future<void> _copySignedUrl(
    BuildContext context,
    ProjectDocument document,
  ) async {
    try {
      final signedUrl =
          await ref.read(documentsRepositoryProvider).createSignedUrl(
                bucketId: document.bucketId,
                filePath: document.filePath,
              );

      await Clipboard.setData(ClipboardData(text: signedUrl));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien temporaire copiÃƒÆ’Ã‚Â©.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lien: $error')),
      );
    }
  }

  List<ProjectDocument> _applyFilters(List<ProjectDocument> documents) {
    final query = searchController.text.trim().toLowerCase();

    return documents.where((document) {
      final matchesSearch = query.isEmpty ||
          document.title.toLowerCase().contains(query) ||
          document.description.toLowerCase().contains(query) ||
          document.fileName.toLowerCase().contains(query) ||
          document.mimeType.toLowerCase().contains(query);

      final matchesCategory =
          categoryFilter == 'toutes' || document.category == categoryFilter;

      final hasTask = (document.taskId ?? '').isNotEmpty;
      final hasPurchase = (document.purchaseId ?? '').isNotEmpty;

      var matchesRelation = true;
      if (relationFilter == 'tache') {
        matchesRelation = hasTask;
      } else if (relationFilter == 'achat') {
        matchesRelation = hasPurchase;
      } else if (relationFilter == 'avec_liaison') {
        matchesRelation = hasTask || hasPurchase;
      } else if (relationFilter == 'sans_liaison') {
        matchesRelation = !hasTask && !hasPurchase;
      }

      return matchesSearch && matchesCategory && matchesRelation;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final activeDocumentsAsync = ref.watch(activeDocumentsProvider);
    final archivedDocumentsAsync = ref.watch(archivedDocumentsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Documents'),
              bottom: TabBar(
                isScrollable: isCompact,
                tabs: const [
                  Tab(text: 'En cours'),
                  Tab(text: 'ArchivÃƒÆ’Ã‚Â©s'),
                ],
              ),
            ),
            body: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 20),
              child: Column(
                children: [
                  selectedProjectAsync.when(
                    data: (project) => _DocumentsHeader(
                      isCompact: isCompact,
                      projectName: project?.name,
                      onCreate: project == null
                          ? null
                          : () => _openNewDocumentDialog(context),
                    ),
                    loading: () => _DocumentsHeader(
                      isCompact: isCompact,
                      projectName: null,
                    ),
                    error: (_, __) => _DocumentsHeader(
                      isCompact: isCompact,
                      projectName: null,
                      unavailable: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DocumentsFilters(
                    isCompact: isCompact,
                    searchController: searchController,
                    categoryFilter: categoryFilter,
                    relationFilter: relationFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onCategoryChanged: (value) {
                      if (value != null) {
                        setState(() => categoryFilter = value);
                      }
                    },
                    onRelationChanged: (value) {
                      if (value != null) {
                        setState(() => relationFilter = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        activeDocumentsAsync.when(
                          data: (documents) => _DocumentsList(
                            isCompact: isCompact,
                            documents: _applyFilters(documents),
                            onOpen: (document) =>
                                _openDocument(context, document),
                            onArchiveToggle: _toggleArchive,
                            onDelete: (document) =>
                                _deleteDocument(context, document),
                            onCopyLink: (document) =>
                                _copySignedUrl(context, document),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                        archivedDocumentsAsync.when(
                          data: (documents) => _DocumentsList(
                            isCompact: isCompact,
                            documents: _applyFilters(documents),
                            onOpen: (document) =>
                                _openDocument(context, document),
                            onArchiveToggle: _toggleArchive,
                            onDelete: (document) =>
                                _deleteDocument(context, document),
                            onCopyLink: (document) =>
                                _copySignedUrl(context, document),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({
    required this.isCompact,
    this.projectName,
    this.onCreate,
    this.unavailable = false,
  });

  final bool isCompact;
  final String? projectName;
  final VoidCallback? onCreate;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final title = isCompact ? 'Documents' : 'Documents projet';
    final subtitle = unavailable
        ? 'Projet courant indisponible.'
        : projectName == null
            ? 'Chargement projet courant...'
            : 'Projet courant : $projectName';

    final action = ElevatedButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(isCompact ? 'Nouveau' : 'Nouveau document'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: action,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  action,
                ],
              ),
      ),
    );
  }
}

class _DocumentsFilters extends StatelessWidget {
  const _DocumentsFilters({
    required this.isCompact,
    required this.searchController,
    required this.categoryFilter,
    required this.relationFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onRelationChanged,
  });

  final bool isCompact;
  final TextEditingController searchController;
  final String categoryFilter;
  final String relationFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onRelationChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isCompact ? double.infinity : 360,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Recherche',
                  hintText: 'Titre, description, fichier, type',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: categoryFilter,
                decoration:
                    const InputDecoration(labelText: 'CatÃƒÆ’Ã‚Â©gorie'),
                items: const [
                  DropdownMenuItem(value: 'toutes', child: Text('Toutes')),
                  DropdownMenuItem(value: 'plan', child: Text('Plan')),
                  DropdownMenuItem(value: 'photo', child: Text('Photo')),
                  DropdownMenuItem(value: 'facture', child: Text('Facture')),
                  DropdownMenuItem(
                    value: 'bon_commande',
                    child: Text('Bon commande'),
                  ),
                  DropdownMenuItem(value: 'pv', child: Text('PV')),
                  DropdownMenuItem(value: 'rapport', child: Text('Rapport')),
                  DropdownMenuItem(value: 'autre', child: Text('Autre')),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
            SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: relationFilter,
                decoration: const InputDecoration(labelText: 'Liaison'),
                items: const [
                  DropdownMenuItem(value: 'toutes', child: Text('Toutes')),
                  DropdownMenuItem(
                    value: 'avec_liaison',
                    child: Text('Avec liaison'),
                  ),
                  DropdownMenuItem(
                    value: 'sans_liaison',
                    child: Text('Sans liaison'),
                  ),
                  DropdownMenuItem(
                    value: 'tache',
                    child: Text('LiÃƒÆ’Ã‚Â©s ÃƒÆ’Ã‚Â  une tÃƒÆ’Ã‚Â¢che'),
                  ),
                  DropdownMenuItem(
                    value: 'achat',
                    child: Text('LiÃƒÆ’Ã‚Â©s ÃƒÆ’Ã‚Â  un achat'),
                  ),
                ],
                onChanged: onRelationChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({
    required this.isCompact,
    required this.documents,
    required this.onOpen,
    required this.onArchiveToggle,
    required this.onDelete,
    required this.onCopyLink,
  });

  final bool isCompact;
  final List<ProjectDocument> documents;
  final Future<void> Function(ProjectDocument document) onOpen;
  final Future<void> Function(ProjectDocument document) onArchiveToggle;
  final Future<void> Function(ProjectDocument document) onDelete;
  final Future<void> Function(ProjectDocument document) onCopyLink;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucun document.'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final document = documents[index];
          return _DocumentTile(
            isCompact: isCompact,
            document: document,
            onOpen: () => onOpen(document),
            onArchiveToggle: () => onArchiveToggle(document),
            onDelete: () => onDelete(document),
            onCopyLink: () => onCopyLink(document),
          );
        },
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.isCompact,
    required this.document,
    required this.onOpen,
    required this.onArchiveToggle,
    required this.onDelete,
    required this.onCopyLink,
  });

  final bool isCompact;
  final ProjectDocument document;
  final Future<void> Function() onOpen;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;
  final Future<void> Function() onCopyLink;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  late Future<_RelationLabels> _relationsFuture;

  @override
  void initState() {
    super.initState();
    _relationsFuture = _resolveRelations();
  }

  @override
  void didUpdateWidget(covariant _DocumentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.taskId != widget.document.taskId ||
        oldWidget.document.purchaseId != widget.document.purchaseId) {
      _relationsFuture = _resolveRelations();
    }
  }

  Future<_RelationLabels> _resolveRelations() async {
    final taskTitle = await _resolveTitle(
      id: widget.document.taskId,
      table: 'project_tasks',
    );
    final purchaseTitle = await _resolveTitle(
      id: widget.document.purchaseId,
      table: 'purchases',
    );

    return _RelationLabels(
      taskTitle: taskTitle,
      purchaseTitle: purchaseTitle,
    );
  }

  Future<String> _resolveTitle({
    required String? id,
    required String table,
  }) async {
    if ((id ?? '').isEmpty) {
      return '-';
    }

    try {
      final row = await SupabaseService.client
          .from(table)
          .select('title')
          .eq('id', id!)
          .maybeSingle();

      final title = (row?['title'] as String?)?.trim() ?? '';
      if (title.isNotEmpty) {
        return title;
      }
    } catch (_) {}

    return _shortId(id!);
  }

  String _shortId(String value) {
    return value.length <= 12 ? value : value.substring(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    final createdAt =
        DateFormat('dd/MM/yyyy HH:mm').format(widget.document.createdAt);

    return FutureBuilder<_RelationLabels>(
      future: _relationsFuture,
      builder: (context, snapshot) {
        final relations = snapshot.data ??
            _RelationLabels(
              taskTitle: (widget.document.taskId ?? '').isEmpty
                  ? '-'
                  : _shortId(widget.document.taskId!),
              purchaseTitle: (widget.document.purchaseId ?? '').isEmpty
                  ? '-'
                  : _shortId(widget.document.purchaseId!),
            );

        return Card(
          child: Padding(
            padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DocumentPreview(
                            document: widget.document,
                            compact: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.document.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CategoryChip(category: widget.document.category),
                          if ((widget.document.taskId ?? '').isNotEmpty)
                            _LinkChip(
                              label: relations.taskTitle,
                              icon: Icons.task_alt_outlined,
                            ),
                          if ((widget.document.purchaseId ?? '').isNotEmpty)
                            _LinkChip(
                              label: relations.purchaseTitle,
                              icon: Icons.shopping_bag_outlined,
                            ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DocumentPreview(
                        document: widget.document,
                        compact: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.document.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _CategoryChip(
                                    category: widget.document.category),
                                if ((widget.document.taskId ?? '').isNotEmpty)
                                  _LinkChip(
                                    label: relations.taskTitle,
                                    icon: Icons.task_alt_outlined,
                                  ),
                                if ((widget.document.purchaseId ?? '')
                                    .isNotEmpty)
                                  _LinkChip(
                                    label: relations.purchaseTitle,
                                    icon: Icons.shopping_bag_outlined,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'Fichier',
                  value: widget.document.fileName,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'Type',
                  value: widget.document.mimeType,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'Taille',
                  value: _formatFileSize(widget.document.fileSize),
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'AjoutÃƒÆ’Ã‚Â© le',
                  value: createdAt,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'TÃƒÆ’Ã‚Â¢che',
                  value: relations.taskTitle,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  compact: widget.isCompact,
                  label: 'Achat',
                  value: relations.purchaseTitle,
                ),
                if (widget.document.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(widget.document.description),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onOpen,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Ouvrir'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onCopyLink,
                        icon: const Icon(Icons.link_outlined),
                        label: const Text('Lien'),
                      ),
                      TextButton.icon(
                        onPressed: widget.onArchiveToggle,
                        icon: Icon(
                          widget.document.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        label: Text(
                          widget.document.isArchived
                              ? 'DÃƒÆ’Ã‚Â©sarchiver'
                              : 'Archiver',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _RelationLabels {
  const _RelationLabels({
    required this.taskTitle,
    required this.purchaseTitle,
  });

  final String taskTitle;
  final String purchaseTitle;
}

class _DocumentPreview extends ConsumerStatefulWidget {
  const _DocumentPreview({
    required this.document,
    required this.compact,
  });

  final ProjectDocument document;
  final bool compact;

  @override
  ConsumerState<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends ConsumerState<_DocumentPreview> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();

    if (widget.document.isImage) {
      _signedUrlFuture = ref.read(documentsRepositoryProvider).createSignedUrl(
            bucketId: widget.document.bucketId,
            filePath: widget.document.filePath,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.document.isImage) {
      return _FallbackPreview(
        document: widget.document,
        compact: widget.compact,
      );
    }

    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.trim().isEmpty) {
          return _FallbackPreview(
            document: widget.document,
            compact: widget.compact,
          );
        }

        final size = widget.compact ? 76.0 : 92.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: size,
            height: size,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackPreview(
                document: widget.document,
                compact: widget.compact,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview({
    required this.document,
    required this.compact,
  });

  final ProjectDocument document;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = document.isPdf
        ? Icons.picture_as_pdf_outlined
        : document.isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;

    final color = document.isPdf
        ? Colors.red
        : document.isImage
            ? Colors.green
            : Colors.blueGrey;

    final size = compact ? 76.0 : 92.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: compact ? 30 : 34),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.compact,
    required this.label,
    required this.value,
  });

  final bool compact;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            '$label :',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);

    return Chip(
      label: Text(_categoryLabel(category)),
      backgroundColor: color.withOpacity(0.14),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case 'plan':
      return Colors.indigo;
    case 'photo':
      return Colors.green;
    case 'facture':
      return Colors.orange;
    case 'bon_commande':
      return Colors.blue;
    case 'pv':
      return Colors.deepPurple;
    case 'rapport':
      return Colors.teal;
    case 'autre':
    default:
      return Colors.blueGrey;
  }
}

String _categoryLabel(String category) {
  switch (category) {
    case 'plan':
      return 'Plan';
    case 'photo':
      return 'Photo';
    case 'facture':
      return 'Facture';
    case 'bon_commande':
      return 'Bon commande';
    case 'pv':
      return 'PV';
    case 'rapport':
      return 'Rapport';
    case 'autre':
    default:
      return 'Autre';
  }
}
