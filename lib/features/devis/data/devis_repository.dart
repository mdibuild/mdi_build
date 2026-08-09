import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_quote.dart';
import '../../../core/services/supabase_service.dart';

class DevisRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ProjectQuote>> fetchQuotesByProject(String projectId) async {
    final rows = await _client
        .from('project_quotes')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => ProjectQuote.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectQuote?> fetchQuoteById(String quoteId) async {
    final row = await _client
        .from('project_quotes')
        .select()
        .eq('id', quoteId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ProjectQuote.fromMap(row);
  }

  Future<ProjectQuote> createQuote(ProjectQuote quote) async {
    final row = await _client
        .from('project_quotes')
        .insert(quote.toInsertMap())
        .select()
        .single();

    return ProjectQuote.fromMap(row);
  }

  Future<ProjectQuote> updateQuote(ProjectQuote quote) async {
    final row = await _client
        .from('project_quotes')
        .update(quote.toUpdateMap())
        .eq('id', quote.id)
        .select()
        .single();

    return ProjectQuote.fromMap(row);
  }

  Future<void> deleteQuote(String quoteId) async {
    await _client.from('project_quotes').delete().eq('id', quoteId);
  }
}
