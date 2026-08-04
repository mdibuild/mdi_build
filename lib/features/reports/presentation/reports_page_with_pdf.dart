import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_report.dart';
import '../../../core/widgets/app_scaffold_title.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../services/report_pdf_service.dart';
import 'providers/reports_providers.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final activeReportsAsync = ref.watch(activeReportsProvider);
    final archivedReportsAsync = ref.watch(archivedReportsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Rapports'),
              bottom: TabBar(
                isScrollable: isCompact,
                tabs: const [
                  Tab(text: 'En cours'),
                  Tab(text: 'Archivés'),
                ],
              ),
            ),
            body: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 20),
              child: Column(
                children: [
                  selectedProjectAsync.when(
                    data: (project) => _ReportsHeader(
                      isCompact: isCompact,
                      projectName: project?.name,
                      onCreate: project == null
                          ? null
                          : () => _openReportDialog(context, ref),
                    ),
                    loading: () => _ReportsHeader(
                      isCompact: isCompact,
                      projectName: null,
                    ),
                    error: (_, __) => _ReportsHeader(
                      isCompact: isCompact,
                      projectName: null,
                      unavailable: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        activeReportsAsync.when(
                          data: (reports) => _ReportsList(
                            isCompact: isCompact,
                            reports: reports,
                            onEdit: (report) => _openReportDialog(
                              context,
                              ref,
                              initialReport: report,
                            ),
                            onPrint: (report) => _printReport(
                              context,
                              projectName:
                                  selectedProjectAsync.value?.name ??
                                      'Projet',
                              report: report,
                            ),
                            onArchiveToggle: (report) =>
                                _toggleArchive(ref, report),
                            onDelete: (report) =>
                                _deleteReport(context, ref, report),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                        archivedReportsAsync.when(
                          data: (reports) => _ReportsList(
                            isCompact: isCompact,
                            reports: reports,
                            onEdit: (report) => _openReportDialog(
                              context,
                              ref,
                              initialReport: report,
                            ),
                            onPrint: (report) => _printReport(
                              context,
                              projectName:
                                  selectedProjectAsync.value?.name ??
                                      'Projet',
                              report: report,
                            ),
                            onArchiveToggle: (report) =>
                                _toggleArchive(ref, report),
                            onDelete: (report) =>
                                _deleteReport(context, ref, report),
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

  Future<void> _openReportDialog(
    BuildContext context,
    WidgetRef ref, {
    ProjectReport? initialReport,
  }) async {
    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);
    final authUserId = profile?.id;

    if (project == null || profile == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projet ou profil introuvable.')),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReportFormDialog(
        initialReport: initialReport,
        companyId: profile.companyId,
        projectId: project.id,
        authorId: authUserId,
      ),
    );

    if (saved == true) {
      ref.invalidate(activeReportsProvider);
      ref.invalidate(archivedReportsProvider);
    }
  }

  Future<void> _printReport(
    BuildContext context, {
    required String projectName,
    required ProjectReport report,
  }) async {
    try {
      await ReportPdfService().printReport(
        projectName: projectName,
        report: report,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur PDF : $error')),
      );
    }
  }

  Future<void> _toggleArchive(WidgetRef ref, ProjectReport report) async {
    await ref.read(reportsRepositoryProvider).setArchived(
          reportId: report.id,
          archived: !report.isArchived,
        );

    ref.invalidate(activeReportsProvider);
    ref.invalidate(archivedReportsProvider);
  }

  Future<void> _deleteReport(
    BuildContext context,
    WidgetRef ref,
    ProjectReport report,
  ) async {
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

    await ref.read(reportsRepositoryProvider).deleteReport(report.id);

    ref.invalidate(activeReportsProvider);
    ref.invalidate(archivedReportsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rapport supprimé.')),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
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
    final subtitle = unavailable
        ? 'Projet courant indisponible.'
        : projectName == null
            ? 'Chargement projet courant...'
            : 'Projet courant : $projectName';

    final action = ElevatedButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.note_add_outlined),
      label: Text(isCompact ? 'Nouveau' : 'Nouveau rapport'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapports',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: action),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: AppScaffoldTitle(
                      title: 'Rapports',
                      subtitle: subtitle,
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

class _ReportsList extends StatelessWidget {
  const _ReportsList({
    required this.isCompact,
    required this.reports,
    required this.onEdit,
    required this.onPrint,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final bool isCompact;
  final List<ProjectReport> reports;
  final Future<void> Function(ProjectReport report) onEdit;
  final Future<void> Function(ProjectReport report) onPrint;
  final Future<void> Function(ProjectReport report) onArchiveToggle;
  final Future<void> Function(ProjectReport report) onDelete;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucun rapport.'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final report = reports[index];
          return _ReportTile(
            isCompact: isCompact,
            report: report,
            onEdit: () => onEdit(report),
            onPrint: () => onPrint(report),
            onArchiveToggle: () => onArchiveToggle(report),
            onDelete: () => onDelete(report),
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.isCompact,
    required this.report,
    required this.onEdit,
    required this.onPrint,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final bool isCompact;
  final ProjectReport report;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPrint;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final reportDate = DateFormat('dd/MM/yyyy').format(report.reportDate);
    final createdAt = DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt);

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
                    report.title,
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
                      _MetaChip(
                        icon: Icons.event_outlined,
                        label: reportDate,
                      ),
                      if (report.weather.trim().isNotEmpty)
                        _MetaChip(
                          icon: Icons.wb_sunny_outlined,
                          label: report.weather,
                        ),
                    ],
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: Icons.event_outlined,
                    label: reportDate,
                  ),
                  const SizedBox(width: 8),
                  if (report.weather.trim().isNotEmpty)
                    _MetaChip(
                      icon: Icons.wb_sunny_outlined,
                      label: report.weather,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            _InfoBlock(label: 'Avancement', value: report.progressSummary),
            const SizedBox(height: 8),
            _InfoBlock(label: 'Blocages', value: report.blockers),
            const SizedBox(height: 8),
            _InfoBlock(label: 'Décisions', value: report.decisions),
            const SizedBox(height: 8),
            _InfoBlock(label: 'Prochaines étapes', value: report.nextSteps),
            const SizedBox(height: 8),
            Text(
              'Créé le $createdAt',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                TextButton.icon(
                  onPressed: onArchiveToggle,
                  icon: Icon(
                    report.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(report.isArchived ? 'Désarchiver' : 'Archiver'),
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? '-' : value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(safeValue),
      ],
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
      setState(() => _reportDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

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

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReport != null;
    final dateLabel = DateFormat('dd/MM/yyyy').format(_reportDate);

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
                    hintText: 'Ex. Visite chantier du matin',
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
                        decoration: const InputDecoration(
                          labelText: 'Date rapport',
                        ),
                        child: Text(dateLabel),
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
                  decoration: const InputDecoration(
                    labelText: 'Météo',
                    hintText: 'Ex. Ensoleillé, pluie légère',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _progressController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Avancement',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _blockersController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Blocages',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _decisionsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Décisions',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextStepsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Prochaines étapes',
                  ),
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
