import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_document.dart';
import '../../documents/presentation/document_form_dialog.dart';
import '../../documents/presentation/document_view_page.dart';
import '../../documents/presentation/providers/documents_providers.dart';

class PurchaseDocumentsSection extends ConsumerWidget {
  const PurchaseDocumentsSection({
    super.key,
    required this.purchaseId,
  });

  final String purchaseId;

  Future<void> _openUploadDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => DocumentFormDialog(purchaseId: purchaseId),
    );

    if (created == true) {
      ref.invalidate(purchaseDocumentsProvider(purchaseId));
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

  Future<void> _copySignedUrl(
    BuildContext context,
    WidgetRef ref,
    ProjectDocument document,
  ) async {
    try {
      final signedUrl =
          await ref.read(documentsRepositoryProvider).createSignedUrl(
                bucketId: document.bucketId,
                filePath: document.filePath,
              );

      await Clipboard.setData(ClipboardData(text: signedUrl));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien temporaire copié.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lien: $error')),
      );
    }
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    ProjectDocument document,
  ) async {
    await ref.read(documentsRepositoryProvider).setArchived(
          documentId: document.id,
          archived: !document.isArchived,
        );

    ref.invalidate(purchaseDocumentsProvider(purchaseId));
    ref.invalidate(activeDocumentsProvider);
    ref.invalidate(archivedDocumentsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          document.isArchived ? 'Document désarchivé.' : 'Document archivé.',
        ),
      ),
    );
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
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

    ref.invalidate(purchaseDocumentsProvider(purchaseId));
    ref.invalidate(activeDocumentsProvider);
    ref.invalidate(archivedDocumentsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document supprimé.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(purchaseDocumentsProvider(purchaseId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Documents liés à l’achat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openUploadDialog(context, ref),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Ajouter document'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            documentsAsync.when(
              data: (documents) {
                if (documents.isEmpty) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Aucun document lié à cet achat.'),
                  );
                }

                return Column(
                  children: [
                    for (final document in documents) ...[
                      _PurchaseDocumentTile(
                        document: document,
                        onOpen: () => _openDocument(context, document),
                        onCopyLink: () =>
                            _copySignedUrl(context, ref, document),
                        onArchive: () => _toggleArchive(context, ref, document),
                        onDelete: () => _deleteDocument(context, ref, document),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Align(
                alignment: Alignment.centerLeft,
                child: Text('Erreur documents: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDocumentTile extends StatelessWidget {
  const _PurchaseDocumentTile({
    required this.document,
    required this.onOpen,
    required this.onCopyLink,
    required this.onArchive,
    required this.onDelete,
  });

  final ProjectDocument document;
  final Future<void> Function() onOpen;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onArchive;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('dd/MM/yyyy HH:mm').format(document.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_iconForDocument(document)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    document.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _CategoryChip(category: document.category),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(label: 'Fichier', value: document.fileName),
            const SizedBox(height: 4),
            _InfoLine(label: 'Ajouté', value: createdAt),
            if (document.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(document.description),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ouvrir'),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyLink,
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Lien'),
                ),
                TextButton.icon(
                  onPressed: onArchive,
                  icon: Icon(
                    document.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(document.isArchived ? 'Désarchiver' : 'Archiver'),
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

  IconData _iconForDocument(ProjectDocument document) {
    if (document.isPdf) {
      return Icons.picture_as_pdf_outlined;
    }
    if (document.isImage) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label :',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
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
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
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
