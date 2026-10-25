import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mdi_build/features/dashboard/services/dashboard_metrics_service.dart';

void main() {
  test(
      'Project dashboard reads the planning table and excludes completed, cancelled and archived tasks from overdue count',
      () async {
    final requests = <Uri>[];
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final today = DateTime.now();
    final transport = MockClient((request) async {
      requests.add(request.url);
      final tasks = request.url.path.endsWith('/project_tasks');
      return http.Response.bytes(
          utf8.encode(jsonEncode(tasks
              ? [
                  {
                    'title': 'Retard réel',
                    'status': 'en_cours',
                    'planned_end_date': yesterday.toIso8601String()
                  },
                  {
                    'title': 'Terminée',
                    'status': 'termine',
                    'planned_end_date': yesterday.toIso8601String()
                  },
                  {
                    'title': 'Annulée',
                    'status': 'annule',
                    'planned_end_date': yesterday.toIso8601String()
                  },
                  {
                    'title': 'Archivée',
                    'status': 'en_cours',
                    'is_archived': true,
                    'planned_end_date': yesterday.toIso8601String()
                  },
                  {
                    'title': 'Aujourd’hui',
                    'status': 'en_cours',
                    'planned_end_date': today.toIso8601String()
                  },
                ]
              : [])),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final client = SupabaseClient('https://example.invalid', 'public-test-key',
        httpClient: transport);
    addTearDown(client.dispose);
    final metrics = await DashboardMetricsService(client: client)
        .fetch(companyId: 'company', projectId: 'project-b');
    expect(metrics.tasksCount, 4,
        reason: requests.map((r) => r.path).join(', '));
    expect(metrics.doneTasksCount, 1);
    expect(metrics.lateTasksCount, 1);
    final planningRequest =
        requests.singleWhere((u) => u.path.endsWith('/project_tasks'));
    expect(planningRequest.queryParameters['project_id'], 'eq.project-b');
  });
}
