import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette_colors.dart';
import '../../core/services/live_refresh.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/module_refresh_provider.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import 'premium_ui.dart';

/// Clé stable du contenu de la coque : quand la largeur change (rotation
/// portrait/paysage), la coque passe du tiroir à la barre latérale, mais
/// l'écran affiché est déplacé tel quel au lieu d'être recréé. Le projet,
/// la conversation, les saisies en cours et le défilement sont conservés.
final GlobalKey _shellContentKey = GlobalKey(debugLabel: 'shellContent');

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.child});

  final Widget child;

  /// Menu regroupé par thèmes (titre de section, entrées).
  static const sections = <(String, List<(String, IconData, String)>)>[
    (
      'Pilotage',
      [
        ('/dashboard', Icons.space_dashboard_outlined, 'Tableau de bord'),
        ('/projects', Icons.apartment_outlined, 'Projets'),
        ('/checklist', Icons.checklist_rtl_outlined, 'Check-list'),
      ]
    ),
    (
      'Études & chiffrage',
      [
        ('/metrage', Icons.straighten_outlined, 'Métré & Quantitatif'),
        ('/devis', Icons.request_quote_outlined, 'Devis & Factures'),
        ('/technique', Icons.engineering_outlined, 'Technique'),
      ]
    ),
    (
      'Chantier',
      [
        ('/planning', Icons.calendar_month_outlined, 'Planning'),
        ('/achats', Icons.shopping_cart_outlined, 'Achats'),
        ('/documents', Icons.folder_outlined, 'Documents'),
      ]
    ),
    (
      'Échanges',
      [
        ('/chat', Icons.chat_bubble_outline, 'Chat'),
        ('/reports', Icons.picture_as_pdf_outlined, 'Rapports'),
      ]
    ),
    (
      '',
      [
        ('/settings', Icons.settings_outlined, 'Paramètres'),
      ]
    ),
  ];

  static final items = [for (final s in sections) ...s.$2];

  /// Anciennes adresses regroupées dans un module fusionné.
  static const _aliases = {
    '/quantitatif': '/metrage',
    '/factures': '/devis',
  };

  int _currentIndex(String location) {
    var path = location;
    for (final alias in _aliases.entries) {
      if (path.startsWith(alias.key)) {
        path = alias.value;
      }
    }
    final index = items.indexWhere((item) => path.startsWith(item.$1));
    return index >= 0 ? index : 0;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Tu vas être déconnecté de ton compte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: PremiumButtonStyles.destructive(context),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        final content = KeyedSubtree(
          key: _shellContentKey,
          child: LiveRefreshScope(
            child: PremiumWatermarkBackground(child: child),
          ),
        );

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
                          Consumer(
                            builder: (context, ref, _) {
                              final unread = ref.watch(chatUnreadTotalProvider);
                              return IconButton(
                                icon: Badge(
                                  isLabelVisible: unread > 0,
                                  backgroundColor: const Color(0xFFE53935),
                                  label: Text(unread > 99 ? '99+' : '$unread'),
                                  child: Icon(Icons.menu, color: colors.petrol),
                                ),
                                tooltip: unread > 0
                                    ? 'Menu ($unread message(s) non lu(s))'
                                    : 'Menu',
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              );
                            },
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
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Container(
                width: constraints.maxWidth < 1000 ? 212 : 236,
                color: colors.surfaceAlt,
                // Protège la barre des encoches / barres système en paysage.
                child: SafeArea(
                  right: false,
                  child: _NavRailContent(
                    colors: colors,
                    selectedIndex: selectedIndex,
                    onSelect: context.go,
                    onLogout: () => _confirmLogout(context),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SafeArea(
                  left: false,
                  top: false,
                  bottom: false,
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavRailContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrandHeader(colors: colors),
                for (final section in MainShellPage.sections) ...[
                  if (section.$1.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
                      child: Text(
                        section.$1.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: colors.textSoft,
                        ),
                      ),
                    )
                  else
                    Divider(
                      height: 20,
                      indent: 16,
                      endIndent: 16,
                      color: colors.border,
                    ),
                  for (final item in section.$2)
                    Consumer(
                      builder: (context, ref, _) => _RailItem(
                        icon: item.$2,
                        label: item.$3,
                        selected:
                            MainShellPage.items.indexOf(item) == selectedIndex,
                        // Pastille rouge : messages non lus du chat.
                        badge: item.$1 == '/chat'
                            ? ref.watch(chatUnreadTotalProvider)
                            : 0,
                        onTap: () => onSelect(item.$1),
                      ),
                    ),
                ],
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
                    onPressed: () => ref
                        .read(moduleRefreshRevisionProvider.notifier)
                        .refresh(),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colors});

  final AppPaletteColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.apartment, color: colors.petrol, size: 32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MDI Build',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.petrol,
                ),
              ),
              Text(
                'Gestion de chantier',
                style: TextStyle(fontSize: 11, color: colors.textSoft),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Entrée de menu sobre : icône + libellé. L'entrée active est repérée par
/// un fond teinté, un trait doré à gauche et un libellé en gras.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? colors.petrolSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 4,
                    height: selected ? 24 : 0,
                    decoration: BoxDecoration(
                      color: colors.yellow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? colors.petrol : colors.textSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? colors.petrol : colors.text,
                      ),
                    ),
                  ),
                  if (badge > 0) ...[
                    const SizedBox(width: 6),
                    UnreadBubble(count: badge),
                  ],
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
