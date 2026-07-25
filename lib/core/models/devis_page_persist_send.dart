import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/estimate_item.dart';
import '../../../core/models/project_quote.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_scaffold_title.dart';
import '../../achats/presentation/providers/purchases_providers.dart';
import '../../achats/presentation/widgets/purchase_form.dart';
import '../../metrage/presentation/providers/spaces_providers.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../presentation/providers/devis_providers.dart';
import '../services/quote_pdf_service.dart';

class DevisPage extends ConsumerStatefulWidget {
  const DevisPage({super.key});

  @override
  ConsumerState<DevisPage> createState() => _DevisPageState();
}

class _DevisPageState extends ConsumerState<DevisPage> {
  final _signatureController = SignaturePadController();
  final _signatureKey = GlobalKey();

  String mode = 'piece';
  String status = 'brouillon';
  double unitPriceWalls = 850;
  double unitPriceCeiling = 700;
  Uint8List? savedSignatureBytes;

  String? _initializedProjectId;
  ProjectQuote? _currentQuote;

  void _applyQuote(ProjectQuote? quote, String projectId) {
    _currentQuote = quote;
    _initializedProjectId = projectId;

    mode = quote?.mode ?? 'piece';
    status = quote?.status ?? 'brouillon';
    unitPriceWalls = quote?.unitPriceWalls ?? 850;
    unitPriceCeiling = quote?.unitPriceCeiling ?? 700;

    final signatureBase64 = quote?.signatureBase64;
    if ((signatureBase64 ?? '').isNotEmpty) {
      try {
        savedSignatureBytes = base64Decode(signatureBase64!);
      } catch (_) {
        savedSignatureBytes = null;
      }
    } else {
      savedSignatureBytes = null;
    }

    _signatureController.clearSilently();
  }

  Future<ProjectQuote?> _persistQuote({
    required BuildContext context,
    required String projectId,
    String? forcedStatus,
    Uint8List? signatureOverride,
    bool clearSignature = false,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (profile == null || authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return null;
    }

    final now = DateTime.now();
    final nextStatus = forcedStatus ?? status;
    final signatureBytes =
        clearSignature ? null : signatureOverride ?? savedSignatureBytes;

    final existing = _currentQuote;

    final quote = ProjectQuote(
      id: existing?.id ?? '',
      companyId: profile.companyId,
      projectId: projectId,
      mode: mode,
      status: nextStatus,
      unitPriceWalls: unitPriceWalls,
      unitPriceCeiling: unitPriceCeiling,
      signatureBase64:
          signatureBytes == null ? null : base64Encode(signatureBytes),
      sentAt:
          nextStatus == 'envoye' ? (existing?.sentAt ?? now) : existing?.sentAt,
      signedAt: nextStatus == 'signe'
          ? (existing?.signedAt ?? now)
          : (clearSignature ? null : existing?.signedAt),
      createdBy: existing?.createdBy ?? authUser.id,
      updatedBy: authUser.id,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final saved = await ref.read(devisRepositoryProvider).upsertQuote(quote);

    ref.invalidate(currentProjectQuoteProvider(projectId));

    if (!mounted) {
      return saved;
    }

    setState(() {
      _currentQuote = saved;
      status = saved.status;
      savedSignatureBytes = signatureBytes;
    });

    return saved;
  }

  Future<void> _openGeneratePurchaseDialog(
    BuildContext context, {
    required List<EstimateItem> items,
    required String projectId,
    required String projectName,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (profile == null || authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return;
    }

    final purchaseItems = items
        .asMap()
        .entries
        .map(
          (entry) => PurchaseItem(
            id: '',
            purchaseId: '',
            article: entry.value.label,
            description: 'Ligne générée depuis le devis',
            quantity: entry.value.quantity,
            unit: entry.value.unit,
            unitPrice: entry.value.unitPrice,
            notes: '',
            sortOrder: entry.key,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )
        .toList();

    final draftPurchase = Purchase(
      id: '',
      companyId: profile.companyId,
      projectId: projectId,
      title: 'Achat généré depuis devis',
      lot: mode == 'corps_etat' ? 'Corps dâDAÃ¢âDAž¢état' : 'Pièce',
      notes: 'Généré depuis le devis de $projectName',
      status: 'brouillon',
      requestedBy: authUser.id,
      approvedBy: null,
      orderedBy: null,
      deliveredBy: null,
      cancelledBy: null,
      archivedBy: null,
      approvedAt: null,
      orderedAt: null,
      deliveredAt: null,
      cancelledAt: null,
      archivedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Générer achat depuis le devis'),
          content: SizedBox(
            width: 760,
            child: PurchaseForm(
              projectOptions: [
                DropdownMenuItem<String>(
                  value: projectId,
                  child: Text(projectName),
                ),
              ],
              initialPurchase: draftPurchase,
              initialItems: purchaseItems,
              onSubmit: (value) async {
                final purchase = Purchase(
                  id: '',
                  companyId: profile.companyId,
                  projectId: value.projectId,
                  title: value.title,
                  lot: value.lot,
                  notes: value.notes,
                  status: 'brouillon',
                  requestedBy: authUser.id,
                  approvedBy: null,
                  orderedBy: null,
                  deliveredBy: null,
                  cancelledBy: null,
                  archivedBy: null,
                  approvedAt: null,
                  orderedAt: null,
                  deliveredAt: null,
                  cancelledAt: null,
                  archivedAt: null,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref.read(purchasesRepositoryProvider).createPurchase(
                      purchase,
                      value.items,
                    );

                ref.invalidate(activePurchasesProvider);
                ref.invalidate(archivedPurchasesProvider);

                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Achat généré depuis le devis.'),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSignature({
    required BuildContext context,
    required String projectId,
  }) async {
    if (!_signatureController.hasSignature) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune signature à enregistrer.')),
      );
      return;
    }

    final boundary = _signatureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (bytes == null || !mounted) {
      return;
    }

    final saved = await _persistQuote(
      context: context,
      projectId: projectId,
      forcedStatus: 'signe',
      signatureOverride: bytes,
    );

    if (saved == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature enregistrée.')),
    );
  }

  Future<void> _clearSignature({
    required BuildContext context,
    required String projectId,
  }) async {
    _signatureController.clear();

    final nextStatus = status == 'signe' ? 'brouillon' : status;

    final saved = await _persistQuote(
      context: context,
      projectId: projectId,
      forcedStatus: nextStatus,
      clearSignature: true,
    );

    if (saved == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature effacée.')),
    );
  }

  Future<void> _saveDraft({
    required BuildContext context,
    required String projectId,
  }) async {
    final saved = await _persistQuote(
      context: context,
      projectId: projectId,
    );

    if (saved == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devis enregistré.')),
    );
  }

  Future<void> _printQuote({
    required BuildContext context,
    required String projectName,
    required List<EstimateItem> items,
  }) async {
    try {
      await QuotePdfService().printQuote(
        projectName: projectName,
        mode: mode,
        status: status,
        unitPriceWalls: unitPriceWalls,
        unitPriceCeiling: unitPriceCeiling,
        items: items,
        signatureBytes: savedSignatureBytes,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur PDF : $error')),
      );
    }
  }

  Future<void> _sendToClient({
    required BuildContext context,
    required String projectId,
    required String projectName,
    required List<EstimateItem> items,
  }) async {
    final nextStatus = status == 'signe' ? 'signe' : 'envoye';

    final saved = await _persistQuote(
      context: context,
      projectId: projectId,
      forcedStatus: nextStatus,
    );

    if (saved == null) {
      return;
    }

    try {
      await QuotePdfService().shareQuote(
        projectName: projectName,
        mode: mode,
        status: saved.status,
        unitPriceWalls: unitPriceWalls,
        unitPriceCeiling: unitPriceCeiling,
        items: items,
        signatureBytes: savedSignatureBytes,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devis prêt à être envoyé.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi : $error')),
      );
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final spacesAsync = ref.watch(spacesProvider);
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Devis')),
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 20),
        child: selectedProjectAsync.when(
          data: (project) {
            if (project == null) {
              return const AppScaffoldTitle(
                title: 'Devis',
                subtitle: 'Choisis un projet.',
              );
            }

            final quoteAsync =
                ref.watch(currentProjectQuoteProvider(project.id));

            return quoteAsync.when(
              data: (quote) {
                if (_initializedProjectId != project.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    setState(() => _applyQuote(quote, project.id));
                  });
                }

                return Column(
                  children: [
                    AppScaffoldTitle(
                      title: 'Devis',
                      subtitle: 'Projet courant : ${project.name}',
                    ),
                    const SizedBox(height: 16),
                    if (isCompact)
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: mode,
                            items: const [
                              DropdownMenuItem(
                                value: 'piece',
                                child: Text('Par pièce'),
                              ),
                              DropdownMenuItem(
                                value: 'corps_etat',
                                child: Text('Par corps dâDAÃ¢âDAž¢état'),
                              ),
                              DropdownMenuItem(
                                value: 'mixte',
                                child: Text('Mixte'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => mode = value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Mode de devis',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: status,
                            items: const [
                              DropdownMenuItem(
                                value: 'brouillon',
                                child: Text('Brouillon'),
                              ),
                              DropdownMenuItem(
                                value: 'envoye',
                                child: Text('Envoyé'),
                              ),
                              DropdownMenuItem(
                                value: 'signe',
                                child: Text('Signé'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => status = value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Statut',
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: mode,
                              items: const [
                                DropdownMenuItem(
                                  value: 'piece',
                                  child: Text('Par pièce'),
                                ),
                                DropdownMenuItem(
                                  value: 'corps_etat',
                                  child: Text('Par corps dâDAÃ¢âDAž¢état'),
                                ),
                                DropdownMenuItem(
                                  value: 'mixte',
                                  child: Text('Mixte'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => mode = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Mode de devis',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'brouillon',
                                  child: Text('Brouillon'),
                                ),
                                DropdownMenuItem(
                                  value: 'envoye',
                                  child: Text('Envoyé'),
                                ),
                                DropdownMenuItem(
                                  value: 'signe',
                                  child: Text('Signé'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => status = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Statut',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (isCompact)
                      Column(
                        children: [
                          TextFormField(
                            initialValue: unitPriceWalls.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              labelText: 'PU peinture murs',
                            ),
                            onChanged: (value) {
                              unitPriceWalls =
                                  double.tryParse(value) ?? unitPriceWalls;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: unitPriceCeiling.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              labelText: 'PU peinture plafond',
                            ),
                            onChanged: (value) {
                              unitPriceCeiling =
                                  double.tryParse(value) ?? unitPriceCeiling;
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: unitPriceWalls.toStringAsFixed(0),
                              decoration: const InputDecoration(
                                labelText: 'PU peinture murs',
                              ),
                              onChanged: (value) {
                                unitPriceWalls =
                                    double.tryParse(value) ?? unitPriceWalls;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: unitPriceCeiling.toStringAsFixed(0),
                              decoration: const InputDecoration(
                                labelText: 'PU peinture plafond',
                              ),
                              onChanged: (value) {
                                unitPriceCeiling =
                                    double.tryParse(value) ?? unitPriceCeiling;
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Signature client',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (savedSignatureBytes != null)
                                  const Chip(label: Text('Enregistrée')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            RepaintBoundary(
                              key: _signatureKey,
                              child: SignaturePad(
                                controller: _signatureController,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _saveSignature(
                                    context: context,
                                    projectId: project.id,
                                  ),
                                  icon: const Icon(Icons.draw_outlined),
                                  label: const Text('Enregistrer signature'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _clearSignature(
                                    context: context,
                                    projectId: project.id,
                                  ),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Effacer'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _saveDraft(
                                    context: context,
                                    projectId: project.id,
                                  ),
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Enregistrer devis'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: spacesAsync.when(
                        data: (spaces) {
                          final items = <EstimateItem>[
                            for (final space in spaces) ...[
                              EstimateItem(
                                label: 'Peinture murs ${space.name}',
                                quantity: space.netWallArea,
                                unit: 'mÃƒâDAš²',
                                unitPrice: unitPriceWalls,
                              ),
                              EstimateItem(
                                label: 'Peinture plafond ${space.name}',
                                quantity: space.ceilingArea,
                                unit: 'mÃƒâDAš²',
                                unitPrice: unitPriceCeiling,
                              ),
                            ],
                          ];

                          final subtotal = items.fold<double>(
                            0,
                            (sum, item) => sum + item.total,
                          );
                          final tax = subtotal * 0.19;
                          final total = subtotal + tax;

                          return Card(
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Mode: ${_modeLabel(mode)}'),
                                    Text('Statut: ${_statusLabel(status)}'),
                                    OutlinedButton.icon(
                                      onPressed: items.isEmpty
                                          ? null
                                          : () => _printQuote(
                                                context: context,
                                                projectName: project.name,
                                                items: items,
                                              ),
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      label: const Text('PDF devis'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: items.isEmpty
                                          ? null
                                          : () => _sendToClient(
                                                context: context,
                                                projectId: project.id,
                                                projectName: project.name,
                                                items: items,
                                              ),
                                      icon: const Icon(Icons.send_outlined),
                                      label: const Text('Envoyer au client'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: items.isEmpty
                                          ? null
                                          : () => _openGeneratePurchaseDialog(
                                                context,
                                                items: items,
                                                projectId: project.id,
                                                projectName: project.name,
                                              ),
                                      icon: const Icon(
                                        Icons.shopping_cart_outlined,
                                      ),
                                      label: const Text('Générer achat'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final item in items)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.label),
                                    subtitle: Text(
                                      '${item.quantity.toStringAsFixed(2)} ${item.unit} ÃƒâDAâDA ${item.unitPrice.toStringAsFixed(2)}',
                                    ),
                                    trailing:
                                        Text(item.total.toStringAsFixed(2)),
                                  ),
                                const Divider(),
                                _line('Sous-total', subtotal),
                                _line('TVA 19%', tax),
                                const Divider(),
                                _line('Total', total, bold: true),
                              ],
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            Center(child: Text('Erreur: $error')),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Erreur devis: $error'),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Erreur projet: $error'),
          ),
        ),
      ),
    );
  }

  String _modeLabel(String value) {
    switch (value) {
      case 'piece':
        return 'Par pièce';
      case 'corps_etat':
        return 'Par corps dâDAÃ¢âDAž¢état';
      case 'mixte':
        return 'Mixte';
      default:
        return value;
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'brouillon':
        return 'Brouillon';
      case 'envoye':
        return 'Envoyé';
      case 'signe':
        return 'Signé';
      default:
        return value;
    }
  }

  Widget _line(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value.toStringAsFixed(2), style: style),
        ],
      ),
    );
  }
}

class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> strokes = [];

  bool get hasSignature => strokes.any((stroke) => stroke.isNotEmpty);

  void startStroke(Offset point) {
    strokes.add([point]);
    notifyListeners();
  }

  void appendPoint(Offset point) {
    if (strokes.isEmpty) {
      startStroke(point);
      return;
    }

    strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    notifyListeners();
  }

  void clearSilently() {
    strokes.clear();
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.controller,
  });

  final SignaturePadController controller;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) =>
          widget.controller.startStroke(details.localPosition),
      onPanUpdate: (details) =>
          widget.controller.appendPoint(details.localPosition),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: CustomPaint(
          painter: SignaturePainter(widget.controller.strokes),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  const SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }

      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
