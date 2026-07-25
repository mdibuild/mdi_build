import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/project_report.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../services/report_dashboard_generation_service.dart';
import '../services/report_export_service.dart';
import 'providers/reports_providers.dart';

String _moduleLabel(String value) {
  switch (value) {
    case 'global':
      return 'Tout';
    case 'project':
      return 'Projet';
    case 'planning':
      return 'Planning';
    case 'devis':
      return 'Devis';
    case 'achats':
      return 'Achats';
    case 'metrage':
      return 'Métré';
    case 'manual':
      return 'Manuel';
    default:
      return value;
  }
}

String _reportTypeLabel(String value) {
  switch (value) {
    case 'manual':
      return 'Manuel';
    case 'weekly_auto':
      return 'Auto hebdo';
    case 'module_auto':
      return 'Auto module';
    default:
      return value;
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'draft':
      return 'Brouillon';
    case 'generated':
      return 'Généré';
    case 'finalized':
      return 'Finalisé';
    default:
      return value;
  }
}

String _periodLabel(String value) {
  switch (value) {
    case 'current_week':
      return 'Semaine en cours';
    case 'previous_week':
      return 'Semaine précédente';
    case 'current_month':
      return 'Mois en cours';
    case 'custom':
      return 'Personnalisée';
    default:
      return value;
  }
}

String _formatLabel(String value) {
  switch (value) {
    case 'pdf':
      return 'PDF';
    case 'xlsx':
      return 'Excel';
    default:
      return value;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _dateLabel(DateTime value) {
  return '${_two(value.day)}/${_two(value.month)}/${value.year}';
}

String _dateTimeLabel(DateTime value) {
  return '${_dateLabel(value)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _reportPeriodText(ProjectReport report) {
  if (report.periodStart == null || report.periodEnd == null) {
    return '-';
  }
  return '${_dateLabel(report.periodStart!)} Ã¢âDA âDAâ„¢ ${_dateLabel(report.periodEnd!)}';
}

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedGenerationModule = 'global';
  String _selectedPeriod = 'current_week';
  String _selectedFormat = 'pdf';
  DateTimeRange? _customRange;

  String _historyModuleFilter = 'all';
  bool _generating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTimeRange _resolveSelectedRange() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'previous_week':
        final currentWeekStart = _startOfWeek(now);
        final start = currentWeekStart.subtract(const Duration(days: 7));
        final end = currentWeekStart.subtract(const Duration(seconds: 1));
        return DateTimeRange(start: start, end: end);
      case 'current_month':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'custom':
        return _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day, 23, 59, 59),
            );
      case 'current_week':
      default:
        final start = _startOfWeek(now);
        final end = start
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateTimeRange(start: start, end: end);
    }
  }

  String _formatRange(DateTimeRange range) {
    return '${_dateLabel(range.start)} Ã¢âDA âDAâ„¢ ${_dateLabel(range.end)}';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _customRange,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _customRange = DateTimeRange(
        start:
            DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
    });
  }

  List<ProjectReport> _filterReports(List<ProjectReport> reports) {
    final query = _searchController.text.trim().toLowerCase();

    return reports.where((report) {
      final moduleMatch = _historyModuleFilter == 'all' ||
          report.sourceModule == _historyModuleFilter;

      final textMatch = query.isEmpty ||
          report.title.toLowerCase().contains(query) ||
          report.sourceModule.toLowerCase().contains(query) ||
          report.reportType.toLowerCase().contains(query) ||
          report.status.toLowerCase().contains(query) ||
          report.progressSummary.toLowerCase().contains(query);

      return moduleMatch && textMatch;
    }).toList();
  }

  Future<void> _runAutomaticGeneration({
    bool createOnly = false,
  }) async {
    if (_generating) {
      return;
    }

    if (_selectedPeriod == 'custom' && _customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une période personnalisée.')),
      );
      return;
    }

    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);

    if (project == null || profile == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet ou profil introuvable.')),
      );
      return;
    }

    setState(() {
      _generating = true;
    });

    try {
      final range = _resolveSelectedRange();

      final report =
          await ReportDashboardGenerationService().generateAutomaticReport(
        reportsRepository: ref.read(reportsRepositoryProvider),
        companyId: profile.companyId,
        projectId: project.id,
        projectName: project.name,
        authorId: profile.id,
        sourceModule: _selectedGenerationModule,
        periodStart: range.start,
        periodEnd: range.end,
      );

      ref.invalidate(activeReportsProvider);
      ref.invalidate(archivedReportsProvider);

      if (createOnly) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapport généré : ${report.title}')),
        );
        return;
      }

      final repository = ref.read(reportsRepositoryProvider);
      final sections = await repository.fetchSections(report.id);
      final sources = await repository.fetchSources(report.id);

      if (_selectedFormat == 'pdf') {
        await ReportExportService().exportPdf(
          projectName: project.name,
          report: report,
          sections: sections,
          sources: sources,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF généré : ${report.title}')),
        );
        return;
      }

      final filePath = await ReportExportService().exportExcel(
        projectName: project.name,
        report: report,
        sections: sections,
        sources: sources,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel généré : $filePath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur génération/export : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  Future<void> _exportExistingReport({
    required ProjectReport report,
    required String format,
  }) async {
    final project = await ref.read(selectedProjectProvider.future);
    if (project == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet courant introuvable.')),
      );
      return;
    }

    try {
      final repository = ref.read(reportsRepositoryProvider);
      final sections = await repository.fetchSections(report.id);
      final sources = await repository.fetchSources(report.id);

      if (format == 'pdf') {
        await ReportExportService().exportPdf(
          projectName: project.name,
          report: report,
          sections: sections,
          sources: sources,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exporté : ${report.title}')),
        );
        return;
      }

      final filePath = await ReportExportService().exportExcel(
        projectName: project.name,
        report: report,
        sections: sections,
        sources: sources,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exporté : $filePath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export : $error')),
      );
    }
  }

  Future<void> _openReportDialog({
    ProjectReport? initialReport,
  }) async {
    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);

    if (project == null || profile == null) {
      if (!context.mounted) {
        return;
      }
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet ou profil introuvable.')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) => _ReportFormDialog(
        initialReport: initialReport,
        companyId: profile.companyId,
        projectId: project.id,
        authorId: profile.id,
      ),
    );

    if (saved == true) {
      ref.invalidate(activeReportsProvider);
      ref.invalidate(archivedReportsProvider);
    }
  }

  Future<void> _toggleArchive(ProjectReport report) async {
    await ref.read(reportsRepositoryProvider).setArchived(
          reportId: report.id,
          archived: !report.isArchived,
        );

    ref.invalidate(activeReportsProvider);
    ref.invalidate(archivedReportsProvider);
  }

  Future<void> _deleteReport(ProjectReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer rapport'),
        content: Text('Supprimer "${report.title}" ?'),
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

    await ref.read(reportsRepositoryProvider).deleteReport(report.id);

    ref.invalidate(activeReportsProvider);
    ref.invalidate(archivedReportsProvider);

    if (!context.mounted) {
      return;
    }

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rapport supprimé.')),
    );
  }

  Widget _buildHeaderBlock({
    required int activeCount,
    required int archivedCount,
    required int autoCount,
    required int manualCount,
    required String subtitle,
  }) {
    final selectedRange = _resolveSelectedRange();

    return Column(
      children: [
        PremiumHeroHeader(
          title: 'Rapports premium',
          subtitle: subtitle,
          trailing: ElevatedButton.icon(
            onPressed: () => _openReportDialog(),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Nouveau'),
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                title: 'Vue pilotage',
                subtitle: 'Synthèse haute lisibilité pour chef de projet',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  PremiumMetricTile(
                    label: 'Actifs',
                    value: '$activeCount',
                    icon: Icons.description_outlined,
                  ),
                  PremiumMetricTile(
                    label: 'Archivés',
                    value: '$archivedCount',
                    icon: Icons.archive_outlined,
                  ),
                  PremiumMetricTile(
                    label: 'Auto',
                    value: '$autoCount',
                    icon: Icons.auto_awesome_outlined,
                  ),
                  PremiumMetricTile(
                    label: 'Manuel',
                    value: '$manualCount',
                    icon: Icons.edit_note_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text('Module : ${_moduleLabel(_selectedGenerationModule)}'),
                    Text('Période : ${_periodLabel(_selectedPeriod)}'),
                    Text('Plage : ${_formatRange(selectedRange)}'),
                    Text('Format : ${_formatLabel(_selectedFormat)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                title: 'Génération automatique',
                subtitle: 'Créer, générer ou exporter depuis un seul centre',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGenerationModule,
                decoration: const InputDecoration(labelText: 'Module'),
                items: const [
                  DropdownMenuItem(value: 'global', child: Text('Tout')),
                  DropdownMenuItem(value: 'project', child: Text('Projet')),
                  DropdownMenuItem(value: 'planning', child: Text('Planning')),
                  DropdownMenuItem(value: 'devis', child: Text('Devis')),
                  DropdownMenuItem(value: 'achats', child: Text('Achats')),
                  DropdownMenuItem(value: 'metrage', child: Text('Métré')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGenerationModule = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPeriod,
                decoration: const InputDecoration(labelText: 'Période'),
                items: const [
                  DropdownMenuItem(
                    value: 'current_week',
                    child: Text('Semaine en cours'),
                  ),
                  DropdownMenuItem(
                    value: 'previous_week',
                    child: Text('Semaine précédente'),
                  ),
                  DropdownMenuItem(
                    value: 'current_month',
                    child: Text('Mois en cours'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Personnalisée'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPeriod = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedFormat,
                decoration: const InputDecoration(labelText: 'Format'),
                items: const [
                  DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                  DropdownMenuItem(value: 'xlsx', child: Text('Excel')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedFormat = value);
                  }
                },
              ),
              if (_selectedPeriod == 'custom') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _customRange == null
                        ? 'Choisir la période'
                        : _formatRange(_customRange!),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PremiumActionRow(
                children: [
                  FilledButton.icon(
                    onPressed: _generating
                        ? null
                        : () => _runAutomaticGeneration(createOnly: true),
                    icon: const Icon(Icons.playlist_add_check_outlined),
                    label: Text(
                      _generating ? 'Génération...' : 'Créer le rapport',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _generating ? null : () => _runAutomaticGeneration(),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _generating
                          ? 'Traitement...'
                          : 'Générer ${_formatLabel(_selectedFormat)}',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                title: 'Historique',
                subtitle: 'Recherche et lecture des rapports déjà produits',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Recherche',
                  hintText: 'Titre, module, statut...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _historyModuleFilter,
                decoration: const InputDecoration(
                  labelText: 'Filtre module',
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous')),
                  DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                  DropdownMenuItem(value: 'global', child: Text('Tout')),
                  DropdownMenuItem(value: 'project', child: Text('Projet')),
                  DropdownMenuItem(value: 'planning', child: Text('Planning')),
                  DropdownMenuItem(value: 'devis', child: Text('Devis')),
                  DropdownMenuItem(value: 'achats', child: Text('Achats')),
                  DropdownMenuItem(value: 'metrage', child: Text('Métré')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _historyModuleFilter = value);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final activeReportsAsync = ref.watch(activeReportsProvider);
    final archivedReportsAsync = ref.watch(archivedReportsProvider);

    final activeReports =
        activeReportsAsync.valueOrNull ?? const <ProjectReport>[];
    final archivedReports =
        archivedReportsAsync.valueOrNull ?? const <ProjectReport>[];

    final totalReports = activeReports.length + archivedReports.length;
    final autoReports = [
      ...activeReports,
      ...archivedReports,
    ].where((report) => report.reportType != 'manual').length;
    final manualReports = totalReports - autoReports;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rapports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En cours'),
              Tab(text: 'Archivés'),
            ],
          ),
        ),
        body: selectedProjectAsync.when(
          data: (project) {
            final subtitle = project == null
                ? 'Projet courant introuvable'
                : 'Projet courant : ${project.name}';

            return TabBarView(
              children: [
                activeReportsAsync.when(
                  data: (reports) => _ReportsTabContent(
                    header: _buildHeaderBlock(
                      activeCount: activeReports.length,
                      archivedCount: archivedReports.length,
                      autoCount: autoReports,
                      manualCount: manualReports,
                      subtitle: subtitle,
                    ),
                    reports: _filterReports(reports),
                    onEdit: (report) =>
                        _openReportDialog(initialReport: report),
                    onPdf: (report) =>
                        _exportExistingReport(report: report, format: 'pdf'),
                    onExcel: (report) =>
                        _exportExistingReport(report: report, format: 'xlsx'),
                    onArchiveToggle: _toggleArchive,
                    onDelete: _deleteReport,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur : $error')),
                ),
                archivedReportsAsync.when(
                  data: (reports) => _ReportsTabContent(
                    header: _buildHeaderBlock(
                      activeCount: activeReports.length,
                      archivedCount: archivedReports.length,
                      autoCount: autoReports,
                      manualCount: manualReports,
                      subtitle: subtitle,
                    ),
                    reports: _filterReports(reports),
                    onEdit: (report) =>
                        _openReportDialog(initialReport: report),
                    onPdf: (report) =>
                        _exportExistingReport(report: report, format: 'pdf'),
                    onExcel: (report) =>
                        _exportExistingReport(report: report, format: 'xlsx'),
                    onArchiveToggle: _toggleArchive,
                    onDelete: _deleteReport,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur : $error')),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur projet : $error')),
        ),
      ),
    );
  }
}

class _ReportsTabContent extends StatelessWidget {
  const _ReportsTabContent({
    required this.header,
    required this.reports,
    required this.onEdit,
    required this.onPdf,
    required this.onExcel,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final Widget header;
  final List<ProjectReport> reports;
  final Future<void> Function(ProjectReport report) onEdit;
  final Future<void> Function(ProjectReport report) onPdf;
  final Future<void> Function(ProjectReport report) onExcel;
  final Future<void> Function(ProjectReport report) onArchiveToggle;
  final Future<void> Function(ProjectReport report) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        header,
        const SizedBox(height: 16),
        if (reports.isEmpty)
          const PremiumSurfaceCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aucun rapport pour ce filtre.'),
              ),
            ),
          )
        else
          ...reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PremiumReportCard(
                report: report,
                onEdit: () => onEdit(report),
                onPdf: () => onPdf(report),
                onExcel: () => onExcel(report),
                onArchiveToggle: () => onArchiveToggle(report),
                onDelete: () => onDelete(report),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PremiumReportCard extends StatelessWidget {
  const _PremiumReportCard({
    required this.report,
    required this.onEdit,
    required this.onPdf,
    required this.onExcel,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final ProjectReport report;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPdf;
  final Future<void> Function() onExcel;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;

  Color _statusBg() {
    switch (report.status) {
      case 'generated':
        return const Color(0xFFEAF7EE);
      case 'finalized':
        return const Color(0xFFE9F1FF);
      default:
        return AppColors.yellowSoft;
    }
  }

  Color _statusFg() {
    switch (report.status) {
      case 'generated':
        return AppColors.success;
      case 'finalized':
        return AppColors.info;
      default:
        return AppColors.petrol;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumStatusBadge(
                label: _moduleLabel(report.sourceModule),
                backgroundColor: AppColors.petrolSoft,
                foregroundColor: AppColors.petrol,
                icon: Icons.category_outlined,
              ),
              PremiumStatusBadge(
                label: _reportTypeLabel(report.reportType),
                backgroundColor: AppColors.surfaceAlt,
                foregroundColor: AppColors.textSoft,
                icon: Icons.auto_mode_outlined,
              ),
              PremiumStatusBadge(
                label: _statusLabel(report.status),
                backgroundColor: _statusBg(),
                foregroundColor: _statusFg(),
                icon: Icons.flag_outlined,
              ),
              PremiumStatusBadge(
                label: _dateLabel(report.reportDate),
                backgroundColor: AppColors.surfaceAlt,
                foregroundColor: AppColors.textSoft,
                icon: Icons.event_outlined,
              ),
            ],
          ),
          if (report.periodStart != null && report.periodEnd != null) ...[
            const SizedBox(height: 10),
            Text(
              'Période : ${_reportPeriodText(report)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          PremiumInfoLine(label: 'Avancement', value: report.progressSummary),
          const SizedBox(height: 12),
          PremiumInfoLine(label: 'Blocages', value: report.blockers),
          const SizedBox(height: 12),
          PremiumInfoLine(label: 'Décisions', value: report.decisions),
          const SizedBox(height: 12),
          PremiumInfoLine(label: 'Prochaines étapes', value: report.nextSteps),
          const SizedBox(height: 12),
          Text(
            'Créé le ${_dateTimeLabel(report.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          PremiumActionRow(
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier'),
              ),
              ElevatedButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                onPressed: onExcel,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Excel'),
              ),
              OutlinedButton.icon(
                onPressed: onArchiveToggle,
                icon: Icon(
                  report.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(report.isArchived ? 'Désarchiver' : 'Archiver'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportFormDialog extends ConsumerStatefulWidget {
  const _ReportFormDialog({
    this.initialReport,
    required this.companyId,
    required this.projectId,
    required this.authorId,
  });

  final ProjectReport? initialReport;
  final String companyId;
  final String projectId;
  final String? authorId;

  @override
  ConsumerState<_ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends ConsumerState<_ReportFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _weatherController;
  late final TextEditingController _progressController;
  late final TextEditingController _blockersController;
  late final TextEditingController _decisionsController;
  late final TextEditingController _nextStepsController;

  late DateTime _reportDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReport;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _weatherController = TextEditingController(text: initial?.weather ?? '');
    _progressController =
        TextEditingController(text: initial?.progressSummary ?? '');
    _blockersController = TextEditingController(text: initial?.blockers ?? '');
    _decisionsController =
        TextEditingController(text: initial?.decisions ?? '');
    _nextStepsController =
        TextEditingController(text: initial?.nextSteps ?? '');
    _reportDate = initial?.reportDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _weatherController.dispose();
    _progressController.dispose();
    _blockersController.dispose();
    _decisionsController.dispose();
    _nextStepsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _reportDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();
    final initial = widget.initialReport;

    final report = ProjectReport(
      id: initial?.id ?? '',
      companyId: widget.companyId,
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      reportDate: _reportDate,
      weather: _weatherController.text.trim(),
      progressSummary: _progressController.text.trim(),
      blockers: _blockersController.text.trim(),
      decisions: _decisionsController.text.trim(),
      nextSteps: _nextStepsController.text.trim(),
      authorId: initial?.authorId ?? widget.authorId,
      isArchived: initial?.isArchived ?? false,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
      reportType: initial?.reportType ?? 'manual',
      sourceModule: initial?.sourceModule ?? 'manual',
      status: initial?.status ?? 'draft',
      periodStart: initial?.periodStart,
      periodEnd: initial?.periodEnd,
      generatedAt: initial?.generatedAt,
    );

    try {
      if (initial == null) {
        await ref.read(reportsRepositoryProvider).createReport(report);
      } else {
        await ref.read(reportsRepositoryProvider).updateReport(report);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReport != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifier rapport' : 'Nouveau rapport'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    hintText: 'Ex. Point hebdomadaire chantier',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Titre obligatoire';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Date rapport'),
                        child: Text(_dateLabel(_reportDate)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: const Text('Choisir'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weatherController,
                  decoration: const InputDecoration(labelText: 'Météo'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _progressController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Avancement'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _blockersController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Blocages'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _decisionsController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Décisions'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextStepsController,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Prochaines étapes'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}
