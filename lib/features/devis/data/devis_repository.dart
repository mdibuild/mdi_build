import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_quote.dart';
import '../../../core/models/quote_line_item.dart';
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

  Future<List<QuoteLineItem>> fetchQuoteItems(String quoteId) async {
    final rows = await _client
        .from('project_quote_items')
        .select()
        .eq('quote_id', quoteId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => QuoteLineItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectQuote> createQuote(
    ProjectQuote quote,
    List<QuoteLineItem> items,
  ) async {
    final row = await _client
        .from('project_quotes')
        .insert(quote.toInsertMap())
        .select()
        .single();

    final saved = ProjectQuote.fromMap(row);
    await _replaceItems(saved.id, items);

    return saved;
  }

  Future<ProjectQuote> updateQuote(
    ProjectQuote quote,
    List<QuoteLineItem> items,
  ) async {
    final row = await _client
        .from('project_quotes')
        .update(quote.toUpdateMap())
        .eq('id', quote.id)
        .select()
        .single();

    final saved = ProjectQuote.fromMap(row);
    await _replaceItems(saved.id, items);

    return saved;
  }

  Future<void> _replaceItems(
    String quoteId,
    List<QuoteLineItem> items,
  ) async {
    await _client.from('project_quote_items').delete().eq('quote_id', quoteId);

    if (items.isEmpty) {
      return;
    }

    final payload = items
        .asMap()
        .entries
        .map(
          (entry) => entry.value
              .copyWith(quoteId: quoteId, sortOrder: entry.key)
              .toInsertMap(),
        )
        .toList();

    await _client.from('project_quote_items').insert(payload);
  }

  Future<void> deleteQuote(String quoteId) async {
    await _client.from('project_quotes').delete().eq('id', quoteId);
  }
}
