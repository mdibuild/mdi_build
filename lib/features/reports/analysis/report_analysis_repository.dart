import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_document.dart';
import '../../../core/models/project_quote.dart';
import '../../../core/models/project_task.dart';
import '../../../core/models/project_task_dependency.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/models/quote_line_item.dart';
import '../../../core/models/space_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../metrage/data/spaces_repository.dart';

class PurchasesData {
  const PurchasesData(this.purchases, this.itemsByPurchase);
  final List<Purchase> purchases;
  final Map<String, List<PurchaseItem>> itemsByPurchase;
}

class QuotesData {
  const QuotesData(this.quotes, this.itemsByQuote);
  final List<ProjectQuote> quotes;
  final Map<String, List<QuoteLineItem>> itemsByQuote;
}

class PlanningData {
  const PlanningData(this.tasks, this.dependencies);
  final List<ProjectTask> tasks;
  final List<ProjectTaskDependency> dependencies;
}

/// Chargement **exhaustif** des données d'un projet pour les rapports.
/// Supabase limite chaque requête (1 000 lignes par défaut) : on lit donc
/// page par page jusqu'à la dernière, pour ne jamais tronquer un rapport.
/// Les droits d'accès existants (RLS) s'appliquent comme partout ailleurs.
class ReportAnalysisRepository {
  ReportAnalysisRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;
  static const _pageSize = 1000;
  static const _idChunk = 100;

  Future<List<Map<String, dynamic>>> _fetchAll(
    String table, {
    required String column,
    required String value,
    String orderBy = 'created_at',
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final rows = await _client
          .from(table)
          .select()
          .eq(column, value)
          .order(orderBy, ascending: true)
          .order('id', ascending: true)
          .range(from, from + _pageSize - 1);
      final page = (rows as List<dynamic>)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      all.addAll(page);
      if (page.length < _pageSize) {
        return all;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIn(
    String table, {
    required String column,
    required List<String> ids,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, (i + _idChunk).clamp(0, ids.length));
      for (var from = 0;; from += _pageSize) {
        final rows = await _client
            .from(table)
            .select()
            .inFilter(column, chunk)
            .order('id', ascending: true)
            .range(from, from + _pageSize - 1);
        final page = (rows as List<dynamic>)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        all.addAll(page);
        if (page.length < _pageSize) {
          break;
        }
      }
    }
    return all;
  }

  Future<PurchasesData> loadPurchases(String projectId) async {
    final purchases = (await _fetchAll(
      'purchases',
      column: 'project_id',
      value: projectId,
    ))
        .map(Purchase.fromMap)
        .toList();
    final items = (await _fetchIn(
      'purchase_items',
      column: 'purchase_id',
      ids: [for (final p in purchases) p.id],
    ))
        .map(PurchaseItem.fromMap);
    final byPurchase = <String, List<PurchaseItem>>{};
    for (final item in items) {
      byPurchase.putIfAbsent(item.purchaseId, () => []).add(item);
    }
    return PurchasesData(purchases, byPurchase);
  }

  Future<QuotesData> loadQuotes(String projectId) async {
    final quotes = (await _fetchAll(
      'project_quotes',
      column: 'project_id',
      value: projectId,
    ))
        .map(ProjectQuote.fromMap)
        .toList();
    final items = (await _fetchIn(
      'project_quote_items',
      column: 'quote_id',
      ids: [for (final q in quotes) q.id],
    ))
        .map(QuoteLineItem.fromMap);
    final byQuote = <String, List<QuoteLineItem>>{};
    for (final item in items) {
      byQuote.putIfAbsent(item.quoteId, () => []).add(item);
    }
    return QuotesData(quotes, byQuote);
  }

  /// Tâches non archivées (comme le module Planning) et leurs dépendances.
  Future<PlanningData> loadPlanning(String projectId) async {
    final tasks = (await _fetchAll(
      'project_tasks',
      column: 'project_id',
      value: projectId,
    ))
        .map(ProjectTask.fromMap)
        .where((t) => !t.isArchived)
        .toList();
    final deps = (await _fetchAll(
      'project_task_dependencies',
      column: 'project_id',
      value: projectId,
    ))
        .map(ProjectTaskDependency.fromMap)
        .toList();
    return PlanningData(tasks, deps);
  }

  /// Tous les documents du projet, y compris archivés (signalés comme tels).
  Future<List<ProjectDocument>> loadDocuments(String projectId) async {
    return (await _fetchAll(
      'project_documents',
      column: 'project_id',
      value: projectId,
    ))
        .map(ProjectDocument.fromMap)
        .toList();
  }

  /// Espaces du métré, chargés comme dans le module Métré.
  Future<List<SpaceItem>> loadSpaces(String projectId) {
    return SpacesRepository().fetchSpaces(projectId);
  }
}
