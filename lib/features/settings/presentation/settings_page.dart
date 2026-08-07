import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/settings_user_entry.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import 'providers/settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _updatingIds = <String>{};
  String _roleFilter = 'all';

  static const List<String> _roles = <String>[
    'owner',
    'admin',
    'manager',
    'member',
    'viewer',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SettingsUserEntry> _filterUsers(List<SettingsUserEntry> users) {
    final query = _searchController.text.trim().toLowerCase();

    return users.where((user) {
      final roleMatch = _roleFilter == 'all' || user.role == _roleFilter;
      final textMatch = query.isEmpty ||
          user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);

      return roleMatch && textMatch;
    }).toList();
  }

  Future<void> _updateRole(SettingsUserEntry user, String newRole) async {
    setState(() => _updatingIds.add(user.id));

    try {
      await ref.read(settingsRepositoryProvider).updateUserRole(
            userId: user.id,
            role: newRole,
          );

      ref.invalidate(companyUsersProvider(user.companyId));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle mis à jour : ${user.displayName}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur rôle : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(user.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Profil utilisateur introuvable.'),
            );
          }

          final usersAsync = ref.watch(companyUsersProvider(profile.companyId));

          return usersAsync.when(
            data: (users) {
              final filtered = _filterUsers(users);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PremiumSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsNavTile(
                          icon: Icons.business_outlined,
                          title: 'Entreprise',
                          subtitle: 'Raison sociale, identifiants légaux, logo, RIB',
                          onTap: () => context.push('/settings/company'),
                        ),
                        const Divider(height: 1),
                        _SettingsNavTile(
                          icon: Icons.people_outline,
                          title: 'Clients',
                          subtitle: 'Référentiel client réutilisable',
                          onTap: () => context.push('/settings/clients'),
                        ),
                        const Divider(height: 1),
                        _SettingsNavTile(
                          icon: Icons.local_shipping_outlined,
                          title: 'Fournisseurs',
                          subtitle: 'Référentiel fournisseur réutilisable',
                          onTap: () => context.push('/settings/suppliers'),
                        ),
                        const Divider(height: 1),
                        _SettingsNavTile(
                          icon: Icons.percent_outlined,
                          title: 'Taxes & TVA',
                          subtitle: 'Taux applicables aux devis',
                          onTap: () => context.push('/settings/taxes'),
                        ),
                        const Divider(height: 1),
                        _SettingsNavTile(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Préférences d\'alertes',
                          onTap: () => context.push('/settings/notifications'),
                        ),
                        const Divider(height: 1),
                        _SettingsNavTile(
                          icon: Icons.palette_outlined,
                          title: 'Apparence',
                          subtitle: 'Thème et couleur d\'accent',
                          onTap: () => context.push('/settings/appearance'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionHeader(
                          title: 'Gestion des privilèges',
                          subtitle:
                              'Mets à jour les rôles de ton équipe depuis cet écran.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _roles
                              .map(
                                (role) => Chip(
                                  label: Text(role),
                                  avatar: const Icon(Icons.shield_outlined,
                                      size: 16),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumSurfaceCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Recherche',
                            hintText: 'Nom, email, rôle',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _roleFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filtre rôle',
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('Tous')),
                            DropdownMenuItem(
                                value: 'owner', child: Text('owner')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('admin')),
                            DropdownMenuItem(
                                value: 'manager', child: Text('manager')),
                            DropdownMenuItem(
                                value: 'member', child: Text('member')),
                            DropdownMenuItem(
                                value: 'viewer', child: Text('viewer')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _roleFilter = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const PremiumSurfaceCard(
                      child: Center(
                        child: Text('Aucun utilisateur pour ce filtre.'),
                      ),
                    )
                  else
                    ...filtered.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumSurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(user.email.isEmpty
                                  ? 'Email non disponible'
                                  : user.email),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PremiumStatusBadge(
                                    label: 'Rôle actuel : ${user.role}',
                                    backgroundColor:
                                        context.palette.petrolSoft,
                                    foregroundColor: context.palette.petrol,
                                    icon: Icons.verified_user_outlined,
                                  ),
                                  SizedBox(
                                    width: 220,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _roles.contains(user.role)
                                          ? user.role
                                          : 'member',
                                      decoration: const InputDecoration(
                                        labelText: 'Nouveau rôle',
                                      ),
                                      items: _roles
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(role),
                                            ),
                                          )
                                          .toList(),
                                      onChanged:
                                          _updatingIds.contains(user.id)
                                              ? null
                                              : (value) {
                                                  if (value != null &&
                                                      value != user.role) {
                                                    _updateRole(user, value);
                                                  }
                                                },
                                    ),
                                  ),
                                  if (_updatingIds.contains(user.id))
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Erreur utilisateurs : $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur profil : $error')),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
