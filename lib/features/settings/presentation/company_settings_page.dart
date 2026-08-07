import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/company.dart';
import '../../../shared/presentation/premium_ui.dart';
import 'providers/company_providers.dart';

class CompanySettingsPage extends ConsumerWidget {
  const CompanySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(currentCompanyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Entreprise')),
      body: companyAsync.when(
        data: (company) {
          if (company == null) {
            return const Center(
              child: Text('Entreprise introuvable.'),
            );
          }

          return _CompanyForm(company: company);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
      ),
    );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({required this.company});

  final Company company;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;
  late final TextEditingController iceController;
  late final TextEditingController ifController;
  late final TextEditingController rcController;
  late final TextEditingController patenteController;
  late final TextEditingController bankNameController;
  late final TextEditingController bankRibController;

  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final company = widget.company;
    nameController = TextEditingController(text: company.name);
    phoneController = TextEditingController(text: company.phone);
    emailController = TextEditingController(text: company.email);
    addressController = TextEditingController(text: company.address);
    iceController = TextEditingController(text: company.legalIce);
    ifController = TextEditingController(text: company.legalIf);
    rcController = TextEditingController(text: company.legalRc);
    patenteController = TextEditingController(text: company.legalPatente);
    bankNameController = TextEditingController(text: company.bankName);
    bankRibController = TextEditingController(text: company.bankRib);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    iceController.dispose();
    ifController.dispose();
    rcController.dispose();
    patenteController.dispose();
    bankNameController.dispose();
    bankRibController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (picked == null) {
      return;
    }

    setState(() => _uploadingLogo = true);

    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      final repository = ref.read(companyRepositoryProvider);
      final logoPath = await repository.uploadLogo(
        companyId: widget.company.id,
        bytes: bytes,
        contentType: 'image/$extension',
        fileExtension: extension,
      );

      await repository.updateCompany(
        widget.company.copyWith(
          logoPath: logoPath,
          updatedAt: DateTime.now(),
        ),
      );

      ref.invalidate(currentCompanyProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo mis à jour.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur logo : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingLogo = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(companyRepositoryProvider);

      await repository.updateCompany(
        widget.company.copyWith(
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
          address: addressController.text.trim(),
          legalIce: iceController.text.trim(),
          legalIf: ifController.text.trim(),
          legalRc: rcController.text.trim(),
          legalPatente: patenteController.text.trim(),
          bankName: bankNameController.text.trim(),
          bankRib: bankRibController.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );

      ref.invalidate(currentCompanyProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entreprise mise à jour.')),
      );
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
    final logoPath = widget.company.logoPath;
    final logoUrl = (logoPath == null || logoPath.isEmpty)
        ? null
        : ref.read(companyRepositoryProvider).publicLogoUrl(logoPath);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumSurfaceCard(
          child: Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      logoUrl == null ? null : NetworkImage(logoUrl),
                  child: logoUrl == null
                      ? const Icon(Icons.business_outlined, size: 40)
                      : null,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _uploadingLogo ? null : _pickLogo,
                  icon: _uploadingLogo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(_uploadingLogo ? 'Envoi...' : 'Changer le logo'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(title: 'Informations générales'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Raison sociale'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(title: 'Identifiants légaux'),
              const SizedBox(height: 16),
              TextField(
                controller: iceController,
                decoration: const InputDecoration(labelText: 'ICE'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ifController,
                decoration: const InputDecoration(labelText: 'IF'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rcController,
                decoration: const InputDecoration(labelText: 'RC'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patenteController,
                decoration: const InputDecoration(labelText: 'Patente'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(title: 'Coordonnées bancaires'),
              const SizedBox(height: 16),
              TextField(
                controller: bankNameController,
                decoration: const InputDecoration(labelText: 'Banque'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankRibController,
                decoration: const InputDecoration(labelText: 'RIB'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}
