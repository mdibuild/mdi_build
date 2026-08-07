import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_palette_colors.dart';
import '../../../shared/presentation/premium_ui.dart';
import 'providers/palette_providers.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(paletteSelectionProvider);
    final notifier = ref.read(paletteSelectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PremiumSectionHeader(
            title: 'Thème',
            subtitle: 'Choisis une ambiance et un accent, appliqué immédiatement.',
          ),
          const SizedBox(height: 16),
          for (final palette in appPalettes.values) ...[
            _PaletteCard(
              palette: palette,
              selection: selection,
              onSelectPalette: () => notifier.selectPalette(palette.id),
              onSelectAccent: (index) {
                if (selection.paletteId != palette.id) {
                  notifier.selectPalette(palette.id);
                }
                notifier.selectAccent(index);
              },
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.selection,
    required this.onSelectPalette,
    required this.onSelectAccent,
  });

  final AppPalette palette;
  final PaletteSelection selection;
  final VoidCallback onSelectPalette;
  final ValueChanged<int> onSelectAccent;

  bool get _isSelected => selection.paletteId == palette.id;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return PremiumSurfaceCard(
      onTap: _isSelected ? null : onSelectPalette,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      palette.tagline,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_isSelected)
                PremiumStatusBadge(
                  label: 'Actif',
                  backgroundColor: colors.petrolSoft,
                  foregroundColor: colors.petrol,
                  icon: Icons.check,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < palette.accentOptions.length; i++)
                _AccentSwatch(
                  option: palette.accentOptions[i],
                  selected: _isSelected && selection.accentIndex == i,
                  onTap: () => onSelectAccent(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppAccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? option.color : Colors.transparent,
              width: 2.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: option.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),
      ),
    );
  }
}
