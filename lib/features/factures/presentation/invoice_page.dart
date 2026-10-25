import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/project_invoice.dart';
import '../../../core/services/pdf_letterhead.dart';
import '../../../core/utils/number_input.dart';
import '../../../shared/presentation/party_pickers.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../devis/presentation/providers/devis_providers.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../../settings/presentation/providers/clients_providers.dart';
import '../../settings/presentation/providers/company_providers.dart';
import '../../settings/presentation/providers/tax_rates_providers.dart';
import '../services/invoice_pdf_service.dart';
import 'providers/invoices_providers.dart';

/// Création / modification d'une facture. Depuis un devis ([fromQuoteId]),
/// les lignes, le client et l'objet sont repris automatiquement.
class InvoicePage extends ConsumerStatefulWidget {
  const InvoicePage({super.key, this.invoiceId, this.fromQuoteId});

  final String? invoiceId;
  final String? fromQuoteId;

  @override
  ConsumerState<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends ConsumerState<InvoicePage> {
  final _title = TextEditingController(text: 'Facture');
  final _paid = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _taxRate = TextEditingController(text: '19');
  final List<_LineDraft> _lines = [];

  ProjectInvoice? _invoice;
  String? _projectId;
  String? _quoteId;
  String? _clientId;
  bool _clientChosen = false;
  String _status = 'emise';
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 30));

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _paid.dispose();
    _notes.dispose();
    _taxRate.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final invoices = ref.read(invoicesRepositoryProvider);
      if (widget.invoiceId != null) {
        final invoice = await invoices.fetchInvoiceById(widget.invoiceId!);
        if (invoice == null) {
          throw StateError('Facture introuvable.');
        }
        final items = await invoices.fetchInvoiceItems(invoice.id);
        _invoice = invoice;
        _projectId = invoice.projectId;
        _quoteId = invoice.quoteId;
        _clientId = invoice.clientId;
        _clientChosen = true;
        _status = invoice.status == 'brouillon' || invoice.status == 'annulee'
            ? invoice.status
            : 'emise';
        _issueDate = invoice.issueDate;
        _dueDate = invoice.dueDate;
        _title.text = invoice.title;
        _paid.text = formatDecimal(invoice.amountPaid, maxDecimals: 2);
        _notes.text = invoice.notes;
        _taxRate.text = formatDecimal(invoice.taxRate, maxDecimals: 2);
        _lines.addAll(items.map(_LineDraft.fromItem));
      } else {
        final defaultRate = (await ref.read(activeTaxRatesProvider.future))
            .where((t) => t.isDefault)
            .map((t) => t.rate)
            .firstOrNull;
        if (defaultRate != null) {
          _taxRate.text = formatDecimal(defaultRate, maxDecimals: 2);
        }
        if (widget.fromQuoteId != null) {
          final devis = ref.read(devisRepositoryProvider);
          final quote = await devis.fetchQuoteById(widget.fromQuoteId!);
          if (quote == null) {
            throw StateError('Devis introuvable.');
          }
          final items = await devis.fetchQuoteItems(quote.id);
          _projectId = quote.projectId;
          _quoteId = quote.id;
          _clientId = quote.clientId;
          _clientChosen = quote.clientId != null;
          _title.text = 'Facture — ${quote.title}';
          _lines.addAll(items.map((i) => _LineDraft(
                label: i.label,
                quantity: formatDecimal(i.quantity),
                unit: i.unit,
                unitPrice: formatDecimal(i.unitPrice, maxDecimals: 2),
              )));
        } else {
          _projectId = (await ref.read(selectedProjectProvider.future))?.id;
        }
        if (_lines.isEmpty) {
          _lines.add(_LineDraft());
        }
      }
    } catch (error) {
      _error = '$error';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<InvoiceLineItem> get _items => [
        for (final l in _lines)
          if (l.label.text.trim().isNotEmpty)
            InvoiceLineItem(
              label: l.label.text.trim(),
              quantity: parseDecimal(l.quantity.text) ?? 0,
              unit: l.unit.text.trim().isEmpty ? 'u' : l.unit.text.trim(),
              unitPrice: parseDecimal(l.unitPrice.text) ?? 0,
            ),
      ];

  InvoiceTotals get _totals => InvoiceTotals(
        _items,
        parseDecimal(_taxRate.text) ?? 0,
        parseDecimal(_paid.text) ?? 0,
      );

  /// Première saisie invalide (texte non numérique) ou null.
  String? _validate() {
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.label.text.trim().isEmpty) {
        continue;
      }
      if (parseDecimal(l.quantity.text) == null ||
          parseDecimal(l.unitPrice.text) == null) {
        return 'Ligne ${i + 1} : quantité ou prix invalide.';
      }
    }
    if (_items.isEmpty) {
      return 'Ajoute au moins une ligne.';
    }
    final rate = parseDecimal(_taxRate.text);
    if (rate == null || rate < 0 || rate > 100) {
      return 'Taux de TVA invalide.';
    }
    final paid = parseDecimal(_paid.text);
    if (paid == null || paid < 0) {
      return 'Montant réglé invalide.';
    }
    return null;
  }

  ProjectInvoice _buildInvoice({required String companyId, String? createdBy}) {
    final totals = _totals;
    final status =
        InvoiceTotals.statusFor(_status, totals.ttc, totals.amountPaid);
    final now = DateTime.now();
    return ProjectInvoice(
      id: _invoice?.id ?? '',
      companyId: _invoice?.companyId ?? companyId,
      projectId: _projectId!,
      quoteId: _quoteId,
      clientId: _clientId,
      number: _invoice?.number ?? '',
      title: _title.text.trim().isEmpty ? 'Facture' : _title.text.trim(),
      status: status,
      issueDate: _issueDate,
      dueDate: _dueDate,
      taxRate: totals.rate,
      amountPaid: totals.amountPaid,
      notes: _notes.text.trim(),
      createdBy: _invoice?.createdBy ?? createdBy,
      createdAt: _invoice?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<ProjectInvoice?> _save({bool quiet = false}) async {
    if (_saving) {
      return null;
    }
    final problem = _validate();
    if (problem != null) {
      _snack(problem);
      return null;
    }
    setState(() => _saving = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null || _projectId == null) {
        throw StateError('Profil ou chantier introuvable.');
      }
      final repo = ref.read(invoicesRepositoryProvider);
      var invoice =
          _buildInvoice(companyId: profile.companyId, createdBy: profile.id);
      final ProjectInvoice saved;
      if (_invoice == null) {
        invoice = invoice.copyWith(
          number: await repo.nextNumber(invoice.companyId, _issueDate.year),
        );
        saved = await repo.createInvoice(invoice, _items);
      } else {
        saved = await repo.updateInvoice(invoice, _items);
      }
      ref.invalidate(projectInvoicesProvider(saved.projectId));
      if (mounted) {
        setState(() => _invoice = saved);
        if (!quiet) {
          _snack('Facture ${saved.number} enregistrée.');
        }
      }
      return saved;
    } catch (error) {
      _snack('Erreur enregistrement : $error');
      return null;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pdf({required bool share}) async {
    final saved = await _save(quiet: true);
    if (saved == null) {
      return;
    }
    try {
      final company = await ref.read(currentCompanyProvider.future);
      final logo = await PdfLetterhead.fetchLogoBytes(company);
      final project =
          await ref.read(projectByIdProvider(saved.projectId).future);
      final clients = await ref.read(activeClientsProvider.future);
      final archived = await ref.read(archivedClientsProvider.future);
      final client = [...clients, ...archived]
          .where((c) => c.id == (saved.clientId ?? project?.clientId))
          .firstOrNull;
      final service = InvoicePdfService();
      final bytes = await service.buildInvoicePdf(
        invoice: saved,
        items: _items,
        projectName: project?.name ?? '',
        projectLocation: project?.location,
        client: client,
        fallbackClientName: project?.clientName,
        company: company,
        logoBytes: logo,
      );
      share
          ? await service.shareInvoice(bytes, saved)
          : await service.printInvoice(bytes, saved);
    } catch (error) {
      _snack('Erreur PDF : $error');
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? _issueDate) : _issueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => due ? _dueDate = picked : _issueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _invoice == null ? 'Nouvelle facture' : _invoice!.number;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Imprimer / PDF',
            onPressed: _loading || _saving ? null : () => _pdf(share: false),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Partager le PDF',
            onPressed: _loading || _saving ? null : () => _pdf(share: true),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final projectId = _projectId;
    if (projectId == null) {
      return const Center(child: Text('Choisis d’abord un chantier.'));
    }
    final project = ref.watch(projectByIdProvider(projectId)).value;
    final effectiveClientId =
        _clientChosen ? _clientId : (_clientId ?? project?.clientId);
    final totals = _totals;
    final colors = context.palette;
    final money = NumberFormat('#,##0.00', 'fr_FR');
    final day = DateFormat('dd/MM/yyyy');
    final status =
        InvoiceTotals.statusFor(_status, totals.ttc, totals.amountPaid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumHeroHeader(
          title: _invoice?.number ?? 'Nouvelle facture',
          subtitle: [
            project?.name ?? '',
            ProjectInvoice.statusLabel(status),
            if (_quoteId != null) 'issue d’un devis',
          ].where((e) => e.isNotEmpty).join(' · '),
          trailing: Text(
            '${money.format(totals.ttc)} DA TTC',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: heroForeground(context),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(title: 'Client et dates'),
              const SizedBox(height: 12),
              ClientPickerField(
                label: 'Client facturé',
                value: effectiveClientId,
                onChanged: (id, _) => setState(() {
                  _clientId = id;
                  _clientChosen = true;
                }),
              ),
              if (effectiveClientId == null &&
                  (project?.clientName.trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Sans fiche choisie, le PDF affichera « ${project!.clientName} ».',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Objet de la facture',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(due: false),
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Émise le ${day.format(_issueDate)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(due: true),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(_dueDate == null
                        ? 'Échéance : à réception'
                        : 'Échéance ${day.format(_dueDate!)}'),
                  ),
                  if (_dueDate != null)
                    TextButton(
                      onPressed: () => setState(() => _dueDate = null),
                      child: const Text('Payable à réception'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'État',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'brouillon', child: Text('Brouillon')),
                        DropdownMenuItem(
                            value: 'emise',
                            child: Text('Émise (suivi des paiements)')),
                        DropdownMenuItem(
                            value: 'annulee', child: Text('Annulée')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'emise'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _taxRate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'TVA %',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumSectionHeader(
                title: 'Lignes facturées',
                subtitle: '${_items.length} ligne(s) · montants HT',
                trailing: FilledButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Ligne'),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _lines.length; i++)
                _LineEditor(
                  key: ObjectKey(_lines[i]),
                  draft: _lines[i],
                  index: i,
                  onChanged: () => setState(() {}),
                  onRemove: _lines.length == 1
                      ? null
                      : () => setState(() => _lines.removeAt(i).dispose()),
                ),
              const Divider(height: 24),
              _TotalRow('Total HT', money.format(totals.ht)),
              _TotalRow('TVA ${formatDecimal(totals.rate, maxDecimals: 2)} %',
                  money.format(totals.tax)),
              _TotalRow('Total TTC', money.format(totals.ttc), strong: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(title: 'Règlement'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _paid,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Montant déjà réglé (DA)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() =>
                        _paid.text = formatDecimal(totals.ttc, maxDecimals: 2)),
                    child: const Text('Tout est réglé'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reste à payer : ${money.format(totals.remaining)} DA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      totals.remaining > 0.005 ? colors.danger : colors.success,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mentions / conditions (imprimées sur la facture)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(),
          icon: _saving
              ? const PremiumButtonProgress()
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer la facture'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text('$value DA', style: style),
      ]),
    );
  }
}

class _LineDraft {
  _LineDraft({
    String label = '',
    String quantity = '1',
    String unit = 'u',
    String unitPrice = '0',
  })  : label = TextEditingController(text: label),
        quantity = TextEditingController(text: quantity),
        unit = TextEditingController(text: unit),
        unitPrice = TextEditingController(text: unitPrice);

  factory _LineDraft.fromItem(InvoiceLineItem item) => _LineDraft(
        label: item.label,
        quantity: formatDecimal(item.quantity),
        unit: item.unit,
        unitPrice: formatDecimal(item.unitPrice, maxDecimals: 2),
      );

  final TextEditingController label;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;

  void dispose() {
    label.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final qty = parseDecimal(draft.quantity.text);
    final pu = parseDecimal(draft.unitPrice.text);
    final total = (qty ?? 0) * (pu ?? 0);
    const numeric = TextInputType.numberWithOptions(decimal: true);
    Widget field(TextEditingController c, String label,
            {TextInputType? type, bool invalid = false}) =>
        TextField(
          controller: c,
          keyboardType: type,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            errorText: invalid ? 'Nombre invalide' : null,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 640;
        final numbers = [
          Expanded(
              child: field(draft.quantity, 'Qté',
                  type: numeric, invalid: qty == null)),
          const SizedBox(width: 8),
          Expanded(child: field(draft.unit, 'Unité')),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: field(draft.unitPrice, 'PU HT',
                  type: numeric, invalid: pu == null)),
        ];
        final header = Row(children: [
          Text('Ligne ${index + 1}',
              style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Text('${NumberFormat('#,##0.00', 'fr_FR').format(total)} DA',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          if (onRemove != null)
            IconButton(
              tooltip: 'Supprimer la ligne',
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline, color: colors.danger),
            ),
        ]);
        return Column(children: [
          header,
          if (wide)
            Row(children: [
              Expanded(flex: 3, child: field(draft.label, 'Désignation')),
              const SizedBox(width: 8),
              ...numbers,
            ])
          else ...[
            field(draft.label, 'Désignation'),
            const SizedBox(height: 8),
            Row(children: numbers),
          ],
        ]);
      }),
    );
  }
}
