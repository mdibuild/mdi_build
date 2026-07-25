import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project.dart';
import '../../../core/services/supabase_service.dart';

class ProjectsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Project>> fetchProjects() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }

    final profile = await _client
        .from('profiles')
        .select('company_id')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      return [];
    }

    final companyId = profile['company_id'] as String;

    final rows = await _client
        .from('projects')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Project.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createProject(Project project) async {
    await _client.from('projects').insert(project.toInsertMap());
  }

  Future<void> updateProject(Project project) async {
    await _client
        .from('projects')
        .update(project.toUpdateMap())
        .eq('id', project.id);
  }

  Future<void> deleteProject(String projectId) async {
    await _client.from('projects').delete().eq('id', projectId);
  }
}
