import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/estimate_item.dart';
import '../../../core/models/project_quote.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../achats/presentation/providers/purchases_providers.dart';
import '../../achats/presentation/widgets/purchase_form.dart';
import '../../metrage/presentation/providers/spaces_providers.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../../reports/presentation/providers/reports_providers.dart';
import 'providers/devis_providers.dart';
import '../services/quote_pdf_service.dart';
import '../services/quote_report_bridge_service.dart';

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
            description: 'Ligne g\u00e9n\u00e9r\u00e9e depuis le devis',
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
      title: 'Achat g\u00e9n\u00e9r\u00e9 depuis devis',
      lot: mode == 'corps_etat' ? 'Corps d\u2019\u00e9tat' : 'Pi\u00e8ce',
      notes: 'G\u00e9n\u00e9r\u00e9 depuis le devis de $projectName',
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
          title: const Text('G\u00e9n\u00e9rer achat depuis le devis'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
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
                    Navigator.of(dialogContext).pop();
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Achat g\u00e9n\u00e9r\u00e9 depuis le devis.',
                        ),
                      ),
                    );
                  }
                },
              ),
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
        const SnackBar(
          content: Text('Aucune signature \u00e0 enregistrer.'),
        ),
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

    if (bytes == null || !context.mounted) {
      return;
    }

    final saved = await _persistQuote(
      context: context,
      projectId: projectId,
      forcedStatus: 'signe',
      signatureOverride: bytes,
    );

    if (saved == null || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature enregistr\u00e9e.')),
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

    if (saved == null || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature effac\u00e9e.')),
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

    if (saved == null || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devis enregistr\u00e9.')),
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

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devis pr\u00eat \u00e0 \u00eatre envoy\u00e9.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi : $error')),
      );
    }
  }

  Future<void> _generateQuoteReport({
    required BuildContext context,
    required String projectId,
    required String projectName,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);

    if (profile == null) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil utilisateur introuvable.')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 7));
      final periodEnd = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );

      final report = await QuoteReportBridgeService().generateQuoteReport(
        reportsRepository: ref.read(reportsRepositoryProvider),
        companyId: profile.companyId,
        projectId: projectId,
        projectName: projectName,
        authorId: profile.id,
        quote: _currentQuote,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      ref.invalidate(activeReportsProvider);
      ref.invalidate(archivedReportsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Rapport devis g\u00e9n\u00e9r\u00e9 : ${report.title}'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur rapport devis : $error')),
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
    final isCompact = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      appBar: AppBar(title: const Text('Devis')),
      body: SafeArea(
        child: selectedProjectAsync.when(
          data: (project) {
            if (project == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Choisis un projet pour afficher le devis.'),
                ),
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

                return spacesAsync.when(
                  data: (spaces) {
                    final items = <EstimateItem>[
                      for (final space in spaces) ...[
                        EstimateItem(
                          label: 'Peinture murs ${space.name}',
                          quantity: space.netWallArea,
                          unit: 'm\u00b2',
                          unitPrice: unitPriceWalls,
                        ),
                        EstimateItem(
                          label: 'Peinture plafond ${space.name}',
                          quantity: space.ceilingArea,
                          unit: 'm\u00b2',
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

                    return ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.all(isCompact ? 12 : 20),
                      children: [
                        _DevisHeroCard(
                          projectName: project.name,
                          status: status,
                          total: total,
                          itemCount: items.length,
                        ),
                        const SizedBox(height: 16),
                        _DevisConfigurationCard(
                          mode: mode,
                          status: status,
                          unitPriceWalls: unitPriceWalls,
                          unitPriceCeiling: unitPriceCeiling,
                          onModeChanged: (value) {
                            if (value != null) {
                              setState(() => mode = value);
                            }
                          },
                          onStatusChanged: (value) {
                            if (value != null) {
                              setState(() => status = value);
                            }
                          },
                          onWallPriceChanged: (value) {
                            setState(() => unitPriceWalls = value);
                          },
                          onCeilingPriceChanged: (value) {
                            setState(() => unitPriceCeiling = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SignatureCard(
                          signatureKey: _signatureKey,
                          signatureController: _signatureController,
                          savedSignatureBytes: savedSignatureBytes,
                          compact: isCompact,
                          onSaveSignature: () => _saveSignature(
                            context: context,
                            projectId: project.id,
                          ),
                          onClearSignature: () => _clearSignature(
                            context: context,
                            projectId: project.id,
                          ),
                          onSaveDraft: () => _saveDraft(
                            context: context,
                            projectId: project.id,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _QuoteActionsCard(
                          mode: mode,
                          status: status,
                          itemsEmpty: items.isEmpty,
                          onPrint: () => _printQuote(
                            context: context,
                            projectName: project.name,
                            items: items,
                          ),
                          onSend: () => _sendToClient(
                            context: context,
                            projectId: project.id,
                            projectName: project.name,
                            items: items,
                          ),
                          onReport: () => _generateQuoteReport(
                            context: context,
                            projectId: project.id,
                            projectName: project.name,
                          ),
                          onPurchase: () => _openGeneratePurchaseDialog(
                            context,
                            items: items,
                            projectId: project.id,
                            projectName: project.name,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _EstimateItemsCard(
                          items: items,
                          subtotal: subtotal,
                          tax: tax,
                          total: total,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur : $error')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur devis : $error')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur projet : $error')),
        ),
      ),
    );
  }
}

class _DevisHeroCard extends StatelessWidget {
  const _DevisHeroCard({
    required this.projectName,
    required this.status,
    required this.total,
    required this.itemCount,
  });

  final String projectName;
  final String status;
  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.petrol,
              AppColors.petrol.withValues(alpha: 0.84),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;

            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devis projet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  projectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            );

            final metrics = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroMetric(
                  label: 'Total TTC',
                  value: _money(total),
                ),
                _HeroMetric(
                  label: 'Lignes',
                  value: itemCount.toString(),
                ),
                _HeroMetric(
                  label: 'Statut',
                  value: _statusLabel(status),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 16),
                  metrics,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 18),
                Flexible(child: metrics),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.yellow,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevisConfigurationCard extends StatelessWidget {
  const _DevisConfigurationCard({
    required this.mode,
    required this.status,
    required this.unitPriceWalls,
    required this.unitPriceCeiling,
    required this.onModeChanged,
    required this.onStatusChanged,
    required this.onWallPriceChanged,
    required this.onCeilingPriceChanged,
  });

  final String mode;
  final String status;
  final double unitPriceWalls;
  final double unitPriceCeiling;
  final ValueChanged<String?> onModeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<double> onWallPriceChanged;
  final ValueChanged<double> onCeilingPriceChanged;

  @override
  Widget build(BuildContext context) {
    return _PremiumDevisCard(
      title: 'Configuration du devis',
      subtitle: 'Mode, statut et prix unitaires.',
      icon: Icons.tune_outlined,
      child: Column(
        children: [
          _ResponsiveFormGrid(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _safeMode(mode),
                decoration: const InputDecoration(labelText: 'Mode de devis'),
                items: const [
                  DropdownMenuItem(
                    value: 'piece',
                    child: Text('Par pi\u00e8ce'),
                  ),
                  DropdownMenuItem(
                    value: 'corps_etat',
                    child: Text('Par corps d\u2019\u00e9tat'),
                  ),
                  DropdownMenuItem(
                    value: 'mixte',
                    child: Text('Mixte'),
                  ),
                ],
                onChanged: onModeChanged,
              ),
              DropdownButtonFormField<String>(
                initialValue: _safeStatus(status),
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(
                    value: 'brouillon',
                    child: Text('Brouillon'),
                  ),
                  DropdownMenuItem(
                    value: 'envoye',
                    child: Text('Envoy\u00e9'),
                  ),
                  DropdownMenuItem(
                    value: 'signe',
                    child: Text('Sign\u00e9'),
                  ),
                ],
                onChanged: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveFormGrid(
            children: [
              TextFormField(
                key: ValueKey('walls-$unitPriceWalls'),
                initialValue: unitPriceWalls.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PU peinture murs',
                  suffixText: 'DA',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed != null) {
                    onWallPriceChanged(parsed);
                  }
                },
              ),
              TextFormField(
                key: ValueKey('ceiling-$unitPriceCeiling'),
                initialValue: unitPriceCeiling.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PU peinture plafond',
                  suffixText: 'DA',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed != null) {
                    onCeilingPriceChanged(parsed);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.signatureKey,
    required this.signatureController,
    required this.savedSignatureBytes,
    required this.compact,
    required this.onSaveSignature,
    required this.onClearSignature,
    required this.onSaveDraft,
  });

  final GlobalKey signatureKey;
  final SignaturePadController signatureController;
  final Uint8List? savedSignatureBytes;
  final bool compact;
  final VoidCallback onSaveSignature;
  final VoidCallback onClearSignature;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return _PremiumDevisCard(
      title: 'Signature client',
      subtitle: 'Fais signer le client puis enregistre le devis.',
      icon: Icons.draw_outlined,
      trailing: savedSignatureBytes == null
          ? null
          : const _StatusBadge(
              label: 'Enregistr\u00e9e',
              color: AppColors.success,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (savedSignatureBytes != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Image.memory(
                savedSignatureBytes!,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
          ],
          RepaintBoundary(
            key: signatureKey,
            child: SignaturePad(
              controller: signatureController,
              compact: compact,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onSaveSignature,
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Enregistrer signature'),
              ),
              OutlinedButton.icon(
                onPressed: onClearSignature,
                icon: const Icon(Icons.clear),
                label: const Text('Effacer'),
              ),
              OutlinedButton.icon(
                onPressed: onSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer devis'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteActionsCard extends StatelessWidget {
  const _QuoteActionsCard({
    required this.mode,
    required this.status,
    required this.itemsEmpty,
    required this.onPrint,
    required this.onSend,
    required this.onReport,
    required this.onPurchase,
  });

  final String mode;
  final String status;
  final bool itemsEmpty;
  final VoidCallback onPrint;
  final VoidCallback onSend;
  final VoidCallback onReport;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return _PremiumDevisCard(
      title: 'Actions devis',
      subtitle: 'Exporter, envoyer, convertir ou generer un rapport.',
      icon: Icons.bolt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusBadge(
                label: 'Mode : ${_modeLabel(mode)}',
                color: AppColors.petrol,
              ),
              _StatusBadge(
                label: 'Statut : ${_statusLabel(status)}',
                color: _statusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: itemsEmpty ? null : onPrint,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF devis'),
              ),
              FilledButton.icon(
                onPressed: itemsEmpty ? null : onSend,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Envoyer au client'),
              ),
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Rapport auto'),
              ),
              ElevatedButton.icon(
                onPressed: itemsEmpty ? null : onPurchase,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('G\u00e9n\u00e9rer achat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstimateItemsCard extends StatelessWidget {
  const _EstimateItemsCard({
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final List<EstimateItem> items;
  final double subtotal;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _PremiumDevisCard(
      title: 'Lignes du devis',
      subtitle: '${items.length} ligne(s) calculee(s) depuis le metrage.',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune ligne disponible.'),
            )
          else
            for (final item in items) _EstimateItemRow(item: item),
          const Divider(height: 28),
          _QuoteTotalLine(label: 'Sous-total', value: subtotal),
          _QuoteTotalLine(label: 'TVA 19%', value: tax),
          const Divider(height: 24),
          _QuoteTotalLine(label: 'Total TTC', value: total, important: true),
        ],
      ),
    );
  }
}

class _EstimateItemRow extends StatelessWidget {
  const _EstimateItemRow({
    required this.item,
  });

  final EstimateItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity.toStringAsFixed(2)} ${item.unit} \u00d7 ${_money(item.unitPrice)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _money(item.total),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.petrol,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteTotalLine extends StatelessWidget {
  const _QuoteTotalLine({
    required this.label,
    required this.value,
    this.important = false,
  });

  final String label;
  final double value;
  final bool important;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: important ? FontWeight.w900 : FontWeight.w700,
      fontSize: important ? 18 : 14,
      color: important ? AppColors.petrol : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money(value), style: style),
        ],
      ),
    );
  }
}

class _PremiumDevisCard extends StatelessWidget {
  const _PremiumDevisCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.petrol),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSoft,
                            ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFormGrid extends StatelessWidget {
  const _ResponsiveFormGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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
    required this.compact,
  });

  final SignaturePadController controller;
  final bool compact;

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
        height: widget.compact ? 148 : 190,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
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
      ..color = AppColors.petrol
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

String _modeLabel(String value) {
  switch (value) {
    case 'piece':
      return 'Par pi\u00e8ce';
    case 'corps_etat':
      return 'Par corps d\u2019\u00e9tat';
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
      return 'Envoy\u00e9';
    case 'signe':
      return 'Sign\u00e9';
    default:
      return value;
  }
}

Color _statusColor(String value) {
  switch (value) {
    case 'brouillon':
      return AppColors.textSoft;
    case 'envoye':
      return AppColors.info;
    case 'signe':
      return AppColors.success;
    default:
      return AppColors.petrol;
  }
}

String _safeMode(String value) {
  const values = {'piece', 'corps_etat', 'mixte'};
  return values.contains(value) ? value : 'piece';
}

String _safeStatus(String value) {
  const values = {'brouillon', 'envoye', 'signe'};
  return values.contains(value) ? value : 'brouillon';
}

String _money(double value) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} DA';
}
