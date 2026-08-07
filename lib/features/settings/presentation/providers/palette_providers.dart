import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_palette.dart';

const paletteSelectionPrefKey = 'pref_palette_selection_id';
const paletteAccentIndexPrefKey = 'pref_palette_accent_index';
const paletteTitleColorIndexPrefKey = 'pref_palette_title_color_index';

class PaletteSelection {
  const PaletteSelection({
    required this.paletteId,
    required this.accentIndex,
    required this.titleColorIndex,
  });

  final AppPaletteId paletteId;
  final int accentIndex;
  final int titleColorIndex;

  static const fallback = PaletteSelection(
    paletteId: AppPaletteId.blueprintClair,
    accentIndex: 0,
    titleColorIndex: 0,
  );

  static PaletteSelection fromPrefs(SharedPreferences prefs) {
    final idName = prefs.getString(paletteSelectionPrefKey);
    final id = AppPaletteId.values.firstWhere(
      (value) => value.name == idName,
      orElse: () => fallback.paletteId,
    );

    final palette = appPalettes[id]!;
    final maxIndex = palette.accentOptions.length - 1;
    final storedAccentIndex =
        prefs.getInt(paletteAccentIndexPrefKey) ?? palette.defaultAccentIndex;
    final storedTitleIndex =
        prefs.getInt(paletteTitleColorIndexPrefKey) ?? storedAccentIndex;

    return PaletteSelection(
      paletteId: id,
      accentIndex: storedAccentIndex.clamp(0, maxIndex),
      titleColorIndex: storedTitleIndex.clamp(0, maxIndex),
    );
  }
}

class PaletteSelectionNotifier extends Notifier<PaletteSelection> {
  PaletteSelectionNotifier([this._initial = PaletteSelection.fallback]);

  final PaletteSelection _initial;

  @override
  PaletteSelection build() => _initial;

  Future<void> selectPalette(AppPaletteId id) async {
    final defaultIndex = appPalettes[id]!.defaultAccentIndex;
    state = PaletteSelection(
      paletteId: id,
      accentIndex: defaultIndex,
      titleColorIndex: defaultIndex,
    );
    await _persist();
  }

  Future<void> selectAccent(int index) async {
    state = PaletteSelection(
      paletteId: state.paletteId,
      accentIndex: index,
      titleColorIndex: state.titleColorIndex,
    );
    await _persist();
  }

  Future<void> selectTitleColor(int index) async {
    state = PaletteSelection(
      paletteId: state.paletteId,
      accentIndex: state.accentIndex,
      titleColorIndex: index,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(paletteSelectionPrefKey, state.paletteId.name);
    await prefs.setInt(paletteAccentIndexPrefKey, state.accentIndex);
    await prefs.setInt(paletteTitleColorIndexPrefKey, state.titleColorIndex);
  }
}

final paletteSelectionProvider =
    NotifierProvider<PaletteSelectionNotifier, PaletteSelection>(
  PaletteSelectionNotifier.new,
);
