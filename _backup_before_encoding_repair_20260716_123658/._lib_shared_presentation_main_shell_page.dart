import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.child});

  final Widget child;

  static const items = [
    ('/dashboard', Icons.dashboard_outlined, 'Dashboard'),
    ('/projects', Icons.apartment_outlined, 'Projets'),
    ('/planning', Icons.calendar_month_outlined, 'Planning'),
    ('/metrage', Icons.straighten_outlined, 'MÃƒÆ’Ã‚Â©trÃƒÆ’Ã‚Â©'),
    ('/quantitatif', Icons.calculate_outlined, 'Quantitatif'),
    ('/devis', Icons.request_quote_outlined, 'Devis'),
    ('/achats', Icons.shopping_cart_outlined, 'Achats'),
    ('/documents', Icons.folder_outlined, 'Documents'),
    ('/chat', Icons.chat_bubble_outline, 'Chat'),
    ('/reports', Icons.picture_as_pdf_outlined, 'Rapports'),
    ('/settings', Icons.settings_outlined, 'ParamÃƒÆ’Ã‚Â¨tres'),
  ];

  int _currentIndex(String location) {
    final index = items.indexWhere((item) => location.startsWith(item.$1));
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

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
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
