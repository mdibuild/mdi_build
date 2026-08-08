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
    final selectedIndex = _currentIndex(location);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 96,
            color: colors.surface,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _RailItem(
                            icon: items[i].$2,
                            label: items[i].$3,
                            selected: i == selectedIndex,
                            onTap: () => context.go(items[i].$1),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
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
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: PremiumWatermarkBackground(child: child)),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? colors.petrolSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.petrol.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? colors.petrol : colors.textSoft,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? colors.petrol : colors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
