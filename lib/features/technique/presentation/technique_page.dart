import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/utils/number_input.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/project_module_scaffold.dart';
import '../../achats/presentation/purchase_draft_dialog.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../domain/concrete_mix.dart';
import '../domain/rebar.dart';

String _n(double v, {int decimals = 2}) =>
    NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'#' * decimals}', 'fr_FR')
        .format(v)
        .replaceAll(' ', ' ')
        .replaceAll(' ', ' ');

/// Module Technique : formulation du béton et ronds à béton.
class TechniquePage extends StatelessWidget {
  const TechniquePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: ProjectModuleScaffold(
        appBar: AppBar(
          title: const Text('Technique'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Béton'),
            Tab(icon: Icon(Icons.linear_scale), text: 'Ronds à béton'),
          ]),
        ),
        body: const TabBarView(children: [ConcreteTab(), RebarTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Béton
// ---------------------------------------------------------------------------

class ConcreteTab extends ConsumerStatefulWidget {
  const ConcreteTab({super.key});

  @override
  ConsumerState<ConcreteTab> createState() => _ConcreteTabState();
}

class _ConcreteTabState extends ConsumerState<ConcreteTab>
    with AutomaticKeepAliveClientMixin {
  double _mpa = 25;
  final _customMpa = TextEditingController();
  bool _byDimensions = false;
  final _volume = TextEditingController(text: '1');
  final _length = TextEditingController(text: '4');
  final _width = TextEditingController(text: '3');
  final _thickness = TextEditingController(text: '0,15');
  final _count = TextEditingController(text: '1');
  final _waste = TextEditingController(text: '5');
  final _wheelbarrow = TextEditingController(text: '60');
  double _bagKg = 50;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [
      _customMpa,
      _volume,
      _length,
      _width,
      _thickness,
      _count,
      _waste,
      _wheelbarrow,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _volumeM3 {
    if (!_byDimensions) {
      return parseDecimal(_volume.text);
    }
    final l = parseDecimal(_length.text);
    final w = parseDecimal(_width.text);
    final t = parseDecimal(_thickness.text);
    final n = parseDecimal(_count.text);
    if (l == null || w == null || t == null || n == null) {
      return null;
    }
    return rectangularVolume(
        lengthM: l, widthM: w, thicknessM: t, count: n.round());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.palette;
    final grade = gradeForMpa(_mpa);
    final volume = _volumeM3;
    final waste = parseDecimal(_waste.text);
    final wheelbarrow = parseDecimal(_wheelbarrow.text);
    final valid = volume != null &&
        volume > 0 &&
        waste != null &&
        waste >= 0 &&
        wheelbarrow != null &&
        wheelbarrow > 0;
    final q = valid
        ? ConcreteQuantities(
            grade: grade,
            volumeM3: volume,
            wastePercent: waste,
            bagKg: _bagKg,
            wheelbarrowL: wheelbarrow,
          )
        : null;
    const numeric = TextInputType.numberWithOptions(decimal: true);

    Widget numField(TextEditingController c, String label, {String? suffix}) =>
        TextField(
          controller: c,
          keyboardType: numeric,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            isDense: true,
            errorText: parseDecimal(c.text) == null ? 'Nombre invalide' : null,
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PremiumHeroHeader(
          title: 'Formulation du béton',
          subtitle: 'De la résistance en MPa aux sacs de ciment, brouettes '
              'de sable et de gravier, et litres d’eau.',
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(
                title: '1. Résistance visée (à 28 jours)',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in concreteGrades)
                    ChoiceChip(
                      label: Text('${g.mpa.toInt()} MPa · ${g.label}'),
                      selected: _mpa == g.mpa && _customMpa.text.isEmpty,
                      onSelected: (_) => setState(() {
                        _mpa = g.mpa;
                        _customMpa.clear();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _customMpa,
                  keyboardType: numeric,
                  decoration: const InputDecoration(
                    labelText: 'Autre résistance',
                    suffixText: 'MPa',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() {
                    final value = parseDecimal(v);
                    if (value != null && value > 0) {
                      _mpa = value;
                    }
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${grade.label} — ${grade.usage}. Dosage : '
                '${_n(grade.cementKg, decimals: 0)} kg de ciment par m³, '
                'rapport E/C ≈ ${_n(grade.waterCementRatio)}.',
              ),
              if (_mpa >= 30)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'À partir de 30 MPa, faites valider la formulation par une '
                    'étude de laboratoire et des essais d’écrasement.',
                    style: TextStyle(
                        color: colors.danger, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(title: '2. Volume à couler'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Volume connu')),
                  ButtonSegment(
                      value: true,
                      label: Text('Longueur × largeur × épaisseur')),
                ],
                selected: {_byDimensions},
                onSelectionChanged: (s) =>
                    setState(() => _byDimensions = s.first),
              ),
              const SizedBox(height: 12),
              if (!_byDimensions)
                SizedBox(
                    width: 260,
                    child: numField(_volume, 'Volume', suffix: 'm³'))
              else
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                      width: 150,
                      child: numField(_length, 'Longueur', suffix: 'm')),
                  SizedBox(
                      width: 150,
                      child: numField(_width, 'Largeur', suffix: 'm')),
                  SizedBox(
                      width: 150,
                      child: numField(_thickness, 'Épaisseur', suffix: 'm')),
                  SizedBox(width: 120, child: numField(_count, 'Nombre')),
                  if (volume != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('= ${_n(volume, decimals: 3)} m³',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                    width: 150, child: numField(_waste, 'Pertes', suffix: '%')),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<double>(
                    initialValue: _bagKg,
                    isDense: true,
                    decoration: const InputDecoration(
                        labelText: 'Sac de ciment', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 25, child: Text('25 kg')),
                      DropdownMenuItem(value: 35, child: Text('35 kg')),
                      DropdownMenuItem(value: 50, child: Text('50 kg')),
                    ],
                    onChanged: (v) => setState(() => _bagKg = v ?? 50),
                  ),
                ),
                SizedBox(
                    width: 150,
                    child: numField(_wheelbarrow, 'Brouette', suffix: 'L')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (q == null)
          const PremiumSurfaceCard(
            child: Text('Complète le volume et les paramètres pour voir les '
                'quantités.'),
          )
        else ...[
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumSectionHeader(
                  title: '3. Quantités à prévoir',
                  subtitle:
                      '${_n(q.orderedVolume, decimals: 3)} m³ pertes comprises',
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _ResultTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Ciment',
                    main: '${q.cementBagsRounded} sacs de ${_bagKg.toInt()} kg',
                    detail: '${_n(q.cementKg, decimals: 0)} kg '
                        '(${_n(q.cementBags, decimals: 1)} sacs exacts)',
                  ),
                  _ResultTile(
                    icon: Icons.grain,
                    title: 'Sable 0/5',
                    main: '${q.sandWheelbarrows} brouettes',
                    detail: '${_n(q.sandM3, decimals: 3)} m³ · '
                        '${_n(q.sandL, decimals: 0)} L',
                  ),
                  _ResultTile(
                    icon: Icons.landscape_outlined,
                    title: 'Gravier 5/25',
                    main: '${q.gravelWheelbarrows} brouettes',
                    detail: '${_n(q.gravelM3, decimals: 3)} m³ · '
                        '${_n(q.gravelL, decimals: 0)} L',
                  ),
                  _ResultTile(
                    icon: Icons.water_drop_outlined,
                    title: 'Eau',
                    main: '${_n(q.waterL, decimals: 0)} L',
                    detail: 'à ajuster selon l’humidité du sable',
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumSectionHeader(
                  title:
                      'Recette de chantier pour 1 sac de ${_bagKg.toInt()} kg',
                  subtitle:
                      'donne environ ${_n(q.concretePerBagM3 * 1000, decimals: 0)} L de béton',
                ),
                const SizedBox(height: 10),
                _RecipeLine(
                  label: 'Sable',
                  value: '${_n(q.sandPerBagL, decimals: 0)} L',
                  alt:
                      '≈ ${_n(q.sandPerBagWheelbarrows, decimals: 1)} brouette(s) '
                      'ou ${_n(q.sandPerBagBuckets, decimals: 1)} seaux de 10 L',
                ),
                _RecipeLine(
                  label: 'Gravier',
                  value: '${_n(q.gravelPerBagL, decimals: 0)} L',
                  alt:
                      '≈ ${_n(q.gravelPerBagWheelbarrows, decimals: 1)} brouette(s) '
                      'ou ${_n(q.gravelPerBagBuckets, decimals: 1)} seaux de 10 L',
                ),
                _RecipeLine(
                  label: 'Eau',
                  value: '${_n(q.waterPerBagL, decimals: 0)} L',
                  alt:
                      '≈ ${_n(q.waterPerBagBuckets, decimals: 1)} seaux de 10 L',
                ),
                const SizedBox(height: 8),
                Text(
                  'Volumes de granulats secs mesurés en vrac. Dosages '
                  'indicatifs (ciment CPJ / CEM II 42,5) : ils ne remplacent '
                  'pas une étude de formulation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CreatePurchaseButton(
            title: 'Achat béton ${_n(_mpa, decimals: 1)} MPa',
            lot: 'Gros œuvre',
            notes: 'Généré par le module Technique : '
                '${_n(q.orderedVolume, decimals: 3)} m³ de béton '
                '${_n(_mpa, decimals: 1)} MPa, pertes ${_n(q.wastePercent)} %.',
            lines: [
              PurchaseDraftLine(
                article: 'Ciment CPJ 42,5 (sac ${_bagKg.toInt()} kg)',
                quantity: q.cementBagsRounded.toDouble(),
                unit: 'sac',
              ),
              PurchaseDraftLine(
                article: 'Sable 0/5',
                quantity: double.parse(q.sandM3.toStringAsFixed(2)),
                unit: 'm³',
              ),
              PurchaseDraftLine(
                article: 'Gravier 5/25',
                quantity: double.parse(q.gravelM3.toStringAsFixed(2)),
                unit: 'm³',
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ronds à béton
// ---------------------------------------------------------------------------

class RebarTab extends ConsumerStatefulWidget {
  const RebarTab({super.key});

  @override
  ConsumerState<RebarTab> createState() => _RebarTabState();
}

class _RebarLineDraft {
  _RebarLineDraft()
      : count = TextEditingController(text: '1'),
        length = TextEditingController(text: '12');

  int diameter = 12;
  final TextEditingController count;
  final TextEditingController length;

  RebarLine? get line {
    final n = parseDecimal(count.text);
    final l = parseDecimal(length.text);
    if (n == null || l == null) {
      return null;
    }
    return RebarLine(diameterMm: diameter, count: n.round(), lengthM: l);
  }

  void dispose() {
    count.dispose();
    length.dispose();
  }
}

class _RebarTabState extends ConsumerState<RebarTab>
    with AutomaticKeepAliveClientMixin {
  int _diameter = 12;
  bool _lengthToWeight = true;
  final _input = TextEditingController(text: '12');
  final _waste = TextEditingController(text: '5');
  final List<_RebarLineDraft> _lines = [_RebarLineDraft()];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _waste.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.palette;
    final input = parseDecimal(_input.text);
    final perMeter = rebarKgPerMeter(_diameter.toDouble());
    final waste = parseDecimal(_waste.text) ?? 0;
    final summary = RebarSummary(
      _lines.map((l) => l.line).whereType<RebarLine>(),
      wastePercent: waste,
    );
    const numeric = TextInputType.numberWithOptions(decimal: true);

    String converterResult() {
      if (input == null || input < 0) {
        return 'Saisie invalide';
      }
      if (_lengthToWeight) {
        final kg =
            rebarWeightKg(diameterMm: _diameter.toDouble(), lengthM: input);
        return '${_n(input)} m de Ø$_diameter = ${_n(kg)} kg';
      }
      final m = rebarLengthM(diameterMm: _diameter.toDouble(), weightKg: input);
      return '${_n(input)} kg de Ø$_diameter = ${_n(m)} m '
          '(${barsForLength(m)} barre(s) de 12 m)';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PremiumHeroHeader(
          title: 'Ronds à béton',
          subtitle: 'Poids ⇄ longueur des aciers HA : kg/m = 0,00617 × Ø² '
              '(règle de chantier Ø² / 162).',
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(title: 'Convertisseur'),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: _diameter,
                    isDense: true,
                    decoration: const InputDecoration(
                        labelText: 'Diamètre', isDense: true),
                    items: [
                      for (final d in rebarDiameters)
                        DropdownMenuItem(value: d, child: Text('Ø$d mm')),
                    ],
                    onChanged: (v) => setState(() => _diameter = v ?? 12),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Longueur → poids')),
                    ButtonSegment(
                        value: false, label: Text('Poids → longueur')),
                  ],
                  selected: {_lengthToWeight},
                  onSelectionChanged: (s) =>
                      setState(() => _lengthToWeight = s.first),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _input,
                    keyboardType: numeric,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _lengthToWeight ? 'Longueur' : 'Poids',
                      suffixText: _lengthToWeight ? 'm' : 'kg',
                      isDense: true,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(converterResult(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Ø$_diameter : ${_n(perMeter, decimals: 3)} kg/m · '
                  'section ${_n(rebarSectionCm2(_diameter.toDouble()), decimals: 2)} cm² · '
                  'barre de 12 m = ${_n(perMeter * 12)} kg'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSectionHeader(title: 'Tableau des aciers HA'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 38,
                  columns: const [
                    DataColumn(label: Text('Ø (mm)')),
                    DataColumn(label: Text('Section (cm²)'), numeric: true),
                    DataColumn(label: Text('kg/m'), numeric: true),
                    DataColumn(label: Text('Barre 12 m (kg)'), numeric: true),
                    DataColumn(label: Text('m pour 1 t'), numeric: true),
                  ],
                  rows: [
                    for (final d in rebarDiameters)
                      DataRow(
                        selected: d == _diameter,
                        onSelectChanged: (_) => setState(() => _diameter = d),
                        cells: [
                          DataCell(Text('Ø$d')),
                          DataCell(Text(_n(rebarSectionCm2(d.toDouble())))),
                          DataCell(Text(
                              _n(rebarKgPerMeter(d.toDouble()), decimals: 3))),
                          DataCell(
                              Text(_n(rebarKgPerMeter(d.toDouble()) * 12))),
                          DataCell(Text(_n(
                              rebarLengthM(
                                  diameterMm: d.toDouble(), weightKg: 1000),
                              decimals: 0))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumSectionHeader(
                title: 'Nomenclature d’aciers',
                subtitle: 'Total ${_n(summary.totalWeightKg)} kg '
                    '(pertes et recouvrements ${_n(waste)} %)',
                trailing: FilledButton.icon(
                  onPressed: () =>
                      setState(() => _lines.add(_RebarLineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Ligne'),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _lines.length; i++)
                Padding(
                  key: ObjectKey(_lines[i]),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 96,
                      child: DropdownButtonFormField<int>(
                        initialValue: _lines[i].diameter,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Ø', isDense: true),
                        items: [
                          for (final d in rebarDiameters)
                            DropdownMenuItem(value: d, child: Text('Ø$d')),
                        ],
                        onChanged: (v) =>
                            setState(() => _lines[i].diameter = v ?? 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].count,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Nombre', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].length,
                        keyboardType: numeric,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Longueur',
                            suffixText: 'm',
                            isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i).dispose()),
                      icon: Icon(Icons.delete_outline, color: colors.danger),
                    ),
                  ]),
                ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _waste,
                  keyboardType: numeric,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Pertes / recouvrements',
                      suffixText: '%',
                      isDense: true),
                ),
              ),
              const SizedBox(height: 12),
              for (final d in summary.diameters)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Ø$d : ${_n(summary.lengthOf(d))} m · '
                    '${_n(summary.weightOf(d))} kg · '
                    '${summary.barsOf(d)} barre(s) de 12 m',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (summary.diameters.isNotEmpty)
          _CreatePurchaseButton(
            title: 'Achat ronds à béton',
            lot: 'Gros œuvre',
            notes: 'Généré par le module Technique : nomenclature d’aciers, '
                'pertes ${_n(waste)} %.',
            lines: [
              for (final d in summary.diameters)
                PurchaseDraftLine(
                  article: 'Rond à béton HA Ø$d',
                  description: '${summary.barsOf(d)} barre(s) de 12 m',
                  quantity:
                      double.parse(summary.weightOf(d).toStringAsFixed(1)),
                  unit: 'kg',
                ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.main,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String main;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: colors.petrol, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(main,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _RecipeLine extends StatelessWidget {
  const _RecipeLine(
      {required this.label, required this.value, required this.alt});

  final String label;
  final String value;
  final String alt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(spacing: 8, children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(alt),
        ]),
      );
}

/// Crée un achat brouillon sur le chantier sélectionné, avec choix du
/// fournisseur dans le formulaire.
class _CreatePurchaseButton extends ConsumerWidget {
  const _CreatePurchaseButton({
    required this.title,
    required this.lot,
    required this.notes,
    required this.lines,
  });

  final String title;
  final String lot;
  final String notes;
  final List<PurchaseDraftLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(selectedProjectProvider).value;
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: project == null
            ? null
            : () => showPurchaseDraftDialog(
                  context,
                  ref,
                  projectId: project.id,
                  projectName: project.name,
                  title: title,
                  lot: lot,
                  notes: notes,
                  lines: lines,
                ),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: Text(project == null
            ? 'Choisis un chantier pour créer l’achat'
            : 'Créer l’achat pour ${project.name}'),
      ),
    );
  }
}
