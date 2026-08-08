import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/project.dart';
import '../../features/achats/presentation/achats_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/devis/presentation/devis_list_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/metrage/presentation/metrage_page.dart';
import '../../features/planning/presentation/planning_page.dart';
import '../../features/projects/presentation/project_form_page.dart';
import '../../features/projects/presentation/projects_page.dart';
import '../../features/quantitatif/presentation/quantitatif_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/settings/presentation/appearance_settings_page.dart';
import '../../features/settings/presentation/clients_page.dart';
import '../../features/settings/presentation/company_settings_page.dart';
import '../../features/settings/presentation/notifications_settings_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/suppliers_page.dart';
import '../../features/settings/presentation/tax_rates_page.dart';
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
              builder: (context, state) =>
                  ProjectFormPage(project: state.extra as Project?)),
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
              path: '/devis',
              builder: (context, state) => const DevisListPage()),
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
          GoRoute(
              path: '/settings/company',
              builder: (context, state) => const CompanySettingsPage()),
          GoRoute(
              path: '/settings/clients',
              builder: (context, state) => const ClientsPage()),
          GoRoute(
              path: '/settings/suppliers',
              builder: (context, state) => const SuppliersPage()),
          GoRoute(
              path: '/settings/taxes',
              builder: (context, state) => const TaxRatesPage()),
          GoRoute(
              path: '/settings/notifications',
              builder: (context, state) => const NotificationsSettingsPage()),
          GoRoute(
              path: '/settings/appearance',
              builder: (context, state) => const AppearanceSettingsPage()),
        ],
      ),
    ],
  );
});
