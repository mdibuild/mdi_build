import 'package:flutter/material.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/models/purchase_item.dart';
import '../purchase_documents_section.dart';

class PurchaseFormValue {
  const PurchaseFormValue({
    required this.title,
    required this.projectId,
    required this.lot,
    required this.notes,
    required this.items,
  });

  final String title;
  final String projectId;
  final String lot;
  final String notes;
  final List<PurchaseItem> items;
}

class PurchaseForm extends StatefulWidget {
  const PurchaseForm({
    super.key,
    required this.projectOptions,
    this.initialPurchase,
    this.initialItems = const [],
    required this.onSubmit,
  });

  final List<DropdownMenuItem<String>> projectOptions;
  final Purchase? initialPurchase;
  final List<PurchaseItem> initialItems;
  final Future<void> Function(PurchaseFormValue value) onSubmit;

  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  late final TextEditingController titleController;
  late final TextEditingController lotController;
  late final TextEditingController notesController;

  String? selectedProjectId;
  bool saving = false;

  late List<_PurchaseItemDraft> items;

  bool get isEditing => widget.initialPurchase != null;

  String? get editingPurchaseId {
    final id = widget.initialPurchase?.id;
    if ((id ?? '').trim().isEmpty) {
      return null;
    }
    return id;
  }

  @override
  void initState() {
    super.initState();

    final purchase = widget.initialPurchase;

    titleController = TextEditingController(text: purchase?.title ?? '');
    lotController = TextEditingController(text: purchase?.lot ?? '');
    notesController = TextEditingController(text: purchase?.notes ?? '');
    selectedProjectId = purchase?.projectId;

    if (widget.initialItems.isEmpty) {
      items = [_PurchaseItemDraft.empty()];
    } else {
      items = widget.initialItems
          .map(
            (item) => _PurchaseItemDraft(
              article: item.article,
              description: item.description,
              quantity: item.quantity.toString(),
              unit: item.unit,
              unitPrice: item.unitPrice.toString(),
              notes: item.notes,
            ),
          )
          .toList();
    }
  }

  void addItem() {
    setState(() {
      items.add(_PurchaseItemDraft.empty());
    });
  }

  void removeItem(int index) {
    if (items.length == 1) {
      return;
    }

    setState(() {
      final item = items.removeAt(index);
      item.dispose();
    });
  }

  double get estimatedTotal {
    return items.fold<double>(0, (sum, item) {
      final quantity =
          double.tryParse(item.quantityController.text.trim()) ?? 0;
      final unitPrice =
          double.tryParse(item.unitPriceController.text.trim()) ?? 0;
      return sum + (quantity * unitPrice);
    });
  }

  Future<void> submit() async {
    if (saving) {
      return;
    }

    final title = titleController.text.trim();
    final lot = lotController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saisis le titre de lÃƒÂ¢DAÃ¢âDAžÂ¢achat.')),
      );
      return;
    }

    if ((selectedProjectId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un projet.')),
      );
      return;
    }

    if (lot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saisis le lot / corps dÃƒÂ¢DAÃ¢âDAžÂ¢ÃƒÆ’Ã‚Â©tat.')),
      );
      return;
    }

    final mappedItems = items
        .asMap()
        .entries
        .map(
          (entry) => PurchaseItem(
            id: '',
            purchaseId: '',
            article: entry.value.articleController.text.trim(),
            description: entry.value.descriptionController.text.trim(),
            quantity:
                double.tryParse(entry.value.quantityController.text.trim()) ??
                    0,
            unit: entry.value.unitController.text.trim().isEmpty
                ? 'u'
                : entry.value.unitController.text.trim(),
            unitPrice:
                double.tryParse(entry.value.unitPriceController.text.trim()) ??
                    0,
            notes: entry.value.notesController.text.trim(),
            sortOrder: entry.key,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )
        .where((item) => item.article.isNotEmpty)
        .toList();

    if (mappedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un article.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await widget.onSubmit(
        PurchaseFormValue(
          title: title,
          projectId: selectedProjectId!,
          lot: lot,
          notes: notesController.text.trim(),
          items: mappedItems,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    lotController.dispose();
    notesController.dispose();

    for (final item in items) {
      item.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          'Informations gÃƒÆ’Ã‚Â©nÃƒÆ’Ã‚Â©rales',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Titre de lÃƒÂ¢DAÃ¢âDAžÂ¢achat',
            prefixIcon: Icon(Icons.title_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedProjectId,
          items: widget.projectOptions,
          onChanged: (value) {
            setState(() => selectedProjectId = value);
          },
          decoration: const InputDecoration(
            labelText: 'Projet',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: lotController,
          decoration: const InputDecoration(
            labelText: 'Lot / corps dÃƒÂ¢DAÃ¢âDAžÂ¢ÃƒÆ’Ã‚Â©tat',
            prefixIcon: Icon(Icons.work_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Observations',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Articles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: addItem,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int index = 0; index < items.length; index++) ...[
          _PurchaseItemDraftCard(
            draft: items[index],
            index: index,
            canRemove: items.length > 1,
            onRemove: () => removeItem(index),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total estimatif',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text('CalculÃƒÆ’Ã‚Â© ÃƒÆ’Ã‚Â  partir des lignes saisies'),
                    ],
                  ),
                ),
                Text(
                  estimatedTotal.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (editingPurchaseId != null)
          PurchaseDocumentsSection(purchaseId: editingPurchaseId!)
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enregistre dÃƒÂ¢DAÃ¢âDAžÂ¢abord lÃƒÂ¢DAÃ¢âDAžÂ¢achat, puis rouvre-le pour ajouter des documents liÃƒÆ’Ã‚Â©s.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: saving ? null : submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}

class _PurchaseItemDraft {
  _PurchaseItemDraft({
    required String article,
    required String description,
    required String quantity,
    required String unit,
    required String unitPrice,
    required String notes,
  })  : articleController = TextEditingController(text: article),
        descriptionController = TextEditingController(text: description),
        quantityController = TextEditingController(text: quantity),
        unitController = TextEditingController(text: unit),
        unitPriceController = TextEditingController(text: unitPrice),
        notesController = TextEditingController(text: notes);

  factory _PurchaseItemDraft.empty() {
    return _PurchaseItemDraft(
      article: '',
      description: '',
      quantity: '0',
      unit: 'u',
      unitPrice: '0',
      notes: '',
    );
  }

  final TextEditingController articleController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController unitPriceController;
  final TextEditingController notesController;

  void dispose() {
    articleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    unitPriceController.dispose();
    notesController.dispose();
  }
}

class _PurchaseItemDraftCard extends StatelessWidget {
  const _PurchaseItemDraftCard({
    required this.draft,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _PurchaseItemDraft draft;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final subtotal =
        ((double.tryParse(draft.quantityController.text.trim()) ?? 0) *
                (double.tryParse(draft.unitPriceController.text.trim()) ?? 0))
            .toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Article ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.articleController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Article',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.descriptionController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.quantityController,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'QuantitÃƒÆ’Ã‚Â©',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: draft.unitController,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'UnitÃƒÆ’Ã‚Â©',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.unitPriceController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Prix unitaire',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.notesController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Remarque',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Sous-total : $subtotal',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
