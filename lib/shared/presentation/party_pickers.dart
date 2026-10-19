import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/client.dart';
import '../../core/models/supplier.dart';
import '../../features/settings/presentation/providers/clients_providers.dart';
import '../../features/settings/presentation/providers/suppliers_providers.dart';

/// Liste déroulante « Client » alimentée par la base (fiches clients actives).
///
/// [value] est l'identifiant du client choisi (null = aucun).
/// [onChanged] reçoit aussi la fiche complète (null si « Aucun »).
class ClientPickerField extends ConsumerWidget {
  const ClientPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Client (base de données)',
    this.enabled = true,
  });

  final String? value;
  final void Function(String? id, Client? client) onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeClientsProvider);
    return _PartyDropdown<Client>(
      label: label,
      icon: Icons.person_outline,
      emptyHint: 'Aucun client enregistré (Paramètres → Clients)',
      value: value,
      enabled: enabled,
      async: async,
      idOf: (c) => c.id,
      nameOf: (c) => c.name,
      subtitleOf: (c) => c.contactName.isNotEmpty ? c.contactName : c.phone,
      onChanged: onChanged,
    );
  }
}

/// Liste déroulante « Fournisseur » alimentée par la base (fiches actives).
class SupplierPickerField extends ConsumerWidget {
  const SupplierPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Fournisseur (base de données)',
    this.enabled = true,
  });

  final String? value;
  final void Function(String? id, Supplier? supplier) onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeSuppliersProvider);
    return _PartyDropdown<Supplier>(
      label: label,
      icon: Icons.local_shipping_outlined,
      emptyHint: 'Aucun fournisseur enregistré (Paramètres → Fournisseurs)',
      value: value,
      enabled: enabled,
      async: async,
      idOf: (s) => s.id,
      nameOf: (s) => s.name,
      subtitleOf: (s) => s.contactName.isNotEmpty ? s.contactName : s.phone,
      onChanged: onChanged,
    );
  }
}

class _PartyDropdown<T> extends StatelessWidget {
  const _PartyDropdown({
    required this.label,
    required this.icon,
    required this.emptyHint,
    required this.value,
    required this.enabled,
    required this.async,
    required this.idOf,
    required this.nameOf,
    required this.subtitleOf,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String emptyHint;
  final String? value;
  final bool enabled;
  final AsyncValue<List<T>> async;
  final String Function(T) idOf;
  final String Function(T) nameOf;
  final String Function(T) subtitleOf;
  final void Function(String? id, T? item) onChanged;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
    return async.when(
      loading: () => InputDecorator(
        decoration: decoration,
        child: const LinearProgressIndicator(),
      ),
      error: (error, _) => InputDecorator(
        decoration: decoration.copyWith(errorText: 'Chargement impossible'),
        child: const SizedBox.shrink(),
      ),
      data: (items) {
        // La fiche choisie peut avoir été archivée : on garde la valeur
        // seulement si elle existe encore dans la liste.
        final known = items.any((e) => idOf(e) == value);
        return DropdownButtonFormField<String?>(
          initialValue: known ? value : null,
          isExpanded: true,
          decoration: decoration.copyWith(
            helperText: items.isEmpty ? emptyHint : null,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— Aucun —'),
            ),
            for (final item in items)
              DropdownMenuItem<String?>(
                value: idOf(item),
                child: Text(
                  subtitleOf(item).isEmpty
                      ? nameOf(item)
                      : '${nameOf(item)} · ${subtitleOf(item)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: !enabled
              ? null
              : (id) {
                  T? found;
                  for (final e in items) {
                    if (idOf(e) == id) {
                      found = e;
                    }
                  }
                  onChanged(id, found);
                },
        );
      },
    );
  }
}
