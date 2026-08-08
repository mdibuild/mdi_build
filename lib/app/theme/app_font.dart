class AppFontOption {
  const AppFontOption({required this.id, required this.label, required this.googleFontFamily});

  final String id;
  final String label;
  final String googleFontFamily;
}

const appFontOptions = <AppFontOption>[
  AppFontOption(id: 'inter', label: 'Inter', googleFontFamily: 'Inter'),
  AppFontOption(id: 'manrope', label: 'Manrope', googleFontFamily: 'Manrope'),
  AppFontOption(id: 'sora', label: 'Sora', googleFontFamily: 'Sora'),
  AppFontOption(id: 'work_sans', label: 'Work Sans', googleFontFamily: 'Work Sans'),
  AppFontOption(
    id: 'plus_jakarta_sans',
    label: 'Plus Jakarta Sans',
    googleFontFamily: 'Plus Jakarta Sans',
  ),
];

const defaultAppFontId = 'inter';

AppFontOption resolveFontOption(String id) {
  return appFontOptions.firstWhere(
    (option) => option.id == id,
    orElse: () => appFontOptions.first,
  );
}
