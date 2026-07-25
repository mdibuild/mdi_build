import 'package:equatable/equatable.dart';

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
      ];
}
