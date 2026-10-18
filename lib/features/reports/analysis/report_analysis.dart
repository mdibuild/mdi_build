// Calcul des rapports d'analyse (logique pure, sans affichage).
//
// Toutes les vues d'un rapport (synthèse, graphiques, liste détaillée,
// exports PDF/Excel) sont construites à partir des objets produits ici, avec
// les mêmes filtres et les mêmes règles de calcul : elles concordent donc
// toujours entre elles.

import '../../../core/models/project_document.dart';
import '../../../core/models/project_quote.dart';
import '../../../core/models/project_task.dart';
import '../../../core/models/project_task_dependency.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/models/quantity_line.dart';
import '../../../core/models/quote_line_item.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String formatDay(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

/// Montant en dinars avec séparateur de milliers : « 12 500,00 DA ».
String formatAmount(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${negative ? '-' : ''}$buffer,${parts.last} DA';
}

String formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

// ---------------------------------------------------------------------------
// Périodes
// ---------------------------------------------------------------------------

enum ReportPeriodPreset {
  thisMonth('Ce mois'),
  lastMonth('Mois dernier'),
  last30Days('30 derniers jours'),
  thisYear('Cette année'),
  allTime('Depuis le début'),
  custom('Personnalisée');

  const ReportPeriodPreset(this.label);
  final String label;
}

/// Période d'un rapport. Les bornes sont des jours **inclus** ; une borne
/// nulle signifie « sans limite » (préréglage « Depuis le début »).
class ReportPeriod {
  const ReportPeriod._(this.preset, this.start, this.end);

  factory ReportPeriod.preset(ReportPeriodPreset preset, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    switch (preset) {
      case ReportPeriodPreset.thisMonth:
        return ReportPeriod._(
          preset,
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 0),
        );
      case ReportPeriodPreset.lastMonth:
        return ReportPeriod._(
          preset,
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 0),
        );
      case ReportPeriodPreset.last30Days:
        return ReportPeriod._(
          preset,
          today.subtract(const Duration(days: 29)),
          today,
        );
      case ReportPeriodPreset.thisYear:
        return ReportPeriod._(
          preset,
          DateTime(today.year, 1, 1),
          DateTime(today.year, 12, 31),
        );
      case ReportPeriodPreset.allTime:
      case ReportPeriodPreset.custom:
        return const ReportPeriod._(ReportPeriodPreset.allTime, null, null);
    }
  }

  factory ReportPeriod.custom(DateTime start, DateTime end) {
    final a = dateOnly(start);
    final b = dateOnly(end);
    return ReportPeriod._(
      ReportPeriodPreset.custom,
      a.isAfter(b) ? b : a,
      a.isAfter(b) ? a : b,
    );
  }

  final ReportPeriodPreset preset;
  final DateTime? start;
  final DateTime? end;

  bool get isUnbounded => start == null && end == null;

  /// Le jour donné est-il dans la période (bornes incluses) ?
  bool containsDay(DateTime day) {
    final d = dateOnly(day);
    if (start != null && d.isBefore(start!)) {
      return false;
    }
    if (end != null && d.isAfter(end!)) {
      return false;
    }
    return true;
  }

  /// L'intervalle [from, to] chevauche-t-il la période (bornes incluses) ?
  bool overlaps(DateTime from, DateTime to) {
    final a = dateOnly(from);
    final b = dateOnly(to);
    if (start != null && b.isBefore(start!)) {
      return false;
    }
    if (end != null && a.isAfter(end!)) {
      return false;
    }
    return true;
  }

  String get rangeLabel {
    if (isUnbounded) {
      return 'Depuis le début du projet';
    }
    return 'Du ${formatDay(start!)} au ${formatDay(end!)} inclus';
  }

  String get label => preset == ReportPeriodPreset.custom ||
          preset == ReportPeriodPreset.allTime
      ? rangeLabel
      : '${preset.label} · $rangeLabel';
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

enum ReportModule {
  achats('Achats', 'Date de création de l’achat'),
  planning('Planning', 'Intervalle prévu des tâches (chevauchement)'),
  devis('Devis', 'Date de création du devis'),
  documents('Documents', 'Date d’ajout du document'),
  metrage('Métré', 'Non daté : état actuel des espaces');

  const ReportModule(this.label, this.dateRule);
  final String label;

  /// Date utilisée pour filtrer ce rapport (affichée à l'utilisateur).
  final String dateRule;

  bool get usesPeriod => this != ReportModule.metrage;
}

/// Taux de TVA appliqué par le module Devis (identique, pour des totaux
/// concordants avec les devis affichés dans l'application).
const double quoteTaxRate = 0.19;

// ---------------------------------------------------------------------------
// Libellés (identiques à ceux des modules)
// ---------------------------------------------------------------------------

const purchaseStatuses = [
  'brouillon',
  'dg_valide',
  'commande',
  'livre',
  'annule',
  'archive',
];

String purchaseStatusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'dg_valide':
      return 'DG validé';
    case 'commande':
      return 'Commandé';
    case 'livre':
      return 'Livré';
    case 'annule':
      return 'Annulé';
    case 'archive':
      return 'Archivé';
    default:
      return status;
  }
}

String quoteStatusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'envoye':
      return 'Envoyé';
    case 'signe':
      return 'Signé';
    case 'annule':
      return 'Annulé';
    case 'archive':
      return 'Archivé';
    default:
      return status;
  }
}

String taskStatusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'a_faire':
      return 'À faire';
    case 'en_cours':
      return 'En cours';
    case 'bloquee':
      return 'Bloquée';
    case 'terminee':
      return 'Terminée';
    case 'annulee':
      return 'Annulée';
    case 'archivee':
      return 'Archivée';
    default:
      return status;
  }
}

String documentCategoryLabel(String category) {
  switch (category) {
    case 'plan':
      return 'Plan';
    case 'photo':
      return 'Photo';
    case 'facture':
      return 'Facture';
    case 'bon_commande':
      return 'Bon de commande';
    case 'pv':
      return 'PV';
    case 'rapport':
      return 'Rapport';
    case 'autre':
      return 'Autre';
    default:
      return category;
  }
}

bool _matches(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return true;
  }
  return fields.any((f) => (f ?? '').toLowerCase().contains(q));
}

/// Ligne de répartition (graphique en barres et tableau de synthèse).
class BreakdownEntry {
  const BreakdownEntry({
    required this.label,
    required this.count,
    this.amount,
    this.missing = 0,
  });

  final String label;
  final int count;

  /// Montant connu cumulé (null si non pertinent).
  final double? amount;

  /// Éléments de ce groupe dont le montant n'est pas renseigné : ils ne sont
  /// jamais comptés comme zéro.
  final int missing;

  /// Aucun montant renseigné dans ce groupe.
  bool get amountUnknown => missing > 0 && missing == count;

  /// Libellé du montant, explicite sur les montants manquants.
  String get amountText {
    if (amountUnknown) {
      return 'Non renseigné';
    }
    final base = formatAmount(amount ?? 0);
    return missing > 0 ? '$base (+$missing sans montant)' : base;
  }
}

List<BreakdownEntry> _sortedBreakdown(Map<String, BreakdownEntry> map) {
  final list = map.values.toList()
    ..sort((a, b) {
      final byAmount = (b.amount ?? 0).compareTo(a.amount ?? 0);
      return byAmount != 0 ? byAmount : b.count.compareTo(a.count);
    });
  return list;
}

// ---------------------------------------------------------------------------
// Achats
// ---------------------------------------------------------------------------

/// Jour d'un achat : la date de création est posée par le serveur (UTC) ;
/// on la ramène à l'heure locale pour retrouver le bon jour calendaire.
DateTime purchaseDay(Purchase purchase) => dateOnly(purchase.createdAt.toLocal());

class PurchaseRow {
  PurchaseRow({required this.purchase, required List<PurchaseItem> items})
      : items = List.unmodifiable(
          [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );

  final Purchase purchase;
  final List<PurchaseItem> items;

  DateTime get day => purchaseDay(purchase);

  /// Identifiant interne court (l'application n'enregistre pas de
  /// référence d'achat) : 8 premiers caractères de l'identifiant.
  String get internalRef => purchase.id.length >= 8
      ? purchase.id.substring(0, 8).toUpperCase()
      : purchase.id.toUpperCase();

  /// Montant de l'achat : somme des lignes ; **null** (non renseigné) s'il
  /// n'a aucune ligne. Jamais remplacé par zéro.
  double? get amount =>
      items.isEmpty ? null : items.fold<double>(0, (s, i) => s + i.total);

  /// Lignes dont le prix unitaire vaut 0. La base enregistre 0 par défaut :
  /// impossible de distinguer un prix réellement nul d'un prix non saisi.
  int get zeroPriceLines => items.where((i) => i.unitPrice == 0).length;
}

/// Date de commande d'un achat, explicite quand elle manque :
/// « Non applicable » si l'achat n'a pas encore atteint ce stade,
/// « Non renseignée » s'il l'a atteint (ou dépassé) sans date enregistrée.
String purchaseOrderedLabel(Purchase p) {
  if (p.orderedAt != null) {
    return formatDay(p.orderedAt!.toLocal());
  }
  return const {'brouillon', 'dg_valide'}.contains(p.status)
      ? 'Non applicable (pas encore commandé)'
      : 'Non renseignée';
}

/// Date de livraison, même logique que [purchaseOrderedLabel].
String purchaseDeliveredLabel(Purchase p) {
  if (p.deliveredAt != null) {
    return formatDay(p.deliveredAt!.toLocal());
  }
  return const {'brouillon', 'dg_valide', 'commande'}.contains(p.status)
      ? 'Non applicable (pas encore livré)'
      : 'Non renseignée';
}

enum PurchaseSort {
  dateDesc('Date : plus récents d’abord'),
  dateAsc('Date : plus anciens d’abord'),
  amountDesc('Montant (décroissant)'),
  title('Désignation (ordre alphabétique)');

  const PurchaseSort(this.label);
  final String label;
}

class PurchasesReport {
  PurchasesReport._({
    required this.rows,
    required this.knownTotal,
    required this.withoutAmount,
    required this.withZeroPriceLines,
    required this.zeroPriceLineCount,
    required this.lineCount,
    required this.byStatus,
    required this.byLot,
  });

  final List<PurchaseRow> rows;

  /// Somme des montants **renseignés** uniquement.
  final double knownTotal;

  /// Achats sans aucune ligne (montant non renseigné).
  final int withoutAmount;

  /// Achats contenant au moins une ligne à prix 0.
  final int withZeroPriceLines;
  final int zeroPriceLineCount;
  final int lineCount;
  final List<BreakdownEntry> byStatus;
  final List<BreakdownEntry> byLot;

  int get count => rows.length;
}

PurchasesReport buildPurchasesReport({
  required List<Purchase> purchases,
  required Map<String, List<PurchaseItem>> itemsByPurchase,
  required ReportPeriod period,
  Set<String>? statuses,
  String query = '',
  PurchaseSort sort = PurchaseSort.dateDesc,
}) {
  final seen = <String>{};
  final rows = <PurchaseRow>[];
  for (final purchase in purchases) {
    if (!seen.add(purchase.id)) {
      continue; // jamais deux fois le même achat
    }
    if (!period.containsDay(purchaseDay(purchase))) {
      continue;
    }
    if (statuses != null && !statuses.contains(purchase.status)) {
      continue;
    }
    final items = itemsByPurchase[purchase.id] ?? const <PurchaseItem>[];
    if (!_matches(query, [
      purchase.title,
      purchase.lot,
      purchase.notes,
      purchaseStatusLabel(purchase.status),
      ...items.expand((i) => [i.article, i.description, i.notes]),
    ])) {
      continue;
    }
    rows.add(PurchaseRow(purchase: purchase, items: items));
  }

  switch (sort) {
    case PurchaseSort.dateDesc:
      rows.sort((a, b) => b.purchase.createdAt.compareTo(a.purchase.createdAt));
    case PurchaseSort.dateAsc:
      rows.sort((a, b) => a.purchase.createdAt.compareTo(b.purchase.createdAt));
    case PurchaseSort.amountDesc:
      // Les achats sans montant sont placés en fin de liste.
      rows.sort((a, b) => (b.amount ?? double.negativeInfinity)
          .compareTo(a.amount ?? double.negativeInfinity));
    case PurchaseSort.title:
      rows.sort((a, b) =>
          a.purchase.title.toLowerCase().compareTo(b.purchase.title.toLowerCase()));
  }

  final byStatus = <String, BreakdownEntry>{};
  final byLot = <String, BreakdownEntry>{};
  var knownTotal = 0.0;
  for (final row in rows) {
    final amount = row.amount;
    if (amount != null) {
      knownTotal += amount;
    }
    void add(Map<String, BreakdownEntry> map, String key) {
      final current = map[key];
      map[key] = BreakdownEntry(
        label: key,
        count: (current?.count ?? 0) + 1,
        amount: (current?.amount ?? 0) + (amount ?? 0),
        missing: (current?.missing ?? 0) + (amount == null ? 1 : 0),
      );
    }

    add(byStatus, purchaseStatusLabel(row.purchase.status));
    add(byLot, row.purchase.lot.trim().isEmpty
        ? 'Lot non renseigné'
        : row.purchase.lot.trim());
  }

  return PurchasesReport._(
    rows: List.unmodifiable(rows),
    knownTotal: knownTotal,
    withoutAmount: rows.where((r) => r.amount == null).length,
    withZeroPriceLines: rows.where((r) => r.zeroPriceLines > 0).length,
    zeroPriceLineCount: rows.fold(0, (s, r) => s + r.zeroPriceLines),
    lineCount: rows.fold(0, (s, r) => s + r.items.length),
    byStatus: _sortedBreakdown(byStatus),
    byLot: _sortedBreakdown(byLot),
  );
}

// ---------------------------------------------------------------------------
// Devis
// ---------------------------------------------------------------------------

/// Jour d'un devis : la date est enregistrée par l'application telle quelle.
DateTime quoteDay(ProjectQuote quote) => dateOnly(quote.createdAt);

class QuoteRow {
  QuoteRow({
    required this.quote,
    required List<QuoteLineItem> items,
    required this.clientName,
  }) : items = List.unmodifiable(
          [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );

  final ProjectQuote quote;
  final List<QuoteLineItem> items;

  /// Client du projet (le devis ne porte pas de client propre).
  final String? clientName;

  DateTime get day => quoteDay(quote);

  /// HT = somme des lignes, comme dans le module Devis ; null sans ligne.
  double? get totalHt =>
      items.isEmpty ? null : items.fold<double>(0, (s, i) => s + i.total);
  double? get tax => totalHt == null ? null : totalHt! * quoteTaxRate;
  double? get totalTtc => totalHt == null ? null : totalHt! + tax!;
}

class QuotesReport {
  QuotesReport._({
    required this.rows,
    required this.byStatus,
    required this.knownHt,
    required this.knownTtc,
    required this.withoutAmount,
  });

  final List<QuoteRow> rows;
  final List<BreakdownEntry> byStatus; // montants = TTC connus
  final double knownHt;
  final double knownTtc;
  final int withoutAmount;

  int get count => rows.length;
}

QuotesReport buildQuotesReport({
  required List<ProjectQuote> quotes,
  required Map<String, List<QuoteLineItem>> itemsByQuote,
  required ReportPeriod period,
  required String? clientName,
  Set<String>? statuses,
  String query = '',
}) {
  final seen = <String>{};
  final rows = <QuoteRow>[];
  for (final quote in quotes) {
    if (!seen.add(quote.id)) {
      continue;
    }
    if (!period.containsDay(quoteDay(quote))) {
      continue;
    }
    if (statuses != null && !statuses.contains(quote.status)) {
      continue;
    }
    final items = itemsByQuote[quote.id] ?? const <QuoteLineItem>[];
    if (!_matches(query, [
      quote.title,
      quoteStatusLabel(quote.status),
      clientName,
      ...items.map((i) => i.label),
    ])) {
      continue;
    }
    rows.add(QuoteRow(quote: quote, items: items, clientName: clientName));
  }
  rows.sort((a, b) => b.quote.createdAt.compareTo(a.quote.createdAt));

  final byStatus = <String, BreakdownEntry>{};
  var knownHt = 0.0;
  var knownTtc = 0.0;
  for (final row in rows) {
    knownHt += row.totalHt ?? 0;
    knownTtc += row.totalTtc ?? 0;
    final key = quoteStatusLabel(row.quote.status);
    final current = byStatus[key];
    byStatus[key] = BreakdownEntry(
      label: key,
      count: (current?.count ?? 0) + 1,
      amount: (current?.amount ?? 0) + (row.totalTtc ?? 0),
      missing: (current?.missing ?? 0) + (row.totalTtc == null ? 1 : 0),
    );
  }

  return QuotesReport._(
    rows: List.unmodifiable(rows),
    byStatus: _sortedBreakdown(byStatus),
    knownHt: knownHt,
    knownTtc: knownTtc,
    withoutAmount: rows.where((r) => r.totalHt == null).length,
  );
}

// ---------------------------------------------------------------------------
// Planning
// ---------------------------------------------------------------------------

enum TaskReportState {
  terminee('Terminées'),
  enRetard('En retard'),
  enCours('En cours'),
  bloquee('Bloquées'),
  aVenir('À faire / à venir'),
  annulee('Annulées / archivées');

  const TaskReportState(this.label);
  final String label;
}

/// Règle de retard (identique pour la synthèse, la liste et le Gantt) :
/// date de fin prévue **dépassée** (le jour d'échéance n'est pas un retard),
/// tâche ni terminée, ni annulée/archivée, avancement < 100 %.
bool isTaskLate(ProjectTask task, DateTime today) {
  final end = task.plannedEndDate;
  if (end == null) {
    return false;
  }
  if (const {'terminee', 'annulee', 'archivee'}.contains(task.status)) {
    return false;
  }
  if (task.progress >= 100) {
    return false;
  }
  return dateOnly(end).isBefore(dateOnly(today));
}

TaskReportState taskState(ProjectTask task, DateTime today) {
  if (task.status == 'terminee') {
    return TaskReportState.terminee;
  }
  if (task.status == 'annulee' || task.status == 'archivee') {
    return TaskReportState.annulee;
  }
  if (isTaskLate(task, today)) {
    return TaskReportState.enRetard;
  }
  if (task.status == 'bloquee') {
    return TaskReportState.bloquee;
  }
  if (task.status == 'en_cours') {
    return TaskReportState.enCours;
  }
  return TaskReportState.aVenir;
}

class TaskRow {
  TaskRow({
    required this.task,
    required this.state,
    required this.phaseTitle,
    required this.assigneeName,
    required this.predecessors,
  });

  final ProjectTask task;
  final TaskReportState state;
  final String? phaseTitle;
  final String? assigneeName;
  final List<String> predecessors;

  bool get isMilestone => task.taskType == 'milestone';
  bool get hasDates =>
      task.plannedStartDate != null || task.plannedEndDate != null;

  /// Terminée après la date de fin prévue (dates réelles renseignées).
  bool get finishedLate =>
      task.status == 'terminee' &&
      task.actualEndDate != null &&
      task.plannedEndDate != null &&
      dateOnly(task.actualEndDate!).isAfter(dateOnly(task.plannedEndDate!));

  /// Durée prévue en jours : calculée à partir des dates si les deux sont
  /// renseignées (bornes incluses), sinon la durée saisie, sinon null.
  int? get durationDays {
    final s = task.plannedStartDate;
    final e = task.plannedEndDate;
    if (s != null && e != null) {
      return dateOnly(e).difference(dateOnly(s)).inDays + 1;
    }
    return task.plannedDurationDays > 0 ? task.plannedDurationDays : null;
  }
}

class PlanningReport {
  PlanningReport._({
    required this.rows,
    required this.undatedRows,
    required this.counts,
    required this.dependencies,
  });

  /// Tâches datées qui chevauchent la période.
  final List<TaskRow> rows;

  /// Tâches sans aucune date prévue : non positionnables dans le temps,
  /// listées à part pour ne jamais disparaître du rapport.
  final List<TaskRow> undatedRows;
  final Map<TaskReportState, int> counts;

  /// Dépendances dont les deux tâches figurent dans le rapport.
  final List<ProjectTaskDependency> dependencies;

  int get total => rows.length + undatedRows.length;
}

PlanningReport buildPlanningReport({
  required List<ProjectTask> tasks,
  required List<ProjectTaskDependency> dependencies,
  required ReportPeriod period,
  required Map<String, String> userNames,
  required DateTime today,
  Set<TaskReportState>? states,
  String query = '',
}) {
  final byId = {for (final t in tasks) t.id: t};
  final predecessorsOf = <String, List<String>>{};
  for (final d in dependencies) {
    final pred = byId[d.predecessorTaskId];
    if (pred != null) {
      predecessorsOf.putIfAbsent(d.successorTaskId, () => []).add(pred.title);
    }
  }

  final seen = <String>{};
  final rows = <TaskRow>[];
  final undated = <TaskRow>[];
  for (final task in tasks) {
    if (!seen.add(task.id)) {
      continue;
    }
    final state = taskState(task, today);
    if (states != null && !states.contains(state)) {
      continue;
    }
    final row = TaskRow(
      task: task,
      state: state,
      phaseTitle: task.parentTaskId == null ? null : byId[task.parentTaskId]?.title,
      assigneeName: task.assignedTo == null ? null : userNames[task.assignedTo],
      predecessors: predecessorsOf[task.id] ?? const [],
    );
    if (!_matches(query, [
      task.title,
      task.description,
      task.lot,
      row.phaseTitle,
      row.assigneeName,
      taskStatusLabel(task.status),
    ])) {
      continue;
    }
    final s = task.plannedStartDate ?? task.plannedEndDate;
    final e = task.plannedEndDate ?? task.plannedStartDate;
    if (s == null || e == null) {
      undated.add(row);
    } else if (period.overlaps(s, e)) {
      rows.add(row);
    }
  }
  rows.sort((a, b) {
    final sa = a.task.plannedStartDate ?? a.task.plannedEndDate!;
    final sb = b.task.plannedStartDate ?? b.task.plannedEndDate!;
    final c = sa.compareTo(sb);
    return c != 0 ? c : a.task.sortOrder.compareTo(b.task.sortOrder);
  });

  final counts = {for (final s in TaskReportState.values) s: 0};
  for (final row in [...rows, ...undated]) {
    counts[row.state] = counts[row.state]! + 1;
  }
  final included = {for (final r in [...rows, ...undated]) r.task.id};

  return PlanningReport._(
    rows: List.unmodifiable(rows),
    undatedRows: List.unmodifiable(undated),
    counts: counts,
    dependencies: List.unmodifiable(dependencies.where((d) =>
        included.contains(d.predecessorTaskId) &&
        included.contains(d.successorTaskId))),
  );
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

/// Jour d'un document : date enregistrée par l'application telle quelle.
DateTime documentDay(ProjectDocument doc) => dateOnly(doc.createdAt);

class DocumentsReport {
  DocumentsReport._({
    required this.rows,
    required this.byCategory,
    required this.totalBytes,
  });

  final List<ProjectDocument> rows;
  final List<BreakdownEntry> byCategory;
  final int totalBytes;

  int get count => rows.length;
}

DocumentsReport buildDocumentsReport({
  required List<ProjectDocument> documents,
  required ReportPeriod period,
  Set<String>? categories,
  String query = '',
}) {
  final seen = <String>{};
  final rows = <ProjectDocument>[];
  for (final doc in documents) {
    if (!seen.add(doc.id)) {
      continue;
    }
    if (!period.containsDay(documentDay(doc))) {
      continue;
    }
    if (categories != null && !categories.contains(doc.category)) {
      continue;
    }
    if (!_matches(query, [
      doc.title,
      doc.description,
      doc.fileName,
      documentCategoryLabel(doc.category),
    ])) {
      continue;
    }
    rows.add(doc);
  }
  rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final byCategory = <String, BreakdownEntry>{};
  for (final doc in rows) {
    final key = documentCategoryLabel(doc.category);
    byCategory[key] = BreakdownEntry(
      label: key,
      count: (byCategory[key]?.count ?? 0) + 1,
    );
  }
  return DocumentsReport._(
    rows: List.unmodifiable(rows),
    byCategory: _sortedBreakdown(byCategory),
    totalBytes: rows.fold(0, (s, d) => s + d.fileSize),
  );
}

// ---------------------------------------------------------------------------
// Métré (non daté : état actuel, mêmes calculs que le module Quantitatif)
// ---------------------------------------------------------------------------

class MetrageReport {
  MetrageReport._(this.lines);

  final List<QuantityLine> lines;

  int get count => lines.length;
  double get floor => lines.fold(0, (s, l) => s + l.floorArea);
  double get ceiling => lines.fold(0, (s, l) => s + l.ceilingArea);
  double get grossWalls => lines.fold(0, (s, l) => s + l.grossWallArea);
  double get openings => lines.fold(0, (s, l) => s + l.openingsArea);
  double get netWalls => lines.fold(0, (s, l) => s + l.netWallArea);
}

MetrageReport buildMetrageReport({
  required List<QuantityLine> lines,
  String query = '',
}) {
  return MetrageReport._(List.unmodifiable(
    lines.where((l) => _matches(query, [l.spaceName, l.spaceType])),
  ));
}

// ---------------------------------------------------------------------------
// Rapport complet : source unique de l'écran ET des exports
// ---------------------------------------------------------------------------

class ReportIndicator {
  const ReportIndicator(this.label, this.value, {this.hint});
  final String label;
  final String value;
  final String? hint;
}

class ReportBreakdown {
  const ReportBreakdown(this.title, this.entries, {this.amountLabel});
  final String title;
  final List<BreakdownEntry> entries;

  /// Libellé du montant affiché (null : nombre d'éléments uniquement).
  final String? amountLabel;
}

class AnalysisReport {
  AnalysisReport({
    required this.module,
    required this.projectName,
    required this.period,
    required this.activeFilters,
    required this.generatedAt,
    this.purchases,
    this.quotes,
    this.planning,
    this.documents,
    this.metrage,
  });

  final ReportModule module;
  final String projectName;
  final ReportPeriod period;

  /// Filtres complémentaires actifs, en clair (statuts, recherche…).
  final List<String> activeFilters;
  final DateTime generatedAt;
  final PurchasesReport? purchases;
  final QuotesReport? quotes;
  final PlanningReport? planning;
  final DocumentsReport? documents;
  final MetrageReport? metrage;

  String get title {
    switch (module) {
      case ReportModule.achats:
        return 'Rapport des achats — $projectName';
      case ReportModule.planning:
        return 'Rapport de planning — $projectName';
      case ReportModule.devis:
        return 'Rapport des devis — $projectName';
      case ReportModule.documents:
        return 'Rapport des documents — $projectName';
      case ReportModule.metrage:
        return 'Rapport du métré — $projectName';
    }
  }

  String get periodLabel =>
      module.usesPeriod ? period.label : 'Sans période (métré non daté)';

  int get itemCount {
    switch (module) {
      case ReportModule.achats:
        return purchases!.count;
      case ReportModule.planning:
        return planning!.total;
      case ReportModule.devis:
        return quotes!.count;
      case ReportModule.documents:
        return documents!.count;
      case ReportModule.metrage:
        return metrage!.count;
    }
  }

  List<ReportIndicator> get indicators {
    switch (module) {
      case ReportModule.achats:
        final r = purchases!;
        return [
          ReportIndicator('Achats', '${r.count}'),
          ReportIndicator('Lignes d’articles', '${r.lineCount}'),
          ReportIndicator(
            'Montant total connu',
            formatAmount(r.knownTotal),
            hint: r.withoutAmount > 0
                ? 'Hors ${r.withoutAmount} achat(s) sans montant'
                : 'Tous les achats ont un montant',
          ),
          ReportIndicator('Achats sans montant', '${r.withoutAmount}'),
        ];
      case ReportModule.devis:
        final r = quotes!;
        return [
          ReportIndicator('Devis', '${r.count}'),
          ReportIndicator('Total HT connu', formatAmount(r.knownHt)),
          ReportIndicator(
            'Total TTC connu',
            formatAmount(r.knownTtc),
            hint: 'TVA ${(quoteTaxRate * 100).round()} % (règle du module Devis)',
          ),
          ReportIndicator('Devis sans montant', '${r.withoutAmount}'),
        ];
      case ReportModule.planning:
        final r = planning!;
        return [
          ReportIndicator('Tâches', '${r.total}'),
          for (final s in TaskReportState.values)
            ReportIndicator(s.label, '${r.counts[s]}'),
          if (r.undatedRows.isNotEmpty)
            ReportIndicator('Sans dates prévues', '${r.undatedRows.length}'),
        ];
      case ReportModule.documents:
        final r = documents!;
        return [
          ReportIndicator('Documents', '${r.count}'),
          ReportIndicator('Volume total', formatBytes(r.totalBytes)),
          ReportIndicator(
            'Archivés',
            '${r.rows.where((d) => d.isArchived).length}',
          ),
        ];
      case ReportModule.metrage:
        final r = metrage!;
        return [
          ReportIndicator('Espaces', '${r.count}'),
          ReportIndicator('Sol', '${formatQuantity(r.floor)} m²'),
          ReportIndicator('Plafonds', '${formatQuantity(r.ceiling)} m²'),
          ReportIndicator(
            'Murs nets',
            '${formatQuantity(r.netWalls)} m²',
            hint: 'Murs bruts ${formatQuantity(r.grossWalls)} m² − ouvertures '
                '${formatQuantity(r.openings)} m²',
          ),
        ];
    }
  }

  /// Avertissements sur les données (montants manquants, champs absents…).
  List<String> get notes {
    final list = <String>[
      'Date utilisée : ${module.dateRule}'
          '${module.usesPeriod ? ' — bornes incluses' : ''}.',
    ];
    switch (module) {
      case ReportModule.achats:
        final r = purchases!;
        if (r.withoutAmount > 0) {
          list.add('${r.withoutAmount} achat(s) sans aucune ligne : montant '
              'non renseigné. Le total couvre uniquement les montants '
              'renseignés.');
        }
        if (r.zeroPriceLineCount > 0) {
          list.add('${r.zeroPriceLineCount} ligne(s) ont un prix unitaire de 0 '
              '(${r.withZeroPriceLines} achat(s)). L’application enregistre 0 '
              'par défaut : un prix réellement nul ne peut pas être distingué '
              'd’un prix non saisi.');
        }
        list.add('Fournisseur, référence d’achat et statut de paiement ne sont '
            'pas enregistrés par l’application (non disponibles). La « réf. '
            'interne » est l’identifiant technique abrégé de l’achat.');
      case ReportModule.devis:
        final r = quotes!;
        if (r.withoutAmount > 0) {
          list.add('${r.withoutAmount} devis sans ligne : montant non '
              'renseigné, exclu des totaux.');
        }
        list.add('Montants : HT = somme des lignes ; TVA '
            '${(quoteTaxRate * 100).round()} % ; TTC = HT + TVA, comme dans '
            'le module Devis.');
        list.add('L’application ne gère pas de versions de devis : chaque '
            'devis est compté une seule fois. Le client affiché est celui du '
            'projet.');
      case ReportModule.planning:
        list.add('En retard : date de fin prévue dépassée (le jour d’échéance '
            'n’est pas un retard), tâche ni terminée ni annulée, avancement '
            '< 100 %.');
        if (planning!.undatedRows.isNotEmpty) {
          list.add('${planning!.undatedRows.length} tâche(s) sans dates '
              'prévues : listées à part, absentes du Gantt, non filtrables par '
              'période.');
        }
      case ReportModule.documents:
        list.add('Les documents archivés sont inclus et signalés comme tels.');
      case ReportModule.metrage:
        list.add('Surfaces calculées avec les mêmes règles que le module '
            'Quantitatif.');
    }
    return list;
  }

  List<ReportBreakdown> get breakdowns {
    switch (module) {
      case ReportModule.achats:
        return [
          ReportBreakdown(
            'Montant connu par lot',
            purchases!.byLot,
            amountLabel: 'Montant connu',
          ),
          ReportBreakdown(
            'Achats par statut',
            purchases!.byStatus,
            amountLabel: 'Montant connu',
          ),
        ];
      case ReportModule.devis:
        return [
          ReportBreakdown(
            'Devis par statut',
            quotes!.byStatus,
            amountLabel: 'TTC connu',
          ),
        ];
      case ReportModule.planning:
        return [
          ReportBreakdown('Tâches par état', [
            for (final s in TaskReportState.values)
              if (planning!.counts[s]! > 0)
                BreakdownEntry(label: s.label, count: planning!.counts[s]!),
          ]),
        ];
      case ReportModule.documents:
        return [
          ReportBreakdown('Documents par catégorie', documents!.byCategory),
        ];
      case ReportModule.metrage:
        return const [];
    }
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes o';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} Ko';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
