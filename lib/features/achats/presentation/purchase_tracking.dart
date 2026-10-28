import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/project_document.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_workflow.dart';
import '../../../core/services/pdf_letterhead.dart';
import '../../documents/presentation/document_form_dialog.dart';
import '../../documents/presentation/providers/documents_providers.dart';
import '../../settings/presentation/providers/company_providers.dart';
import '../../settings/presentation/providers/suppliers_providers.dart';
import '../services/purchase_pdf_service.dart';
import 'providers/purchases_providers.dart';

/// Barre d'étapes : Besoin émis → Validé DG → En traitement → Commandé →
/// Livré.
class PurchaseStepper extends StatelessWidget {
  const PurchaseStepper({super.key, required this.status, this.onSelect});

  final String status;

  /// Appui sur une étape (avancer ou revenir en arrière) ; null = lecture
  /// seule.
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final rank = PurchaseWorkflow.rank(status);
    final steps = Wrap(
      spacing: 4,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < PurchaseWorkflow.steps.length; i++) ...[
          if (i > 0)
            Icon(Icons.chevron_right,
                size: 16, color: i <= rank ? colors.success : colors.border),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                width: i == rank ? 2 : 1,
                color: i <= rank
                    ? (i == rank ? colors.petrol : colors.success)
                    : colors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSelect == null
                  ? null
                  : () => onSelect!(PurchaseWorkflow.steps[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (i < rank)
                    Icon(Icons.check, size: 14, color: colors.success),
                  if (i < rank) const SizedBox(width: 4),
                  Text(
                    PurchaseWorkflow.label(PurchaseWorkflow.steps[i]),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == rank ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank < 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              PurchaseWorkflow.label(status),
              style:
                  TextStyle(color: colors.danger, fontWeight: FontWeight.w800),
            ),
          ),
        steps,
        if (onSelect != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Touchez une étape pour avancer ou revenir en arrière.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Pastille « trombone » : nombre de pièces jointes de l'achat ; un appui
/// ajoute un devis / une facture proforma du fournisseur (PDF ou photo).
class PurchaseAttachButton extends ConsumerWidget {
  const PurchaseAttachButton({super.key, required this.purchase});

  final Purchase purchase;

  Future<void> attach(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => DocumentFormDialog(
        purchaseId: purchase.id,
        projectId: purchase.projectId,
        initialCategory: 'proforma',
      ),
    );
    if (created == true) {
      await ref.read(purchasesRepositoryProvider).addEvent(
            companyId: purchase.companyId,
            purchaseId: purchase.id,
            kind: 'piece_jointe',
            comment: 'Devis / proforma fournisseur',
          );
      ref.invalidate(purchaseDocumentsProvider(purchase.id));
      ref.invalidate(purchaseEventsProvider(purchase.id));
      ref.invalidate(activeDocumentsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(purchaseDocumentsProvider(purchase.id)).value?.length ?? 0;
    final colors = context.palette;
    return Tooltip(
      message: count == 0
          ? 'Joindre le devis / la proforma du fournisseur'
          : '$count pièce(s) jointe(s) — en ajouter une',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => attach(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: count == 0
                ? colors.surfaceAlt
                : colors.success.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: count == 0 ? colors.border : colors.success),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.attach_file,
                size: 16, color: count == 0 ? colors.textSoft : colors.success),
            const SizedBox(width: 4),
            Text(
              count == 0 ? 'Joindre proforma' : '$count',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Historique du suivi et ajout d'un commentaire (ex. « fournisseur
/// relancé », « prix revu à la baisse »).
class PurchaseTimeline extends ConsumerStatefulWidget {
  const PurchaseTimeline({
    super.key,
    required this.purchase,
    this.showTitle = true,
  });

  final Purchase purchase;

  /// Titre masqué quand la section a déjà son propre cadre titré.
  final bool showTitle;

  @override
  ConsumerState<PurchaseTimeline> createState() => _PurchaseTimelineState();
}

class _PurchaseTimelineState extends ConsumerState<PurchaseTimeline> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    await ref.read(purchasesRepositoryProvider).addEvent(
          companyId: widget.purchase.companyId,
          purchaseId: widget.purchase.id,
          kind: 'commentaire',
          comment: text,
        );
    _comment.clear();
    ref.invalidate(purchaseEventsProvider(widget.purchase.id));
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final stamp = DateFormat('dd/MM/yyyy HH:mm');
    final events = ref.watch(purchaseEventsProvider(widget.purchase.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text('Suivi de l’achat',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
        ],
        events.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(
            '$error'.contains('purchase_events')
                ? 'Historique non activé (script SQL v2.1).'
                : 'Historique indisponible.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          data: (list) => list.isEmpty
              ? Text('Aucun évènement pour l’instant.',
                  style: Theme.of(context).textTheme.bodySmall)
              : Column(children: [
                  for (final e in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_iconFor(e.kind),
                              size: 18, color: colors.petrol),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                text: e.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              if (e.comment.isNotEmpty)
                                TextSpan(text: ' — ${e.comment}'),
                              TextSpan(
                                text: '\n${stamp.format(e.createdAt.toLocal())}'
                                    '${e.actorName.isEmpty ? '' : ' · ${e.actorName}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ])),
                          ),
                        ],
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _comment,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Ajouter un commentaire au suivi…',
                prefixIcon: Icon(Icons.comment_outlined),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ajouter',
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_outlined),
          ),
        ]),
      ],
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'creation' => Icons.flag_outlined,
        'statut' => Icons.timeline,
        'modification' => Icons.edit_note_outlined,
        'piece_jointe' => Icons.attach_file,
        _ => Icons.comment_outlined,
      };
}

/// Imprime l'état complet de l'achat avec ses pièces jointes.
Future<void> printPurchaseState(
  BuildContext context,
  WidgetRef ref, {
  required Purchase purchase,
  required String projectName,
}) async {
  try {
    final repo = ref.read(purchasesRepositoryProvider);
    final documentsRepo = ref.read(documentsRepositoryProvider);
    final items = await repo.fetchPurchaseItems(purchase.id);
    List<PurchaseEvent> events;
    try {
      events = await repo.fetchEvents(purchase.id);
    } catch (_) {
      events = const [];
    }
    final docs = await documentsRepo.fetchPurchaseDocuments(purchase.id);
    final attachments = <(ProjectDocument, Uint8List?)>[];
    for (final doc in docs) {
      Uint8List? bytes;
      try {
        bytes = await documentsRepo.downloadBytes(doc);
      } catch (_) {
        bytes = null;
      }
      attachments.add((doc, bytes));
    }
    final company = await ref.read(currentCompanyProvider.future);
    final logo = await PdfLetterhead.fetchLogoBytes(company);
    final suppliers = [
      ...await ref.read(activeSuppliersProvider.future),
      ...await ref.read(archivedSuppliersProvider.future),
    ];
    await PurchasePdfService().printPurchaseState(
      purchase: purchase,
      projectName: projectName,
      items: items,
      events: events,
      attachments: attachments,
      company: company,
      logoBytes: logo,
      supplier: suppliers.where((s) => s.id == purchase.supplierId).firstOrNull,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur état de l’achat : $error')),
      );
    }
  }
}
