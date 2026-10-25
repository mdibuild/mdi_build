import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/models/client.dart';
import 'package:mdi_build/core/models/supplier.dart';
import 'package:mdi_build/core/models/tax_rate.dart';
import 'package:mdi_build/features/settings/presentation/clients_page.dart';
import 'package:mdi_build/features/settings/presentation/suppliers_page.dart';
import 'package:mdi_build/features/settings/presentation/tax_rates_page.dart';
import 'package:mdi_build/features/settings/presentation/providers/clients_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/tax_rates_providers.dart';
import 'package:mdi_build/shared/presentation/module_filters.dart';

Map<String, dynamic> party(String name, String type) => {
      'id': name,
      'company_id': 'company',
      'name': name,
      'entity_type': type,
      'created_at': '2026-01-01',
      'updated_at': '2026-01-01',
    };

Widget app(Widget page) => ProviderScope(
        overrides: [
          activeClientsProvider.overrideWith((ref) async => [
                Client.fromMap(party('Rachid', 'particulier')),
                Client.fromMap(party('SARL Béton', 'entreprise')),
              ]),
          archivedClientsProvider.overrideWith((ref) async => []),
          activeSuppliersProvider.overrideWith((ref) async => [
                Supplier.fromMap(party('Rachid', 'particulier')),
                Supplier.fromMap(party('SARL Béton', 'entreprise')),
              ]),
          archivedSuppliersProvider.overrideWith((ref) async => []),
          activeTaxRatesProvider.overrideWith((ref) async => [
                for (final rate in [19, 9])
                  TaxRate.fromMap({
                    ...party('TVA $rate', 'entreprise'),
                    'label': 'TVA $rate',
                    'rate': rate,
                    'is_default': rate == 19,
                  }),
              ]),
          archivedTaxRatesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [
            resolvePaletteColors(appPalettes[AppPaletteId.blueprintClair]!, 0),
          ]),
          home: page,
        ));

Future<void> choose(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
      (w) => w is ModuleFilterDropdown<String> && w.label == label);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final page in [const ClientsPage(), const SuppliersPage()]) {
    testWidgets(
        '${page.runtimeType}: combines entity type and search, reset restores results',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      expect(find.text('Rachid'), findsOneWidget);
      expect(find.text('SARL Béton'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rachid');
      await tester.pumpAndSettle();
      await choose(tester, 'Type', 'Entreprise');
      expect(find.widgetWithText(ListTile, 'Rachid'), findsNothing);
      expect(find.text('SARL Béton'), findsNothing);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      expect(find.text('Rachid'), findsOneWidget);
      expect(find.text('SARL Béton'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Taxes: default filter and search combine and reset preserves both rates',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const TaxRatesPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TVA');
    await tester.pumpAndSettle();
    await choose(tester, 'Utilisation', 'Taux par défaut');
    expect(find.text('TVA 19'), findsOneWidget);
    expect(find.text('TVA 9'), findsNothing);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('TVA 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
