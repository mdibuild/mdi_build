import 'package:equatable/equatable.dart';

/// Un élément affiché dans la fiche détaillée d'une tuile du dashboard
/// (mini-liste : un titre et un sous-titre facultatif).
class DashboardListItem extends Equatable {
  const DashboardListItem({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  List<Object?> get props => [title, subtitle];
}

class DashboardMetrics extends Equatable {
  const DashboardMetrics({
    required this.projectsCount,
    required this.tasksCount,
    required this.doneTasksCount,
    required this.lateTasksCount,
    required this.quotesCount,
    required this.purchasesCount,
    required this.reportsCount,
    required this.documentsCount,
    required this.autoReportsCount,
    required this.manualReportsCount,
    required this.recentReportTitles,
    required this.highlights,
    this.projectsPreview = const <DashboardListItem>[],
    this.tasksPreview = const <DashboardListItem>[],
    this.purchasesPreview = const <DashboardListItem>[],
    this.reportsPreview = const <DashboardListItem>[],
    this.documentsPreview = const <DashboardListItem>[],
    this.quotesPreview = const <DashboardListItem>[],
  });

  final int projectsCount;
  final int tasksCount;
  final int doneTasksCount;
  final int lateTasksCount;
  final int quotesCount;
  final int purchasesCount;
  final int reportsCount;
  final int documentsCount;
  final int autoReportsCount;
  final int manualReportsCount;
  final List<String> recentReportTitles;
  final List<String> highlights;

  // Aperçus détaillés (quelques éléments) affichés au clic sur une tuile.
  final List<DashboardListItem> projectsPreview;
  final List<DashboardListItem> tasksPreview;
  final List<DashboardListItem> purchasesPreview;
  final List<DashboardListItem> reportsPreview;
  final List<DashboardListItem> documentsPreview;
  final List<DashboardListItem> quotesPreview;

  factory DashboardMetrics.empty() {
    return const DashboardMetrics(
      projectsCount: 0,
      tasksCount: 0,
      doneTasksCount: 0,
      lateTasksCount: 0,
      quotesCount: 0,
      purchasesCount: 0,
      reportsCount: 0,
      documentsCount: 0,
      autoReportsCount: 0,
      manualReportsCount: 0,
      recentReportTitles: <String>[],
      highlights: <String>[],
    );
  }

  @override
  List<Object?> get props => [
        projectsCount,
        tasksCount,
        doneTasksCount,
        lateTasksCount,
        quotesCount,
        purchasesCount,
        reportsCount,
        documentsCount,
        autoReportsCount,
        manualReportsCount,
        recentReportTitles,
        highlights,
        projectsPreview,
        tasksPreview,
        purchasesPreview,
        reportsPreview,
        documentsPreview,
        quotesPreview,
      ];
}
