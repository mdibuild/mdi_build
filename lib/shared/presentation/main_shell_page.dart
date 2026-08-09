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

  static const _compactBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final colors = context.palette;
    final selectedIndex = _currentIndex(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactBreakpoint;

        if (isCompact) {
          return Scaffold(
            drawer: Drawer(
              width: 236,
              backgroundColor: colors.surfaceAlt,
              child: SafeArea(
                child: _NavRailContent(
                  colors: colors,
                  selectedIndex: selectedIndex,
                  onSelect: (path) {
                    Navigator.of(context).pop();
                    context.go(path);
                  },
                  onLogout: () => _confirmLogout(context),
                ),
              ),
            ),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Builder(
                    builder: (context) => Container(
                      color: colors.surfaceAlt,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.menu, color: colors.petrol),
                            tooltip: 'Menu',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Text(
                            items[selectedIndex].$3,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colors.petrol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: PremiumWatermarkBackground(child: child)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Container(
                width: 236,
                color: colors.surfaceAlt,
                child: _NavRailContent(
                  colors: colors,
                  selectedIndex: selectedIndex,
                  onSelect: context.go,
                  onLogout: () => _confirmLogout(context),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: PremiumWatermarkBackground(child: child)),
            ],
          ),
        );
      },
    );
  }
}

class _NavRailContent extends StatelessWidget {
  const _NavRailContent({
    required this.colors,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final AppPaletteColors colors;
  final int selectedIndex;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                for (var i = 0; i < MainShellPage.items.length; i++)
                  _RailItem(
                    icon: MainShellPage.items[i].$2,
                    label: MainShellPage.items[i].$3,
                    selected: i == selectedIndex,
                    onTap: () => onSelect(MainShellPage.items[i].$1),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Actualiser',
                  child: OutlinedButton(
                    onPressed: reloadApp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.petrol,
                      backgroundColor: colors.surface,
                      side: BorderSide(color: colors.petrol, width: 1.6),
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Icon(Icons.refresh, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Déconnexion',
                  child: OutlinedButton(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.danger,
                      backgroundColor: colors.surface,
                      side: BorderSide(color: colors.danger, width: 1.6),
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Icon(Icons.logout, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.petrolSoft : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: colors.petrol, width: 1.4)
              : Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.14 : 0.06),
              blurRadius: selected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.petrol,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.petrol.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colors.yellow, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? colors.petrol : colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
