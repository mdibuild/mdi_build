import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import 'providers/settings_providers.dart';

const _modules = [
  ('planning', 'Alertes planning', 'Tâches en retard, à échéance aujourd\'hui ou proche.'),
  ('chat', 'Alertes chat', 'Nouveau message dans le chat d\'un projet.'),
  ('achats', 'Alertes achats', 'Changement de statut d\'un achat.'),
];

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends ConsumerState<NotificationsSettingsPage> {
  Future<void> _setPreference(
    String profileId,
    String module,
    bool enabled,
  ) async {
    try {
      await ref.read(notificationPreferencesRepositoryProvider).setPreference(
            profileId: profileId,
            module: module,
            enabled: enabled,
          );
      ref.invalidate(notificationPreferencesProvider(profileId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur préférence : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil introuvable.'));
          }

          final prefsAsync =
              ref.watch(notificationPreferencesProvider(profile.id));

          return prefsAsync.when(
            data: (prefs) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const PremiumSectionHeader(
                    title: 'Notifications',
                    subtitle:
                        'Une case par module — décoche ce que tu ne veux pas recevoir.',
                  ),
                  const SizedBox(height: 16),
                  for (final module in _modules) ...[
                    PremiumSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile(
                        title: Text(module.$2),
                        subtitle: Text(module.$3),
                        value: prefs[module.$1] ?? true,
                        onChanged: (value) =>
                            _setPreference(profile.id, module.$1, value),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Erreur préférences : $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur profil : $error')),
      ),
    );
  }
}
