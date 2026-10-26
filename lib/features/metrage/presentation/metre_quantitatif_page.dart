import 'package:flutter/material.dart';

import '../../../shared/presentation/project_module_scaffold.dart';
import '../../quantitatif/presentation/imported_quantities_page.dart';
import '../../quantitatif/presentation/quantitatif_page.dart';
import 'metrage_page.dart';

/// Module unique « Métré & Quantitatif » : saisie des espaces dans le
/// premier onglet, tableau des surfaces calculées dans le second. Les deux
/// onglets partagent le chantier sélectionné et les mêmes données.
class MetreQuantitatifPage extends StatelessWidget {
  const MetreQuantitatifPage({super.key, this.initialTab = 0});

  /// 0 = Métré, 1 = Quantitatif, 2 = Quantités importées (Excel).
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: ProjectModuleScaffold(
        appBar: AppBar(
          title: const Text('Métré & Quantitatif'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.straighten_outlined), text: 'Métré'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Quantitatif'),
            Tab(icon: Icon(Icons.table_view_outlined), text: 'Quantités Excel'),
          ]),
        ),
        body: const EmbeddedModuleScope(
          child: TabBarView(children: [
            MetragePage(),
            QuantitatifPage(),
            ImportedQuantitiesPage(),
          ]),
        ),
      ),
    );
  }
}
