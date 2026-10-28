import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette_colors.dart';
import '../../../../core/models/project.dart';
import '../../../../core/models/project_document.dart';
import '../../../../core/services/pdf_letterhead.dart';
import '../../../../core/services/quantity_service.dart';
import '../../../../shared/presentation/project_selector_card.dart';
import '../../../planning/presentation/gantt_view.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../../settings/presentation/providers/clients_providers.dart';
import '../../../settings/presentation/providers/company_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/providers/suppliers_providers.dart';
import '../../analysis/report_analysis.dart';
import '../../analysis/report_analysis_export.dart';
import 'report_analysis_providers.dart';
import '../../../planning/presentation/gantt_print.dart';

/// Onglet « Analyse » du module Rapports : parcours Module → Projet →
/// Période → Filtres, puis synthèse, graphiques et détail exhaustif.
class ReportAnalysisTab extends ConsumerStatefulWidget {
  const ReportAnalysisTab({super.key});

  @override
  ConsumerState<ReportAnalysisTab> createState() => _ReportAnalysisTabState();
}

class _ReportAnalysisTabState extends ConsumerState<ReportAnalysisTab> {
  final _searchController = TextEditingController();

  ReportModule _module = ReportModule.achats;
  ReportPeriod _period = ReportPeriod.preset(ReportPeriodPreset.thisMonth);
  String _query = '';
  PurchaseSort _purchaseSort = PurchaseSort.dateDesc;

  /// Filtres complémentaires (null = tous).
  Set<String>? _purchaseStatuses;
  Set<String>? _quoteStatuses;
  Set<TaskReportState>? _taskStates;
  Set<String>? _documentCategories;

  bool _exporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _purchaseStatuses = null;
      _quoteStatuses = null;
      _taskStates = null;
      _documentCategories = null;
    });
  }

  Future<void> _pickCustomPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _period.start != null && _period.end != null
          ? DateTimeRange(start: _period.start!, end: _period.end!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: dateOnly(now),
            ),
      helpText: 'Période du rapport',
      saveText: 'Appliquer',
    );
    if (range != null) {
      setState(() => _period = ReportPeriod.custom(range.start, range.end));
    }
  }

  void _refreshData(String projectId) {
    ref.invalidate(reportPurchasesDataProvider(projectId));
    ref.invalidate(reportQuotesDataProvider(projectId));
    ref.invalidate(reportPlanningDataProvider(projectId));
    ref.invalidate(reportDocumentsDataProvider(projectId));
    ref.invalidate(reportSpacesDataProvider(projectId));
  }

  /// Filtres complémentaires actifs, en clair (affichés et exportés).
  List<String> _activeFilterLabels() {
    final list = <String>[];
    switch (_module) {
      case ReportModule.achats:
        if (_purchaseStatuses != null) {
          list.add('Statuts : ${_purchaseStatuses!.map(purchaseStatusLabel).join(', ')}');
        }
      case ReportModule.devis:
        if (_quoteStatuses != null) {
          list.add('Statuts : ${_quoteStatuses!.map(quoteStatusLabel).join(', ')}');
        }
      case ReportModule.planning:
        if (_taskStates != null) {
          list.add('États : ${_taskStates!.map((s) => s.label).join(', ')}');
        }
      case ReportModule.documents:
        if (_documentCategories != null) {
          list.add('Catégories : ${_documentCategories!.map(documentCategoryLabel).join(', ')}');
        }
      case ReportModule.metrage:
        break;
    }
    if (_query.trim().isNotEmpty) {
      list.add('Recherche : « ${_query.trim()} »');
    }
    return list;
  }

  /// Construit le rapport pour le module choisi (null pendant le chargement
  /// ou en cas d'erreur, alors renvoyés via [AsyncValue]).
  AsyncValue<AnalysisReport> _buildReport(Project project) {
    final filters = _activeFilterLabels();
    AnalysisReport base({
      PurchasesReport? purchases,
      QuotesReport? quotes,
      PlanningReport? planning,
      DocumentsReport? documents,
      MetrageReport? metrage,
    }) =>
        AnalysisReport(
          module: _module,
          projectName: project.name,
          period: _period,
          activeFilters: filters,
          generatedAt: DateTime.now(),
          purchases: purchases,
          quotes: quotes,
          planning: planning,
          documents: documents,
          metrage: metrage,
        );

    switch (_module) {
      case ReportModule.achats:
        // Fiches actives et archivées : un achat ancien garde son fournisseur.
        final supplierNames = <String, String>{
          for (final s in [
            ...?ref.watch(archivedSuppliersProvider).value,
            ...?ref.watch(activeSuppliersProvider).value,
          ])
            s.id: s.name,
        };
        return ref.watch(reportPurchasesDataProvider(project.id)).whenData(
              (d) => base(
                purchases: buildPurchasesReport(
                  purchases: d.purchases,
                  itemsByPurchase: d.itemsByPurchase,
                  period: _period,
                  statuses: _purchaseStatuses,
                  query: _query,
                  sort: _purchaseSort,
                  supplierNames: supplierNames,
                ),
              ),
            );
      case ReportModule.devis:
        final client = project.clientName.trim().isEmpty ? null : project.clientName.trim();
        final clientNames = <String, String>{
          for (final c in [
            ...?ref.watch(archivedClientsProvider).value,
            ...?ref.watch(activeClientsProvider).value,
          ])
            c.id: c.name,
        };
        return ref.watch(reportQuotesDataProvider(project.id)).whenData(
              (d) => base(
                quotes: buildQuotesReport(
                  quotes: d.quotes,
                  itemsByQuote: d.itemsByQuote,
                  period: _period,
                  clientName: client,
                  clientNames: clientNames,
                  projectClientId: project.clientId,
                  statuses: _quoteStatuses,
                  query: _query,
                ),
              ),
            );
      case ReportModule.planning:
        final profile = ref.watch(currentProfileProvider).value;
        final users = profile == null
            ? const <String, String>{}
            : <String, String>{
                for (final u in ref.watch(companyUsersProvider(profile.companyId)).value ?? [])
                  u.id: u.displayName,
              };
        return ref.watch(reportPlanningDataProvider(project.id)).whenData(
              (d) => base(
                planning: buildPlanningReport(
                  tasks: d.tasks,
                  dependencies: d.dependencies,
                  period: _period,
                  userNames: users,
                  today: DateTime.now(),
                  states: _taskStates,
                  query: _query,
                ),
              ),
            );
      case ReportModule.documents:
        return ref.watch(reportDocumentsDataProvider(project.id)).whenData(
              (d) => base(
                documents: buildDocumentsReport(
                  documents: d,
                  period: _period,
                  categories: _documentCategories,
                  query: _query,
                ),
              ),
            );
      case ReportModule.metrage:
        return ref.watch(reportSpacesDataProvider(project.id)).whenData(
              (spaces) => base(
                metrage: buildMetrageReport(
                  lines: QuantityService().buildLines(spaces),
                  query: _query,
                ),
              ),
            );
    }
  }

  Future<void> _exportPdf(AnalysisReport report) async {
    setState(() => _exporting = true);
    try {
      final company = await ref.read(currentCompanyProvider.future);
      final logo = await PdfLetterhead.fetchLogoBytes(company);
      await ReportAnalysisExport().printPdf(report, company: company, logoBytes: logo);
    } catch (error) {
      _snack('Erreur export PDF : $error');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _exportExcel(AnalysisReport report) async {
    setState(() => _exporting = true);
    try {
      final path = await ReportAnalysisExport().saveExcel(report);
      _snack(path == null ? 'Export Excel annulé.' : 'Excel enregistré${path.isEmpty ? '' : ' : $path'}');
    } catch (error) {
      _snack('Erreur export Excel : $error');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _snack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);

    return projectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _StateMessage(
        icon: Icons.error_outline,
        title: 'Projet indisponible',
        text: 'Le projet courant n’a pas pu être chargé : $e',
      ),
      data: (project) {
        if (project == null) {
          return const _StateMessage(
            icon: Icons.apartment_outlined,
            title: 'Aucun projet',
            text: 'Créez ou sélectionnez un projet dans le module Projets pour '
                'afficher des rapports.',
          );
        }
        final reportAsync = _buildReport(project);
        final report = reportAsync.value;

        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverList.list(
                children: [
                  _SetupCard(
                    module: _module,
                    projectId: project.id,
                    period: _period,
                    onModule: (m) => setState(() => _module = m),
                    onPreset: (p) {
                      if (p == ReportPeriodPreset.custom) {
                        _pickCustomPeriod();
                      } else {
                        setState(() => _period = ReportPeriod.preset(p));
                      }
                    },
                    onCustom: _pickCustomPeriod,
                    filters: _buildModuleFilters(reportAsync),
                    activeFilterCount: _activeFilterLabels()
                        .where((f) => !f.startsWith('Recherche'))
                        .length,
                    searchField: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: _searchHint,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer la recherche',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActiveFiltersBar(
                    module: _module,
                    projectName: project.name,
                    periodLabel: _module.usesPeriod ? _period.label : 'Sans période',
                    filters: _activeFilterLabels(),
                    onReset: _activeFilterLabels().isEmpty ? null : _resetFilters,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (reportAsync.isLoading && report == null)
              const SliverToBoxAdapter(
                child: _StateMessage(
                  icon: Icons.hourglass_top,
                  title: 'Chargement des données…',
                  text: 'Toutes les données du projet sont lues, sans limite '
                      'de nombre.',
                  busy: true,
                ),
              )
            else if (reportAsync.hasError && report == null)
              SliverToBoxAdapter(
                child: _StateMessage(
                  icon: Icons.cloud_off,
                  title: 'Impossible de charger les données',
                  text: '${reportAsync.error}\nVérifiez la connexion puis réessayez.',
                  action: FilledButton.icon(
                    onPressed: () => _refreshData(project.id),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ),
              )
            else if (report != null)
              ..._reportSlivers(context, report, project),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }

  String get _searchHint {
    switch (_module) {
      case ReportModule.achats:
        return 'Rechercher : achat, lot, article, remarque…';
      case ReportModule.planning:
        return 'Rechercher : tâche, phase, lot, responsable…';
      case ReportModule.devis:
        return 'Rechercher : devis, prestation, statut…';
      case ReportModule.documents:
        return 'Rechercher : titre, fichier, catégorie…';
      case ReportModule.metrage:
        return 'Rechercher : espace, type…';
    }
  }

  Widget? _buildModuleFilters(AsyncValue<AnalysisReport> reportAsync) {
    Widget chips<T>({
      required String title,
      required List<T> values,
      required Set<T>? selected,
      required String Function(T) label,
      required ValueChanged<Set<T>?> onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in values)
                FilterChip(
                  label: Text(label(v)),
                  selected: selected == null || selected.contains(v),
                  onSelected: (on) {
                    final next = {...(selected ?? values.toSet())};
                    on ? next.add(v) : next.remove(v);
                    onChanged(next.length == values.length ? null : next);
                  },
                ),
            ],
          ),
        ],
      );
    }

    switch (_module) {
      case ReportModule.achats:
        return chips<String>(
          title: 'Statuts d’achat',
          values: purchaseStatuses,
          selected: _purchaseStatuses,
          label: purchaseStatusLabel,
          onChanged: (s) => setState(() => _purchaseStatuses = s),
        );
      case ReportModule.devis:
        return chips<String>(
          title: 'Statuts de devis',
          values: const ['brouillon', 'envoye', 'signe', 'annule', 'archive'],
          selected: _quoteStatuses,
          label: quoteStatusLabel,
          onChanged: (s) => setState(() => _quoteStatuses = s),
        );
      case ReportModule.planning:
        return chips<TaskReportState>(
          title: 'États des tâches',
          values: TaskReportState.values,
          selected: _taskStates,
          label: (s) => s.label,
          onChanged: (s) => setState(() => _taskStates = s),
        );
      case ReportModule.documents:
        return chips<String>(
          title: 'Catégories',
          values: const ['plan', 'photo', 'facture', 'bon_commande', 'proforma', 'pv', 'rapport', 'autre'],
          selected: _documentCategories,
          label: documentCategoryLabel,
          onChanged: (s) => setState(() => _documentCategories = s),
        );
      case ReportModule.metrage:
        return null;
    }
  }

  List<Widget> _reportSlivers(BuildContext context, AnalysisReport report, Project project) {
    final colors = context.palette;
    const pad = EdgeInsets.symmetric(horizontal: 12);

    Widget box(Widget child) => SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: child),
        );

    final header = _ReportHeader(
      report: report,
      exporting: _exporting,
      onPdf: report.itemCount == 0 ? null : () => _exportPdf(report),
      onExcel: report.itemCount == 0 ? null : () => _exportExcel(report),
      onRefresh: () => _refreshData(project.id),
    );

    final slivers = <Widget>[
      box(header),
      box(const SizedBox(height: 12)),
      box(_Indicators(indicators: report.indicators)),
      box(const SizedBox(height: 12)),
      box(_Notes(notes: report.notes)),
      box(const SizedBox(height: 12)),
    ];

    if (report.itemCount == 0) {
      slivers.add(box(_StateMessage(
        icon: Icons.inbox_outlined,
        title: 'Aucun résultat',
        text: _module.usesPeriod
            ? 'Rien ne correspond à cette période et à ces filtres. Essayez '
                '« Depuis le début » ou retirez des filtres.'
            : 'Aucun élément ne correspond à la recherche.',
      )));
      return slivers;
    }

    for (final b in report.breakdowns.where((b) => b.entries.length > 1)) {
      slivers
        ..add(box(_BarChartCard(breakdown: b)))
        ..add(box(const SizedBox(height: 12)));
    }

    switch (report.module) {
      case ReportModule.achats:
        final r = report.purchases!;
        slivers.add(box(_DetailHeader(
          title: 'Détail des achats',
          count: r.count,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: DropdownButton<PurchaseSort>(
              value: _purchaseSort,
              isDense: true,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.sort),
              items: [
                for (final s in PurchaseSort.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (s) =>
                  setState(() => _purchaseSort = s ?? _purchaseSort),
            ),
          ),
        )));
        slivers.add(SliverPadding(
          padding: pad,
          sliver: SliverList.builder(
            itemCount: r.rows.length,
            itemBuilder: (_, i) => _PurchaseTile(row: r.rows[i]),
          ),
        ));
        slivers.add(box(_TotalCard(
          lines: [
            ('Total général connu', formatAmount(r.knownTotal)),
            if (r.withoutAmount > 0)
              ('Achats sans montant (exclus du total)', '${r.withoutAmount}'),
          ],
        )));
      case ReportModule.devis:
        final r = report.quotes!;
        slivers.add(box(_DetailHeader(title: 'Détail des devis', count: r.count)));
        slivers.add(SliverPadding(
          padding: pad,
          sliver: SliverList.builder(
            itemCount: r.rows.length,
            itemBuilder: (_, i) => _QuoteTile(row: r.rows[i]),
          ),
        ));
        slivers.add(box(_TotalCard(
          lines: [
            ('Total HT connu', formatAmount(r.knownHt)),
            ('TVA ${(quoteTaxRate * 100).round()} %', formatAmount(r.knownTtc - r.knownHt)),
            ('Total TTC connu', formatAmount(r.knownTtc)),
            if (r.withoutAmount > 0) ('Devis sans montant (exclus)', '${r.withoutAmount}'),
          ],
        )));
      case ReportModule.planning:
        final r = report.planning!;
        final today = DateTime.now();
        slivers.add(box(Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diagramme de Gantt', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${r.rows.length} tâche(s) datée(s) chevauchant la période. '
                  'Échelle jour / semaine / mois ; faites défiler horizontalement.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (r.rows.isEmpty)
                  const Text('Aucune tâche datée sur cette période.')
                else
                  GanttView(
                    tasks: [for (final row in r.rows) row.task],
                    dependencies: r.dependencies,
                    isLate: (task) => isTaskLate(task, today),
                  ),
                const SizedBox(height: 8),
                _Legend(colors: colors),
                if (r.rows.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      final company =
                          await ref.read(currentCompanyProvider.future);
                      if (!context.mounted) {
                        return;
                      }
                      await printFullGantt(
                        context,
                        rows: ganttRowsFromReport(r),
                        title: 'Gantt — ${project.name}',
                        subtitle: _period.label,
                        companyName: PdfLetterhead.companyName(company),
                      );
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimer le Gantt complet'),
                  ),
                ],
              ],
            ),
          ),
        )));
        slivers.add(box(const SizedBox(height: 12)));
        slivers.add(box(_DetailHeader(title: 'Détail des tâches', count: r.total)));
        slivers.add(SliverPadding(
          padding: pad,
          sliver: SliverList.builder(
            itemCount: r.rows.length,
            itemBuilder: (_, i) => _TaskTile(row: r.rows[i]),
          ),
        ));
        if (r.undatedRows.isNotEmpty) {
          slivers.add(box(Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Tâches sans dates prévues (${r.undatedRows.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          )));
          slivers.add(SliverPadding(
            padding: pad,
            sliver: SliverList.builder(
              itemCount: r.undatedRows.length,
              itemBuilder: (_, i) => _TaskTile(row: r.undatedRows[i]),
            ),
          ));
        }
      case ReportModule.documents:
        final r = report.documents!;
        slivers.add(box(_DetailHeader(title: 'Détail des documents', count: r.count)));
        slivers.add(SliverPadding(
          padding: pad,
          sliver: SliverList.builder(
            itemCount: r.rows.length,
            itemBuilder: (_, i) => _DocumentTile(doc: r.rows[i]),
          ),
        ));
      case ReportModule.metrage:
        final r = report.metrage!;
        slivers.add(box(_DetailHeader(title: 'Détail des espaces', count: r.count)));
        slivers.add(SliverPadding(
          padding: pad,
          sliver: SliverList.builder(
            itemCount: r.lines.length,
            itemBuilder: (_, i) {
              final l = r.lines[i];
              return _RowCard(
                title: l.spaceName,
                subtitle: l.spaceType,
                lines: [
                  'Sol ${formatQuantity(l.floorArea)} m² · Plafond ${formatQuantity(l.ceilingArea)} m²',
                  'Murs bruts ${formatQuantity(l.grossWallArea)} m² − ouvertures '
                      '${formatQuantity(l.openingsArea)} m² = murs nets ${formatQuantity(l.netWallArea)} m²',
                  'Périmètre ${formatQuantity(l.perimeter)} m',
                ],
              );
            },
          ),
        ));
    }
    return slivers;
  }
}

// ---------------------------------------------------------------------------
// Composants
// ---------------------------------------------------------------------------

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.module,
    required this.projectId,
    required this.period,
    required this.onModule,
    required this.onPreset,
    required this.onCustom,
    required this.filters,
    required this.activeFilterCount,
    required this.searchField,
  });

  final ReportModule module;
  final String projectId;
  final ReportPeriod period;
  final ValueChanged<ReportModule> onModule;
  final ValueChanged<ReportPeriodPreset> onPreset;
  final VoidCallback onCustom;
  final Widget? filters;
  final int activeFilterCount;
  final Widget searchField;

  static const _icons = {
    ReportModule.achats: Icons.shopping_cart_outlined,
    ReportModule.planning: Icons.calendar_month_outlined,
    ReportModule.devis: Icons.request_quote_outlined,
    ReportModule.documents: Icons.folder_outlined,
    ReportModule.metrage: Icons.straighten_outlined,
  };

  /// Ligne de puces : sur une seule ligne défilable horizontalement sur
  /// petit écran (compact), en plusieurs lignes sur grand écran.
  Widget _chips(List<Widget> chips) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Wrap(spacing: 8, runSpacing: 8, children: chips);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in chips)
                Padding(padding: const EdgeInsets.only(right: 8), child: c),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    Widget step(String n, String label) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text('$n. $label', style: theme.textTheme.titleSmall),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            step('1', 'Module'),
            _chips([
              for (final m in ReportModule.values)
                ChoiceChip(
                  avatar: Icon(_icons[m], size: 18),
                  label: Text(m.label),
                  selected: m == module,
                  onSelected: (_) => onModule(m),
                ),
            ]),
            step('2', 'Projet'),
            ProjectSelectorCard(
              currentProjectId: projectId,
              labelText: 'Projet du rapport',
            ),
            step('3', 'Période'),
            if (!module.usesPeriod)
              Text(
                'Le métré n’est pas daté : le rapport présente l’état actuel '
                'des espaces du projet.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              _chips([
                for (final p in ReportPeriodPreset.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == period.preset,
                    onSelected: (_) => onPreset(p),
                  ),
              ]),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '${period.rangeLabel} · ${module.dateRule}',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    onPressed: onCustom,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: const Text('Choisir les dates'),
                  ),
                ],
              ),
            ],
            step('4', 'Filtres'),
            searchField,
            if (filters != null)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('filters-${module.name}'),
                  initiallyExpanded: wide,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: Text(
                    activeFilterCount == 0
                        ? 'Plus de filtres (tous les éléments inclus)'
                        : 'Plus de filtres ($activeFilterCount actif'
                            '${activeFilterCount > 1 ? 's' : ''})',
                    style: theme.textTheme.labelLarge,
                  ),
                  children: [filters!],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.module,
    required this.projectName,
    required this.periodLabel,
    required this.filters,
    required this.onReset,
  });

  final ReportModule module;
  final String projectName;
  final String periodLabel;
  final List<String> filters;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    Widget chip(IconData icon, String text) => Chip(
          avatar: Icon(icon, size: 16, color: colors.petrol),
          label: Text(text),
          visualDensity: VisualDensity.compact,
        );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Filtres actifs :', style: Theme.of(context).textTheme.labelLarge),
        chip(Icons.category_outlined, module.label),
        chip(Icons.apartment_outlined, projectName),
        chip(Icons.event_outlined, periodLabel),
        for (final f in filters) chip(Icons.filter_alt_outlined, f),
        if (onReset != null)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Réinitialiser les filtres'),
          ),
      ],
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.report,
    required this.exporting,
    required this.onPdf,
    required this.onExcel,
    required this.onRefresh,
  });

  final AnalysisReport report;
  final bool exporting;
  final VoidCallback? onPdf;
  final VoidCallback? onExcel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Période : ${report.periodLabel}'),
            Text(
              '${report.itemCount} élément(s) inclus · généré le '
              '${formatDay(report.generatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: exporting ? null : onPdf,
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF / Imprimer'),
                ),
                OutlinedButton.icon(
                  onPressed: exporting ? null : onExcel,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Excel'),
                ),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualiser les données'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  const _Indicators({required this.indicators});

  final List<ReportIndicator> indicators;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in indicators)
              Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.label, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      i.value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.petrol,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (i.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(i.hint!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.petrolSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: colors.petrol),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(n, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.text)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Graphique en barres horizontales, lisible sur mobile (libellé au-dessus
/// de la barre, valeur en clair).
class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.breakdown});

  final ReportBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final theme = Theme.of(context);
    final useAmount = breakdown.amountLabel != null;
    double value(BreakdownEntry e) => useAmount ? (e.amount ?? 0) : e.count.toDouble();
    final max = breakdown.entries.map(value).fold<double>(0, (a, b) => b > a ? b : a);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(breakdown.title, style: theme.textTheme.titleMedium),
            if (useAmount)
              Text('${breakdown.amountLabel} (DA) et nombre d’éléments',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            for (final e in breakdown.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          useAmount ? '${e.amountText} · ${e.count}' : '${e.count}',
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: max <= 0 ? 0 : value(e) / max,
                        minHeight: 10,
                        color: colors.petrol,
                        backgroundColor: colors.surfaceAlt,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.count, this.trailing});

  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Text('$title ($count)', style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.lines});

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.petrolSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.petrol.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (final (label, value) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

Color _purchaseStatusColor(AppPaletteColors c, String status) {
  switch (status) {
    case 'livre':
      return c.success;
    case 'commande':
      return Colors.orange.shade700;
    case 'dg_valide':
      return c.info;
    case 'annule':
      return c.danger;
    default:
      return c.textSoft;
  }
}

Color _taskStateColor(AppPaletteColors c, TaskReportState s) {
  switch (s) {
    case TaskReportState.terminee:
      return c.success;
    case TaskReportState.enRetard:
      return c.danger;
    case TaskReportState.enCours:
      return c.info;
    case TaskReportState.bloquee:
      return Colors.orange.shade700;
    case TaskReportState.aVenir:
      return c.petrol;
    case TaskReportState.annulee:
      return c.textSoft;
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.row});

  final PurchaseRow row;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final theme = Theme.of(context);
    final p = row.purchase;
    final amount = row.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(p.title, style: theme.textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${formatDay(row.day)} · réf. ${row.internalRef}', style: theme.textTheme.bodySmall),
              _StatusChip(purchaseStatusLabel(p.status), _purchaseStatusColor(colors, p.status)),
              if (row.zeroPriceLines > 0) _StatusChip('prix à 0', colors.danger),
            ],
          ),
        ),
        trailing: Text(
          amount == null ? 'Non renseigné' : formatAmount(amount),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontStyle: amount == null ? FontStyle.italic : FontStyle.normal,
            color: amount == null ? colors.textSoft : colors.petrol,
          ),
        ),
        children: [
          _kv(context, 'Lot', p.lot.trim().isEmpty ? 'Non renseigné' : p.lot),
          _kv(context, 'Date de commande', purchaseOrderedLabel(p)),
          _kv(context, 'Date de livraison', purchaseDeliveredLabel(p)),
          _kv(context, 'Fournisseur', row.supplierName ?? 'Non renseigné'),
          if (p.notes.trim().isNotEmpty) _kv(context, 'Remarque', p.notes),
          const Divider(height: 18),
          if (row.items.isEmpty)
            Text('Aucune ligne d’article : montant non renseigné.',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
          else ...[
            for (final item in row.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.article, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (item.description.trim().isNotEmpty)
                            Text(item.description, style: theme.textTheme.bodySmall),
                          Text(
                            '${formatQuantity(item.quantity)} ${item.unit} × '
                            '${item.unitPrice == 0 ? '0 (prix à 0 — peut-être non saisi)' : formatAmount(item.unitPrice)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatAmount(item.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Divider(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Sous-total de l’achat', style: TextStyle(fontWeight: FontWeight.w700))),
                Text(formatAmount(amount!), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _kv(BuildContext context, String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$k : ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: v),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.text),
    ),
  );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.row});

  final QuoteRow row;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final theme = Theme.of(context);
    final q = row.quote;
    String money(double? v) => v == null ? 'Non renseigné' : formatAmount(v);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(q.title, style: theme.textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(formatDay(row.day), style: theme.textTheme.bodySmall),
              _StatusChip(quoteStatusLabel(q.status),
                  q.status == 'signe' ? colors.success : q.status == 'envoye' ? colors.info : colors.textSoft),
            ],
          ),
        ),
        trailing: Text(
          'TTC ${money(row.totalTtc)}',
          style: TextStyle(fontWeight: FontWeight.w800, color: row.totalTtc == null ? colors.textSoft : colors.petrol),
        ),
        children: [
          _kv(context, 'Client', row.clientName ?? 'Non renseigné'),
          _kv(context, 'Objet', q.title),
          if (q.sentAt != null) _kv(context, 'Envoyé le', formatDay(q.sentAt!)),
          if (q.signedAt != null) _kv(context, 'Signé le', formatDay(q.signedAt!)),
          _kv(context, 'Version', 'Unique (pas de versions dans l’application)'),
          const Divider(height: 18),
          if (row.items.isEmpty)
            Text('Aucune prestation : montant non renseigné.',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          for (final i in row.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${i.label}\n${formatQuantity(i.quantity)} ${i.unit} × ${formatAmount(i.unitPrice)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.text)),
                  ),
                  Text(formatAmount(i.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const Divider(height: 12),
          _kv(context, 'Total HT', money(row.totalHt)),
          _kv(context, 'TVA ${(quoteTaxRate * 100).round()} %', money(row.tax)),
          _kv(context, 'Total TTC', money(row.totalTtc)),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.row});

  final TaskRow row;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final theme = Theme.of(context);
    final t = row.task;
    final stateColor = _taskStateColor(colors, row.state);
    String d(DateTime? v) => v == null ? 'non renseignée' : formatDay(v);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (row.isMilestone) ...[
                  Icon(Icons.flag_outlined, size: 18, color: stateColor),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(t.title, style: theme.textTheme.titleSmall)),
                _StatusChip(row.state.label, stateColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Prévu : du ${d(t.plannedStartDate)} au ${d(t.plannedEndDate)}'
              '${row.durationDays == null ? '' : ' · ${row.durationDays} j'}',
              style: theme.textTheme.bodySmall,
            ),
            if (t.actualStartDate != null || t.actualEndDate != null)
              Text('Réel : du ${d(t.actualStartDate)} au ${d(t.actualEndDate)}'
                  '${row.finishedLate ? ' (terminée après la date prévue)' : ''}',
                  style: theme.textTheme.bodySmall),
            Text(
              [
                if (row.phaseTitle != null) 'Phase : ${row.phaseTitle}',
                'Responsable : ${row.assigneeName ?? 'non assigné'}',
                if (t.lot.trim().isNotEmpty) 'Lot : ${t.lot}',
                'Statut : ${taskStatusLabel(t.status)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (row.predecessors.isNotEmpty)
              Text('Après : ${row.predecessors.join(', ')}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (t.progress / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: stateColor,
                      backgroundColor: colors.surfaceAlt,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${t.progress.round()} %', style: theme.textTheme.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc});

  final ProjectDocument doc;

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      title: doc.title.trim().isEmpty ? doc.fileName : doc.title,
      subtitle: '${formatDay(documentDay(doc))} · ${documentCategoryLabel(doc.category)}'
          '${doc.isArchived ? ' · archivé' : ''}',
      lines: [
        '${doc.fileName} · ${formatBytes(doc.fileSize)}',
        if (doc.description.trim().isNotEmpty) doc.description,
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.title, required this.subtitle, required this.lines});

  final String title;
  final String subtitle;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            for (final l in lines) Text(l, style: theme.textTheme.bodySmall?.copyWith(color: context.palette.text)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors});

  final AppPaletteColors colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final s in TaskReportState.values) _StatusChip(s.label, _taskStateColor(colors, s)),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator())
              else
                Icon(icon, size: 34, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
