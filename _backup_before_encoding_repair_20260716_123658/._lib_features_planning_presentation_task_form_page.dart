import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_task.dart';
import '../../../core/services/supabase_service.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/planning_providers.dart';
import 'task_documents_section.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({
    super.key,
    this.task,
  });

  final ProjectTask? task;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController lotController;
  late final TextEditingController progressController;
  late final TextEditingController durationController;
  late final TextEditingController plannedStartController;
  late final TextEditingController plannedEndController;

  late String taskType;
  late String status;
  late String priority;
  late bool isArchived;

  bool saving = false;

  bool get isEditing => widget.task != null;

  double get progressValue {
    return (double.tryParse(progressController.text.trim()) ?? 0).clamp(0, 100);
  }

  String? get editingTaskId {
    final id = widget.task?.id;
    if ((id ?? '').trim().isEmpty) {
      return null;
    }
    return id;
  }

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    titleController = TextEditingController(text: task?.title ?? '');
    descriptionController =
        TextEditingController(text: task?.description ?? '');
    lotController = TextEditingController(text: task?.lot ?? 'general');
    progressController = TextEditingController(
      text: (task?.progress ?? 0).toStringAsFixed(0),
    );
    durationController = TextEditingController(
      text: (task?.plannedDurationDays ?? 0).toString(),
    );
    plannedStartController = TextEditingController(
      text: _dateText(task?.plannedStartDate),
    );
    plannedEndController = TextEditingController(
      text: _dateText(task?.plannedEndDate),
    );

    taskType = task?.taskType ?? 'task';
    status = task?.status ?? 'brouillon';
    priority = task?.priority ?? 'normale';
    isArchived = task?.isArchived ?? false;

    _syncDurationFromDates();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    lotController.dispose();
    progressController.dispose();
    durationController.dispose();
    plannedStartController.dispose();
    plannedEndController.dispose();
    super.dispose();
  }

  Future<void> pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final parsed = _parseDate(controller.text) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      controller.text = _dateText(picked);
      _syncDurationFromDates();
      setState(() {});
    }
  }

  void _syncDurationFromDates() {
    final startDate = _parseDate(plannedStartController.text.trim());
    final endDate = _parseDate(plannedEndController.text.trim());

    if (startDate == null || endDate == null) {
      return;
    }

    if (endDate.isBefore(startDate)) {
      return;
    }

    final days = endDate.difference(startDate).inDays + 1;
    durationController.text = days.toString();
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (project == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucun projet courant sÃƒÆ’Ã‚Â©lectionnÃƒÆ’Ã‚Â©.')),
        );
      }
      return;
    }

    if (profile == null || authUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisis un titre.')),
        );
      }
      return;
    }

    final startDate = _parseDate(plannedStartController.text.trim());
    final endDate = _parseDate(plannedEndController.text.trim());

    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La fin prÃƒÆ’Ã‚Â©vue ne peut pas ÃƒÆ’Ã‚Âªtre avant le dÃƒÆ’Ã‚Â©but prÃƒÆ’Ã‚Â©vu.'),
          ),
        );
      }
      return;
    }

    final computedDuration =
        (startDate != null && endDate != null && !endDate.isBefore(startDate))
            ? endDate.difference(startDate).inDays + 1
            : (int.tryParse(durationController.text.trim()) ?? 0);

    setState(() => saving = true);

    try {
      final task = ProjectTask(
        id: widget.task?.id ?? '',
        companyId: widget.task?.companyId ?? profile.companyId,
        projectId: widget.task?.projectId ?? project.id,
        parentTaskId: widget.task?.parentTaskId,
        taskType: taskType,
        title: title,
        description: descriptionController.text.trim(),
        lot: lotController.text.trim().isEmpty
            ? 'general'
            : lotController.text.trim(),
        assignedTo: widget.task?.assignedTo,
        createdBy: widget.task?.createdBy ?? authUser.id,
        status: status,
        priority: priority,
        progress: progressValue,
        plannedStartDate: startDate,
        plannedEndDate: endDate,
        plannedDurationDays: computedDuration,
        actualStartDate: widget.task?.actualStartDate,
        actualEndDate: widget.task?.actualEndDate,
        sortOrder: widget.task?.sortOrder ?? 0,
        isArchived: isArchived,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(planningRepositoryProvider);

      if (isEditing) {
        await repository.updateTask(task);
      } else {
        await repository.createTask(task);
      }

      ref.invalidate(activeTasksProvider);
      ref.invalidate(archivedTasksProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'TÃƒÆ’Ã‚Â¢che enregistrÃƒÆ’Ã‚Â©e.'
                : 'TÃƒÆ’Ã‚Â¢che crÃƒÆ’Ã‚Â©ÃƒÆ’Ã‚Â©e. Tu pourras ajouter des documents en la rouvrant.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);
    final progressColor = _progressColor(progressValue);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isEditing ? 'Modifier tÃƒÆ’Ã‚Â¢che' : 'Nouvelle tÃƒÆ’Ã‚Â¢che'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Informations gÃƒÆ’Ã‚Â©nÃƒÆ’Ã‚Â©rales',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _TypeChip(taskType: taskType),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: taskType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'task', child: Text('TÃƒÆ’Ã‚Â¢che')),
                        DropdownMenuItem(
                            value: 'milestone', child: Text('Jalon')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => taskType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lotController,
                      decoration: const InputDecoration(
                        labelText: 'Lot / corps dÃƒÂ¢DAÃ¢âDAžÂ¢ÃƒÆ’Ã‚Â©tat',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pilotage',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _ColorChip(
                          label: _statusLabel(status),
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        _ColorChip(
                          label: _priorityLabel(priority),
                          color: priorityColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'brouillon', child: Text('Brouillon')),
                        DropdownMenuItem(
                            value: 'a_faire', child: Text('ÃƒÆ’DA faire')),
                        DropdownMenuItem(
                            value: 'en_cours', child: Text('En cours')),
                        DropdownMenuItem(
                            value: 'bloquee', child: Text('BloquÃƒÆ’Ã‚Â©e')),
                        DropdownMenuItem(
                            value: 'terminee', child: Text('TerminÃƒÆ’Ã‚Â©e')),
                        DropdownMenuItem(
                            value: 'annulee', child: Text('AnnulÃƒÆ’Ã‚Â©e')),
                        DropdownMenuItem(
                            value: 'archivee', child: Text('ArchivÃƒÆ’Ã‚Â©e')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'PrioritÃƒÆ’Ã‚Â©',
                        prefixIcon: Icon(Icons.priority_high),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'basse', child: Text('Basse')),
                        DropdownMenuItem(
                            value: 'normale', child: Text('Normale')),
                        DropdownMenuItem(value: 'haute', child: Text('Haute')),
                        DropdownMenuItem(
                            value: 'urgente', child: Text('Urgente')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: progressController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Avancement (%)',
                        prefixIcon: Icon(Icons.percent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Progression visuelle',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text('${progressValue.toStringAsFixed(0)} %'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progressValue / 100,
                          color: progressColor,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Planning',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'DurÃƒÆ’Ã‚Â©e prÃƒÆ’Ã‚Â©vue (jours)',
                        prefixIcon: Icon(Icons.timelapse_outlined),
                        helperText:
                            'Calcul automatique selon dÃƒÆ’Ã‚Â©but et fin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plannedStartController,
                      readOnly: true,
                      onTap: () => pickDate(plannedStartController),
                      decoration: const InputDecoration(
                        labelText: 'DÃƒÆ’Ã‚Â©but prÃƒÆ’Ã‚Â©vu',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plannedEndController,
                      readOnly: true,
                      onTap: () => pickDate(plannedEndController),
                      decoration: const InputDecoration(
                        labelText: 'Fin prÃƒÆ’Ã‚Â©vue',
                        prefixIcon: Icon(Icons.event_available_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: isArchived,
                onChanged: (value) {
                  setState(() => isArchived = value);
                },
                title: const Text('Archiver'),
                subtitle: const Text(
                    'Masquer la tÃƒÆ’Ã‚Â¢che des ÃƒÆ’Ã‚Â©lÃƒÆ’Ã‚Â©ments actifs'),
                secondary: Icon(
                  isArchived
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
            ),
            const SizedBox(height: 12),
            if (editingTaskId != null)
              TaskDocumentsSection(taskId: editingTaskId!)
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
                          'Enregistre dÃƒÂ¢DAÃ¢âDAžÂ¢abord la tÃƒÆ’Ã‚Â¢che, puis rouvre-la pour ajouter des documents liÃƒÆ’Ã‚Â©s.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateText(DateTime? date) {
    if (date == null) {
      return '';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$year-$month-$day';
  }

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.taskType,
  });

  final String taskType;

  @override
  Widget build(BuildContext context) {
    final isMilestone = taskType == 'milestone';
    final color = isMilestone ? Colors.deepPurple : Colors.blueGrey;

    return Chip(
      label: Text(isMilestone ? 'Jalon' : 'TÃƒÆ’Ã‚Â¢che'),
      avatar: Icon(
        isMilestone ? Icons.flag : Icons.checklist,
        size: 16,
        color: color,
      ),
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

Color _statusColor(String status) {
  switch (status) {
    case 'brouillon':
      return Colors.blueGrey;
    case 'a_faire':
      return Colors.indigo;
    case 'en_cours':
      return Colors.orange;
    case 'bloquee':
      return Colors.red;
    case 'terminee':
      return Colors.green;
    case 'annulee':
      return Colors.redAccent;
    case 'archivee':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'basse':
      return Colors.green;
    case 'normale':
      return Colors.blueGrey;
    case 'haute':
      return Colors.orange;
    case 'urgente':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

Color _progressColor(double progress) {
  if (progress >= 100) {
    return Colors.green;
  }
  if (progress >= 60) {
    return Colors.blue;
  }
  if (progress >= 30) {
    return Colors.orange;
  }
  return Colors.redAccent;
}

String _statusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'a_faire':
      return 'ÃƒÆ’DA faire';
    case 'en_cours':
      return 'En cours';
    case 'bloquee':
      return 'BloquÃƒÆ’Ã‚Â©e';
    case 'terminee':
      return 'TerminÃƒÆ’Ã‚Â©e';
    case 'annulee':
      return 'AnnulÃƒÆ’Ã‚Â©e';
    case 'archivee':
      return 'ArchivÃƒÆ’Ã‚Â©e';
    default:
      return status;
  }
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'basse':
      return 'Basse';
    case 'normale':
      return 'Normale';
    case 'haute':
      return 'Haute';
    case 'urgente':
      return 'Urgente';
    default:
      return priority;
  }
}
