import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_quote.dart';
import '../../../core/services/supabase_service.dart';

class DevisRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<ProjectQuote?> fetchQuoteByProject(String projectId) async {
    final row = await _client
        .from('project_quotes')
        .select()
        .eq('project_id', projectId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ProjectQuote.fromMap(row);
  }

  Future<ProjectQuote> upsertQuote(ProjectQuote quote) async {
    final row = await _client
        .from('project_quotes')
        .upsert(
          quote.toUpsertMap(),
          onConflict: 'project_id',
        )
        .select()
        .single();

    return ProjectQuote.fromMap(row);
  }

  Future<void> deleteQuote(String quoteId) async {
    await _client.from('project_quotes').delete().eq('id', quoteId);
  }
}
