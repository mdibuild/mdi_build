import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/client.dart';
import '../../../core/models/project.dart';
import '../../../core/models/project_invoice.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../settings/presentation/providers/clients_providers.dart';
import 'providers/invoices_providers.dart';
import '../../../shared/presentation/signature_icon.dart';
import '../../projects/presentation/providers/project_scope_provider.dart';
import '../../projects/presentation/providers/projects_providers.dart';

/// Onglet « Factures » du module Devis & Factures : suivi des montants
/// facturés, réglés et restant dus du chantier.
class InvoicesTab extends ConsumerStatefulWidget {
  const InvoicesTab({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<InvoicesTab> {
  String _query = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final all = ref.watch(projectScopeAllProvider);
    final dataAsync = ref.watch(scopedInvoicesProvider);
    final projectNames = {
      for (final p in ref.watch(projectsProvider).value ?? const [])
        p.id: p.name,
    };
    final clients = <String, Client>{
      for (final c in [
        ...?ref.watch(archivedClientsProvider).value,
        ...?ref.watch(activeClientsProvider).value,
      ])
        c.id: c,
    };
    final money = NumberFormat('#,##0.00', 'fr_FR');

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TableMissing(error: error),
      data: (data) {
        String clientOf(ProjectInvoice i) =>
            clients[i.clientId ?? project.clientId]?.name ?? project.clientName;
        final query = _query.trim().toLowerCase();
        final filtered = data.invoices.where((i) {
          final text =
              '${i.number} ${i.title} ${clientOf(i)} ${ProjectInvoice.statusLabel(i.status)}'
                  .toLowerCase();
          final overdue = i.isOverdue(data.totalsOf(i).ttc);
          return (query.isEmpty || text.contains(query)) &&
              (_status == 'all' ||
                  (_status == 'retard' ? overdue : i.status == _status));
        }).toList();

        var billed = 0.0;
        var paid = 0.0;
        var overdueCount = 0;
        for (final i in data.invoices
            .where((i) => i.status != 'annulee' && i.status != 'brouillon')) {
          final t = data.totalsOf(i);
          billed += t.ttc;
          paid += i.amountPaid;
          if (i.isOverdue(t.ttc)) {
            overdueCount++;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PremiumHeroHeader(
              title: 'Factures',
              subtitle: all
                  ? 'Tous les projets · nouvelle facture sur ${project.name}'
                  : 'Chantier : ${project.name}',
              trailing: FilledButton.icon(
                onPressed: () => context.push('/factures/new'),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle facture'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Kpi(
                    icon: Icons.receipt_long_outlined,
                    label: 'Facturé TTC',
                    value: '${money.format(billed)} DA'),
                _Kpi(
                    icon: Icons.payments_outlined,
                    label: 'Encaissé',
                    value: '${money.format(paid)} DA'),
                _Kpi(
                    icon: Icons.hourglass_bottom_outlined,
                    label: 'Reste dû',
                    value:
                        '${money.format((billed - paid).clamp(0, double.infinity))} DA'),
                _Kpi(
                    icon: Icons.warning_amber_outlined,
                    label: 'En retard',
                    value: '$overdueCount',
                    alert: overdueCount > 0),
              ],
            ),
            const SizedBox(height: 16),
            ModuleFilterBar(
              searchQuery: _query,
              onSearchChanged: (v) => setState(() => _query = v),
              searchHint: 'Numéro, objet, client…',
              resultLabel:
                  '${filtered.length} facture(s) sur ${data.invoices.length}',
              onReset: () => setState(() {
                _query = '';
                _status = 'all';
              }),
              filters: [
                ModuleFilterDropdown<String>(
                  value: _status,
                  label: 'État',
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Tous les états')),
                    for (final s in ProjectInvoice.statuses)
                      DropdownMenuItem(
                          value: s, child: Text(ProjectInvoice.statusLabel(s))),
                    const DropdownMenuItem(
                        value: 'retard', child: Text('En retard')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              PremiumSurfaceCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    data.invoices.isEmpty
                        ? 'Aucune facture pour ce chantier. Crée-la ici ou '
                            'depuis un devis signé (bouton « Facturer »).'
                        : 'Aucune facture ne correspond aux filtres.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final invoice in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InvoiceCard(
                    invoice: invoice,
                    totals: data.totalsOf(invoice),
                    clientName: clientOf(invoice),
                    projectName: all ? projectNames[invoice.projectId] : null,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final accent = alert ? colors.danger : colors.petrol;
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alert ? colors.danger : colors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SignatureIcon(icon, size: 34, highlighted: alert),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w900, color: accent)),
        ]),
      ]),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.totals,
    required this.clientName,
    this.projectName,
  });

  final ProjectInvoice invoice;
  final String? projectName;
  final InvoiceTotals totals;
  final String clientName;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final money = NumberFormat('#,##0.00', 'fr_FR');
    final day = DateFormat('dd/MM/yyyy');
    final overdue = invoice.isOverdue(totals.ttc);
    final color = overdue
        ? colors.danger
        : switch (invoice.status) {
            'payee' => colors.success,
            'partielle' => colors.info,
            'annulee' => colors.danger,
            'brouillon' => colors.textSoft,
            _ => colors.petrol,
          };
    final ratio = totals.ttc <= 0
        ? 0.0
        : (invoice.amountPaid / totals.ttc).clamp(0.0, 1.0);

    return PremiumSurfaceCard(
      onTap: () => context.push('/factures/${invoice.id}/edit'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '${invoice.number} · ${invoice.title}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            PremiumStatusBadge(
              label: overdue
                  ? 'En retard'
                  : ProjectInvoice.statusLabel(invoice.status),
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            [
              if (projectName != null) projectName!,
              if (clientName.trim().isNotEmpty) clientName,
              'émise le ${day.format(invoice.issueDate)}',
              invoice.dueDate == null
                  ? 'payable à réception'
                  : 'échéance ${day.format(invoice.dueDate!)}',
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: colors.border,
              color: colors.success,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 4, children: [
            Text('TTC ${money.format(totals.ttc)} DA',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Réglé ${money.format(invoice.amountPaid)} DA'),
            Text(
              'Reste ${money.format(totals.remaining)} DA',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color:
                    totals.remaining > 0.005 ? colors.danger : colors.success,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Message clair si la table des factures n'existe pas encore en base.
class _TableMissing extends StatelessWidget {
  const _TableMissing({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final text = '$error';
    final missing = text.contains('project_invoices') ||
        text.contains('42P01') ||
        text.contains('PGRST205');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          missing
              ? 'La facturation n’est pas encore activée dans la base de '
                  'données (script SQL 2026_invoices_checklist_realtime.sql).'
              : 'Factures indisponibles : $text',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
