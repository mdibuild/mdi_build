import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_task.dart';
import '../../../core/models/project_task_dependency.dart';
import '../../../core/services/supabase_service.dart';

class PlanningRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ProjectTask>> fetchTasks({
    required String projectId,
    bool archived = false,
  }) async {
    final rows = await _client
        .from('project_tasks')
        .select()
        .eq('project_id', projectId)
        .eq('is_archived', archived)
        .order('planned_start_date', ascending: true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => ProjectTask.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProjectTaskDependency>> fetchDependencies({
    required String projectId,
  }) async {
    final rows = await _client
        .from('project_task_dependencies')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map(
            (row) => ProjectTaskDependency.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTask(ProjectTask task) async {
    await _client.from('project_tasks').insert(task.toInsertMap());
  }

  Future<void> updateTask(ProjectTask task) async {
    await _client
        .from('project_tasks')
        .update(task.toUpdateMap())
        .eq('id', task.id);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('project_tasks').delete().eq('id', taskId);
  }

  Future<void> createDependency(ProjectTaskDependency dependency) async {
    if (dependency.predecessorTaskId == dependency.successorTaskId) {
      throw Exception('Une tâche ne peut pas dépendre dâDAÃ¢âDAž¢elle-même.');
    }

    final existing = await _client
        .from('project_task_dependencies')
        .select('id')
        .eq('project_id', dependency.projectId)
        .eq('predecessor_task_id', dependency.predecessorTaskId)
        .eq('successor_task_id', dependency.successorTaskId)
        .eq('dependency_type', dependency.dependencyType)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Cette dépendance existe déjà.');
    }

    await _client
        .from('project_task_dependencies')
        .insert(dependency.toInsertMap());
  }

  Future<void> deleteDependency(String dependencyId) async {
    await _client
        .from('project_task_dependencies')
        .delete()
        .eq('id', dependencyId);
  }
}
