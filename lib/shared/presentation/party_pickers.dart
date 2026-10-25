import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Raccourcis de contact d'un client ou d'un fournisseur de la base :
/// appeler, écrire un e-mail. N'affiche rien si la fiche est introuvable
/// ou sans coordonnées.
class PartyContactChips extends ConsumerWidget {
  const PartyContactChips.client(this.id, {super.key}) : isClient = true;
  const PartyContactChips.supplier(this.id, {super.key}) : isClient = false;

  final String? id;
  final bool isClient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = this.id;
    if (id == null) {
      return const SizedBox.shrink();
    }
    String? name;
    String phone = '';
    String email = '';
    if (isClient) {
      final all = [
        ...?ref.watch(activeClientsProvider).value,
        ...?ref.watch(archivedClientsProvider).value,
      ];
      for (final c in all) {
        if (c.id == id) {
          name = c.name;
          phone = c.phone.trim();
          email = c.email.trim();
        }
      }
    } else {
      final all = [
        ...?ref.watch(activeSuppliersProvider).value,
        ...?ref.watch(archivedSuppliersProvider).value,
      ];
      for (final s in all) {
        if (s.id == id) {
          name = s.name;
          phone = s.phone.trim();
          email = s.email.trim();
        }
      }
    }
    if (name == null || (phone.isEmpty && email.isEmpty)) {
      return const SizedBox.shrink();
    }

    Future<void> open(Uri uri) async {
      try {
        if (!await launchUrl(uri)) {
          throw StateError('aucune application');
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d’ouvrir ${uri.path}')),
          );
        }
      }
    }

    return Wrap(spacing: 8, runSpacing: 6, children: [
      if (phone.isNotEmpty)
        ActionChip(
          avatar: const Icon(Icons.call_outlined, size: 18),
          label: Text(phone),
          tooltip: 'Appeler $name',
          onPressed: () =>
              open(Uri(scheme: 'tel', path: phone.replaceAll(' ', ''))),
        ),
      if (email.isNotEmpty)
        ActionChip(
          avatar: const Icon(Icons.mail_outline, size: 18),
          label: Text(email),
          tooltip: 'Écrire à $name',
          onPressed: () => open(Uri(scheme: 'mailto', path: email)),
        ),
    ]);
  }
}
