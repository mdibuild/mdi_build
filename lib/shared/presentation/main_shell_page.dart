import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_refresh.dart';
import 'premium_ui.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.child});

  final Widget child;

  static const items = [
    ('/dashboard', Icons.dashboard_outlined, 'Dashboard'),
    ('/projects', Icons.apartment_outlined, 'Projets'),
    ('/planning', Icons.calendar_month_outlined, 'Planning'),
    ('/metrage', Icons.straighten_outlined, 'Métré'),
    ('/quantitatif', Icons.calculate_outlined, 'Quantitatif'),
    ('/devis', Icons.request_quote_outlined, 'Devis'),
    ('/achats', Icons.shopping_cart_outlined, 'Achats'),
    ('/documents', Icons.folder_outlined, 'Documents'),
    ('/chat', Icons.chat_bubble_outline, 'Chat'),
    ('/reports', Icons.picture_as_pdf_outlined, 'Rapports'),
    ('/settings', Icons.settings_outlined, 'Paramètres'),
  ];

  int _currentIndex(String location) {
    final index = items.indexWhere((item) => location.startsWith(item.$1));
    return index >= 0 ? index : 0;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Tu vas être déconnecté de ton compte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await SupabaseService.client.auth.signOut();

    if (!context.mounted) {
      return;
    }

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final colors = context.palette;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex(location),
            onDestinationSelected: (index) => context.go(items[index].$1),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.$2),
                  label: Text(item.$3),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: reloadApp,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Actualiser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.petrol,
                          side: BorderSide(color: colors.petrol, width: 1.6),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Déconnexion'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.danger,
                          side: BorderSide(color: colors.danger, width: 1.6),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: PremiumWatermarkBackground(child: child)),
        ],
      ),
    );
  }
}
