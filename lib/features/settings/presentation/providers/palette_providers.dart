import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_palette.dart';

const paletteSelectionPrefKey = 'pref_palette_selection_id';
const paletteAccentIndexPrefKey = 'pref_palette_accent_index';

class PaletteSelection {
  const PaletteSelection({
    required this.paletteId,
    required this.accentIndex,
  });

  final AppPaletteId paletteId;
  final int accentIndex;

  static const fallback = PaletteSelection(
    paletteId: AppPaletteId.blueprintClair,
    accentIndex: 0,
  );

  static PaletteSelection fromPrefs(SharedPreferences prefs) {
    final idName = prefs.getString(paletteSelectionPrefKey);
    final id = AppPaletteId.values.firstWhere(
      (value) => value.name == idName,
      orElse: () => fallback.paletteId,
    );

    final palette = appPalettes[id]!;
    final maxIndex = palette.accentOptions.length - 1;
    final storedIndex = prefs.getInt(paletteAccentIndexPrefKey) ?? palette.defaultAccentIndex;

    return PaletteSelection(
      paletteId: id,
      accentIndex: storedIndex.clamp(0, maxIndex),
    );
  }
}

class PaletteSelectionNotifier extends Notifier<PaletteSelection> {
  PaletteSelectionNotifier([this._initial = PaletteSelection.fallback]);

  final PaletteSelection _initial;

  @override
  PaletteSelection build() => _initial;

  Future<void> selectPalette(AppPaletteId id) async {
    state = PaletteSelection(
      paletteId: id,
      accentIndex: appPalettes[id]!.defaultAccentIndex,
    );
    await _persist();
  }

  Future<void> selectAccent(int index) async {
    state = PaletteSelection(
      paletteId: state.paletteId,
      accentIndex: index,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(paletteSelectionPrefKey, state.paletteId.name);
    await prefs.setInt(paletteAccentIndexPrefKey, state.accentIndex);
  }
}

final paletteSelectionProvider =
    NotifierProvider<PaletteSelectionNotifier, PaletteSelection>(
  PaletteSelectionNotifier.new,
);
