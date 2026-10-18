import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/models/project_quote.dart';
import 'package:mdi_build/core/models/project_task.dart';
import 'package:mdi_build/core/models/project_task_dependency.dart';
import 'package:mdi_build/core/models/purchase.dart';
import 'package:mdi_build/core/models/purchase_item.dart';
import 'package:mdi_build/core/models/quote_line_item.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis.dart';

const _ts = '2026-10-01T12:00:00Z';

Purchase _purchase(String id, String createdAt,
        {String status = 'commande', String lot = 'Gros œuvre', String title = 'Achat'}) =>
    Purchase.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': '$title $id',
      'lot': lot,
      'notes': '',
      'status': status,
      'created_at': createdAt,
      'updated_at': createdAt,
    });

PurchaseItem _item(String id, String purchaseId, num qty, num price,
        {String article = 'Ciment'}) =>
    PurchaseItem.fromMap({
      'id': id,
      'purchase_id': purchaseId,
      'article': article,
      'description': '',
      'quantity': qty,
      'unit': 'sac',
      'unit_price': price,
      'notes': '',
      'sort_order': 0,
      'created_at': _ts,
      'updated_at': _ts,
    });

ProjectTask _task(String id,
        {String? start,
        String? end,
        String status = 'a_faire',
        num progress = 0,
        String? parent,
        String type = 'task'}) =>
    ProjectTask.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'parent_task_id': parent,
      'task_type': type,
      'title': 'Tâche $id',
      'description': '',
      'lot': '',
      'status': status,
      'priority': 'normale',
      'progress': progress,
      'planned_start_date': start,
      'planned_end_date': end,
      'planned_duration_days': 0,
      'sort_order': 0,
      'is_archived': false,
      'created_at': _ts,
      'updated_at': _ts,
    });

ProjectQuote _quote(String id, String createdAt, {String status = 'envoye'}) =>
    ProjectQuote.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': 'Devis $id',
      'mode': 'piece',
      'status': status,
      'unit_price_walls': 0,
      'unit_price_ceiling': 0,
      'created_at': createdAt,
      'updated_at': createdAt,
    });

QuoteLineItem _quoteItem(String id, String quoteId, num qty, num price) =>
    QuoteLineItem.fromMap({
      'id': id,
      'quote_id': quoteId,
      'label': 'Peinture',
      'quantity': qty,
      'unit': 'm²',
      'unit_price': price,
      'sort_order': 0,
      'created_at': _ts,
      'updated_at': _ts,
    });

void main() {
  final october = ReportPeriod.custom(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

  group('Période', () {
    test('bornes incluses', () {
      expect(october.containsDay(DateTime(2026, 10, 1)), isTrue);
      expect(october.containsDay(DateTime(2026, 10, 31)), isTrue);
      expect(october.containsDay(DateTime(2026, 9, 30)), isFalse);
      expect(october.containsDay(DateTime(2026, 11, 1)), isFalse);
    });

    test('préréglages : ce mois et mois dernier', () {
      final now = DateTime(2026, 3, 15);
      final thisMonth = ReportPeriod.preset(ReportPeriodPreset.thisMonth, now: now);
      expect(thisMonth.start, DateTime(2026, 3, 1));
      expect(thisMonth.end, DateTime(2026, 3, 31));
      final last = ReportPeriod.preset(ReportPeriodPreset.lastMonth, now: now);
      expect(last.start, DateTime(2026, 2, 1));
      expect(last.end, DateTime(2026, 2, 28));
      final jan = ReportPeriod.preset(ReportPeriodPreset.lastMonth, now: DateTime(2026, 1, 10));
      expect(jan.start, DateTime(2025, 12, 1));
      expect(jan.end, DateTime(2025, 12, 31));
    });

    test('dates inversées remises dans l’ordre', () {
      final p = ReportPeriod.custom(DateTime(2026, 10, 31), DateTime(2026, 10, 1));
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.end, DateTime(2026, 10, 31));
    });
  });

  group('Achats', () {
    final a = _purchase('aaaaaaaa-1', '2026-10-01T12:00:00Z'); // 1er jour inclus
    final b = _purchase('bbbbbbbb-2', '2026-10-15T12:00:00Z', lot: ''); // sans ligne
    final c = _purchase('cccccccc-3', '2026-10-31T12:00:00Z', status: 'annule'); // dernier jour
    final d = _purchase('dddddddd-4', '2026-11-01T12:00:00Z'); // hors période
    final items = {
      a.id: [_item('i1', a.id, 2, 100), _item('i2', a.id, 3, 0, article: 'Sable')],
      c.id: [_item('i3', c.id, 1, 50)],
      d.id: [_item('i4', d.id, 1, 999)],
    };

    test('exhaustif : achats sans montant inclus, montant null (pas 0)', () {
      final r = buildPurchasesReport(
        purchases: [a, b, c, d, a], // « a » en double : compté une fois
        itemsByPurchase: items,
        period: october,
      );
      expect(r.count, 3);
      expect(r.rows.map((x) => x.purchase.id), containsAll([a.id, b.id, c.id]));
      final rowB = r.rows.firstWhere((x) => x.purchase.id == b.id);
      expect(rowB.amount, isNull);
      expect(r.withoutAmount, 1);
      expect(r.knownTotal, 250); // 200 + 0 + 50, sans « b »
      expect(r.withZeroPriceLines, 1);
      expect(r.zeroPriceLineCount, 1);
      expect(r.lineCount, 3);
    });

    test('synthèses cohérentes avec la liste (mêmes totaux)', () {
      final r = buildPurchasesReport(
        purchases: [a, b, c, d],
        itemsByPurchase: items,
        period: october,
      );
      expect(r.byStatus.fold<int>(0, (s, e) => s + e.count), r.count);
      expect(r.byStatus.fold<double>(0, (s, e) => s + e.amount!), r.knownTotal);
      expect(r.byLot.fold<double>(0, (s, e) => s + e.amount!), r.knownTotal);
      expect(r.byLot.map((e) => e.label), contains('Lot non renseigné'));
      // L'achat sans montant n'est jamais compté comme 0 dans la répartition.
      final sansLot = r.byLot.firstWhere((e) => e.label == 'Lot non renseigné');
      expect(sansLot.missing, 1);
      expect(sansLot.amountUnknown, isTrue);
      expect(sansLot.amountText, 'Non renseigné');
    });

    test('filtre statut et recherche appliqués à toute la synthèse', () {
      final r = buildPurchasesReport(
        purchases: [a, b, c, d],
        itemsByPurchase: items,
        period: october,
        statuses: {'commande'},
        query: 'sable',
      );
      expect(r.count, 1);
      expect(r.rows.single.purchase.id, a.id);
      expect(r.knownTotal, 200);
    });

    test('tri par montant : achats sans montant en fin de liste', () {
      final r = buildPurchasesReport(
        purchases: [a, b, c],
        itemsByPurchase: items,
        period: october,
        sort: PurchaseSort.amountDesc,
      );
      expect(r.rows.map((x) => x.purchase.id).toList(), [a.id, c.id, b.id]);
    });
  });

  group('Planning', () {
    final today = DateTime(2026, 10, 20);
    final tasks = [
      _task('avant', start: '2026-09-01', end: '2026-09-30'), // hors période
      _task('chevauche-debut', start: '2026-09-20', end: '2026-10-05', status: 'terminee', progress: 100),
      _task('chevauche-fin', start: '2026-10-25', end: '2026-11-15'),
      _task('englobe', start: '2026-09-01', end: '2026-12-31', status: 'en_cours', progress: 40),
      _task('retard', start: '2026-10-01', end: '2026-10-19', status: 'en_cours', progress: 60),
      _task('echeance', start: '2026-10-10', end: '2026-10-20', status: 'en_cours'),
      _task('annulee', start: '2026-10-01', end: '2026-10-02', status: 'annulee'),
      _task('sans-dates'),
      _task('jalon', start: '2026-10-31', end: '2026-10-31', type: 'milestone', parent: 'englobe'),
    ];
    final deps = [
      ProjectTaskDependency.fromMap({
        'id': 'd1', 'company_id': 'c1', 'project_id': 'p1',
        'predecessor_task_id': 'retard', 'successor_task_id': 'jalon',
        'dependency_type': 'finish_to_start', 'created_at': _ts, 'updated_at': _ts,
      }),
      ProjectTaskDependency.fromMap({
        'id': 'd2', 'company_id': 'c1', 'project_id': 'p1',
        'predecessor_task_id': 'avant', 'successor_task_id': 'retard',
        'dependency_type': 'finish_to_start', 'created_at': _ts, 'updated_at': _ts,
      }),
    ];

    final r = buildPlanningReport(
      tasks: tasks,
      dependencies: deps,
      period: october,
      userNames: const {},
      today: today,
    );
    final ids = r.rows.map((x) => x.task.id).toSet();

    test('inclut les tâches qui chevauchent la période', () {
      expect(ids, containsAll(['chevauche-debut', 'chevauche-fin', 'englobe', 'jalon']));
      expect(ids, isNot(contains('avant')));
    });

    test('tâches sans dates listées à part, jamais perdues', () {
      expect(r.undatedRows.map((x) => x.task.id), ['sans-dates']);
      expect(r.total, r.rows.length + 1);
    });

    test('retard : échéance dépassée seulement, ni annulée ni terminée', () {
      TaskReportState stateOf(String id) =>
          r.rows.firstWhere((x) => x.task.id == id).state;
      expect(stateOf('retard'), TaskReportState.enRetard);
      expect(stateOf('echeance'), TaskReportState.enCours); // jour J : pas en retard
      expect(stateOf('annulee'), TaskReportState.annulee);
      expect(stateOf('chevauche-debut'), TaskReportState.terminee);
      expect(r.counts.values.fold<int>(0, (s, v) => s + v), r.total);
    });

    test('phase, jalon et dépendances issus des données uniquement', () {
      final jalon = r.rows.firstWhere((x) => x.task.id == 'jalon');
      expect(jalon.isMilestone, isTrue);
      expect(jalon.phaseTitle, 'Tâche englobe');
      expect(jalon.predecessors, ['Tâche retard']);
      expect(jalon.durationDays, 1);
      // d2 relie une tâche hors période : non affichée.
      expect(r.dependencies.map((d) => d.id), ['d1']);
    });
  });

  group('Devis', () {
    final q1 = _quote('q1', '2026-10-05T10:00:00', status: 'envoye');
    final q2 = _quote('q2', '2026-10-06T10:00:00', status: 'brouillon'); // sans ligne
    final q3 = _quote('q3', '2026-11-02T10:00:00');
    final items = {
      'q1': [_quoteItem('l1', 'q1', 10, 100), _quoteItem('l2', 'q1', 5, 20)],
      'q3': [_quoteItem('l3', 'q3', 1, 1000)],
    };

    test('HT = somme des lignes, TVA 19 %, TTC ; sans ligne = non renseigné', () {
      final r = buildQuotesReport(
        quotes: [q1, q2, q3, q1],
        itemsByQuote: items,
        period: october,
        clientName: 'M. Benali',
      );
      expect(r.count, 2);
      final row1 = r.rows.firstWhere((x) => x.quote.id == 'q1');
      expect(row1.totalHt, 1100);
      expect(row1.tax, closeTo(209, 1e-9));
      expect(row1.totalTtc, closeTo(1309, 1e-9));
      expect(r.rows.firstWhere((x) => x.quote.id == 'q2').totalHt, isNull);
      expect(r.withoutAmount, 1);
      expect(r.knownHt, 1100);
      expect(r.byStatus.fold<double>(0, (s, e) => s + e.amount!), closeTo(r.knownTtc, 1e-9));
    });
  });

  test('dates de commande/livraison : non applicable vs non renseignée', () {
    final brouillon = _purchase('x1', _ts, status: 'brouillon');
    final commande = _purchase('x2', _ts, status: 'commande');
    final livre = _purchase('x3', _ts, status: 'livre');
    expect(purchaseOrderedLabel(brouillon), startsWith('Non applicable'));
    expect(purchaseOrderedLabel(commande), 'Non renseignée');
    expect(purchaseDeliveredLabel(commande), startsWith('Non applicable'));
    expect(purchaseDeliveredLabel(livre), 'Non renseignée');
  });

  test('format montant', () {
    expect(formatAmount(1234567.5), '1 234 567,50 DA');
    expect(formatAmount(0), '0,00 DA');
  });
}
