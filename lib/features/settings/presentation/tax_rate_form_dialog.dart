import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/tax_rate.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import 'providers/tax_rates_providers.dart';

class TaxRateFormDialog extends ConsumerStatefulWidget {
  const TaxRateFormDialog({super.key, this.existing});

  final TaxRate? existing;

  @override
  ConsumerState<TaxRateFormDialog> createState() => _TaxRateFormDialogState();
}

class _TaxRateFormDialogState extends ConsumerState<TaxRateFormDialog> {
  late final TextEditingController labelController;
  late final TextEditingController rateController;
  late bool isDefault;

  bool _saving = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final taxRate = widget.existing;
    labelController = TextEditingController(text: taxRate?.label ?? '');
    rateController = TextEditingController(
      text: taxRate == null ? '' : taxRate.rate.toString(),
    );
    isDefault = taxRate?.isDefault ?? false;
  }

  @override
  void dispose() {
    labelController.dispose();
    rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final label = labelController.text.trim();
    final rate = double.tryParse(rateController.text.trim().replaceAll(',', '.'));

    if (label.isEmpty || rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Libellé et taux (nombre) sont requis.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(taxRatesRepositoryProvider);
      final now = DateTime.now();

      if (isEditing) {
        await repository.updateTaxRate(
          widget.existing!.copyWith(
            label: label,
            rate: rate,
            isDefault: isDefault,
            updatedAt: now,
          ),
        );
      } else {
        final profile = await ref.read(currentProfileProvider.future);
        if (profile == null) {
          throw Exception('Profil utilisateur introuvable.');
        }

        await repository.createTaxRate(
          TaxRate(
            id: '',
            companyId: profile.companyId,
            label: label,
            rate: rate,
            isDefault: isDefault,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      ref.invalidate(activeTaxRatesProvider);
      ref.invalidate(archivedTaxRatesProvider);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Modifier taux' : 'Nouveau taux',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Libellé (ex. TVA 20%)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateController,
                  decoration: const InputDecoration(labelText: 'Taux (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Taux par défaut'),
                  subtitle: const Text('Remplace le taux par défaut existant'),
                  value: isDefault,
                  onChanged: (value) => setState(() => isDefault = value),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
