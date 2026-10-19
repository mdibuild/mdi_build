import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/enums/entity_type.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_quote.dart';
import 'package:mdi_build/core/models/purchase.dart';
import 'package:mdi_build/core/services/party_details.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis.dart';

const _ts = '2026-10-05T12:00:00Z';

Purchase _purchase(String id, {String? supplierId}) => Purchase.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': 'Achat $id',
      'lot': 'Gros œuvre',
      'notes': '',
      'status': 'commande',
      'supplier_id': supplierId,
      'created_at': _ts,
      'updated_at': _ts,
    });

ProjectQuote _quote(String id, {String? clientId}) => ProjectQuote.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': 'Devis $id',
      'mode': 'piece',
      'status': 'envoye',
      'unit_price_walls': 0,
      'unit_price_ceiling': 0,
      'client_id': clientId,
      'created_at': '2026-10-05T10:00:00',
      'updated_at': '2026-10-05T10:00:00',
    });

void main() {
  final october =
      ReportPeriod.custom(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

  test('le lien est lu, enregistré et peut être vidé', () {
    final project = Project.fromMap({
      'id': 'p1',
      'company_id': 'c1',
      'name': 'Villa',
      'client_name': 'M. Benali',
      'client_id': 'cl1',
    });
    expect(project.clientId, 'cl1');
    expect(project.toInsertMap()['client_id'], 'cl1');
    expect(project.toUpdateMap()['client_id'], 'cl1');
    expect(project.copyWith(name: 'X').clientId, 'cl1');
    final cleared = project.copyWith(clientId: null);
    expect(cleared.clientId, isNull);
    expect(cleared.toUpdateMap().containsKey('client_id'), isTrue);

    final purchase = _purchase('a1', supplierId: 's1');
    expect(purchase.toUpdateMap()['supplier_id'], 's1');
    expect(purchase.copyWith(supplierId: 's2').supplierId, 's2');
  });

  test('achats : fournisseur affiché et répartition par fournisseur', () {
    final r = buildPurchasesReport(
      purchases: [
        _purchase('a1', supplierId: 's1'),
        _purchase('a2', supplierId: 's1'),
        _purchase('a3'),
      ],
      itemsByPurchase: const {},
      period: october,
      supplierNames: const {'s1': 'Cosider Matériaux'},
    );
    expect(r.rows.where((x) => x.supplierName == 'Cosider Matériaux').length, 2);
    expect(r.withoutSupplier, 1);
    final labels = {for (final e in r.bySupplier) e.label: e.count};
    expect(labels['Cosider Matériaux'], 2);
    expect(labels['Fournisseur non renseigné'], 1);
    expect(
      buildPurchasesReport(
        purchases: [_purchase('a1', supplierId: 's1'), _purchase('a3')],
        itemsByPurchase: const {},
        period: october,
        supplierNames: const {'s1': 'Cosider Matériaux'},
        query: 'cosider',
      ).count,
      1,
    );
  });

  test('devis : client du devis, sinon celui du projet, sinon le nom saisi',
      () {
    final r = buildQuotesReport(
      quotes: [_quote('q1', clientId: 'cl2'), _quote('q2')],
      itemsByQuote: const {},
      period: october,
      clientName: 'Nom saisi',
      clientNames: const {'cl1': 'Client projet', 'cl2': 'Client devis'},
      projectClientId: 'cl1',
    );
    String? client(String id) =>
        r.rows.firstWhere((x) => x.quote.id == id).clientName;
    expect(client('q1'), 'Client devis');
    expect(client('q2'), 'Client projet');

    final fallback = buildQuotesReport(
      quotes: [_quote('q2')],
      itemsByQuote: const {},
      period: october,
      clientName: 'Nom saisi',
    );
    expect(fallback.rows.single.clientName, 'Nom saisi');
  });

  test('coordonnées : champs vides omis, identifiants légaux pour entreprise',
      () {
    final lines = partyDetailLines(
      contactName: 'Karim',
      phone: '0555 00 00 00',
      email: '',
      address: 'Alger',
      entityType: EntityType.entreprise,
      legalNif: '123',
      legalNis: '',
      legalRc: 'RC9',
      legalArticleImposition: '',
    );
    expect(lines, [
      'Contact : Karim',
      'Alger',
      'Tél. : 0555 00 00 00',
      'NIF : 123',
      'RC : RC9',
    ]);
    final particulier = partyDetailLines(
      contactName: '',
      phone: '',
      email: '',
      address: '',
      entityType: EntityType.particulier,
      legalNif: '123',
      legalNis: '',
      legalRc: '',
      legalArticleImposition: '',
    );
    expect(particulier, isEmpty);
  });
}
