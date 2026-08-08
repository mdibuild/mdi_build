import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/enums/user_role.dart';
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
    'directeur',
    'chef_projet',
    'acheteur',
  ];

  String _roleLabel(String dbValue) => UserRole.fromDb(dbValue).label;

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

  Future<void> _openCreateUserDialog(String companyId) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );

    if (created == true) {
      ref.invalidate(companyUsersProvider(companyId));
    }
  }

  Future<void> _openResetPasswordDialog(SettingsUserEntry user) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(user: user),
    );

    if (reset == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mot de passe réinitialisé : ${user.displayName}'),
        ),
      );
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: PremiumSectionHeader(
                                title: 'Gestion des privilèges',
                                subtitle:
                                    'Mets à jour les rôles de ton équipe depuis cet écran.',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _openCreateUserDialog(profile.companyId),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Créer un utilisateur'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _roles
                              .map(
                                (role) => Chip(
                                  label: Text(_roleLabel(role)),
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
                          items: [
                            const DropdownMenuItem(
                                value: 'all', child: Text('Tous')),
                            for (final role in _roles)
                              DropdownMenuItem(
                                value: role,
                                child: Text(_roleLabel(role)),
                              ),
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
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PremiumStatusBadge(
                                    label:
                                        'Rôle actuel : ${_roleLabel(user.role)}',
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
                                          : UserRole.chefProjet.dbValue,
                                      decoration: const InputDecoration(
                                        labelText: 'Nouveau rôle',
                                      ),
                                      items: _roles
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(_roleLabel(role)),
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
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openResetPasswordDialog(user),
                                    icon: const Icon(Icons.lock_reset, size: 18),
                                    label: const Text('Réinitialiser le mot de passe'),
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

String _generatePassword() {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
  final random = Random.secure();
  return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController(text: _generatePassword());

  UserRole _role = UserRole.chefProjet;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(settingsRepositoryProvider).createUser(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            role: _role.dbValue,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création utilisateur : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un utilisateur'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                ),
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Minimum 3 caractères'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  helperText: 'Généré automatiquement, modifiable.',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Regénérer',
                        onPressed: () => setState(
                          () => _passwordController.text = _generatePassword(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ],
                  ),
                ),
                validator: (value) => (value == null || value.length < 8)
                    ? 'Minimum 8 caractères'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: UserRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.user});

  final SettingsUserEntry user;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  late final _passwordController =
      TextEditingController(text: _generatePassword());
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 8 caractères.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(settingsRepositoryProvider).resetUserPassword(
            userId: widget.user.id,
            newPassword: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réinitialisation : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Réinitialiser le mot de passe : ${widget.user.displayName}'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            helperText: 'Communique-le à l\'utilisateur en dehors de l\'app.',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regénérer',
                  onPressed: () => setState(
                    () => _passwordController.text = _generatePassword(),
                  ),
                ),
                IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Réinitialiser'),
        ),
      ],
    );
  }
}
