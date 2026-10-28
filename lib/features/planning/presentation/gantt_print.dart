import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/models/project_task.dart';
import '../services/gantt_pdf.dart';
import 'gantt_view.dart';

/// Lignes du Gantt imprimé à partir des tâches du Planning (tâches datées
/// uniquement, triées par date de début).
List<GanttPdfRow> ganttRowsFromTasks(
  List<ProjectTask> tasks, {
  bool Function(ProjectTask task)? isLate,
  Map<String, String> assigneeNames = const {},
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  bool late(ProjectTask t) {
    if (isLate != null) {
      return isLate(t);
    }
    final end = t.plannedEndDate;
    return end != null &&
        DateTime(end.year, end.month, end.day).isBefore(day) &&
        !const {'terminee', 'annulee', 'archivee'}.contains(t.status) &&
        t.progress < 100;
  }

  final dated = tasks
      .where((t) => t.plannedStartDate != null || t.plannedEndDate != null)
      .toList()
    ..sort((a, b) => (a.plannedStartDate ?? a.plannedEndDate!)
        .compareTo(b.plannedStartDate ?? b.plannedEndDate!));
  final titles = {for (final t in tasks) t.id: t.title};
  return [
    for (final t in dated)
      GanttPdfRow(
        title: t.title,
        start: t.plannedStartDate ?? t.plannedEndDate!,
        end: t.plannedEndDate ?? t.plannedStartDate!,
        progress: t.progress,
        milestone: t.taskType == 'milestone',
        phase: t.parentTaskId == null ? null : titles[t.parentTaskId],
        assignee: t.assignedTo == null ? null : assigneeNames[t.assignedTo],
        state: switch (t.status) {
          'terminee' => GanttBarState.done,
          'annulee' || 'archivee' => GanttBarState.cancelled,
          _ when late(t) => GanttBarState.late,
          'bloquee' => GanttBarState.blocked,
          'en_cours' => GanttBarState.inProgress,
          _ => GanttBarState.todo,
        },
      ),
  ];
}

/// Fenêtre « Imprimer le Gantt » : choix de l'échelle (nombre de planches
/// indiqué pour chacune), puis aperçu d'impression du Gantt complet.
Future<void> printFullGantt(
  BuildContext context, {
  required List<GanttPdfRow> rows,
  required String title,
  String subtitle = '',
  String companyName = '',
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Aucune tâche datée à imprimer.'),
    ));
    return;
  }
  final scale = await showDialog<GanttScale>(
    context: context,
    builder: (dialogContext) {
      final suggested = autoGanttScale(rows);
      return SimpleDialog(
        title: const Text('Imprimer le Gantt complet'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'A4 paysage. S’il ne tient pas sur une feuille, il est imprimé '
              'sur plusieurs planches numérotées, à assembler de gauche à '
              'droite puis de haut en bas.',
            ),
          ),
          for (final s in GanttScale.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(s),
              child: Row(children: [
                Icon(
                  s == suggested ? Icons.star : Icons.calendar_view_week,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.label}${s == suggested ? ' (conseillé)' : ''}',
                    style: TextStyle(
                      fontWeight:
                          s == suggested ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                Text('${GanttPdfLayout(rows: rows, scale: s).sheets} planche(s)'),
              ]),
            ),
        ],
      );
    },
  );
  if (scale == null || !context.mounted) {
    return;
  }
  try {
    final bytes = await buildGanttPdf(
      rows: rows,
      scale: scale,
      title: title,
      subtitle: subtitle,
      companyName: companyName,
    );
    await Printing.layoutPdf(
      name: 'gantt_${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf',
      onLayout: (_) async => bytes,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impression du Gantt impossible : $error')),
      );
    }
  }
}
