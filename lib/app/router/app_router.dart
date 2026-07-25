import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achats/presentation/achats_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/devis/presentation/devis_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/metrage/presentation/metrage_page.dart';
import '../../features/planning/presentation/planning_page.dart';
import '../../features/projects/presentation/project_form_page.dart';
import '../../features/projects/presentation/projects_page.dart';
import '../../features/quantitatif/presentation/quantitatif_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../shared/presentation/main_shell_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => MainShellPage(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage()),
          GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsPage()),
          GoRoute(
              path: '/projects/new',
              builder: (context, state) => const ProjectFormPage()),
          GoRoute(
              path: '/planning',
              builder: (context, state) => const PlanningPage()),
          GoRoute(
              path: '/metrage',
              builder: (context, state) => const MetragePage()),
          GoRoute(
              path: '/quantitatif',
              builder: (context, state) => const QuantitatifPage()),
          GoRoute(
              path: '/devis', builder: (context, state) => const DevisPage()),
          GoRoute(
              path: '/achats', builder: (context, state) => const AchatsPage()),
          GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsPage()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
          GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsPage()),
          GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],
  );
});
