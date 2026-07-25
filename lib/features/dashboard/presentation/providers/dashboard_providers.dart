import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/dashboard_metrics.dart';
import '../../services/dashboard_metrics_service.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';

final dashboardMetricsServiceProvider =
    Provider<DashboardMetricsService>((ref) {
  return DashboardMetricsService();
});

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);

  if (profile == null) {
    return DashboardMetrics.empty();
  }

  return ref.read(dashboardMetricsServiceProvider).fetch(
        companyId: profile.companyId,
        projectId: project?.id,
      );
});
