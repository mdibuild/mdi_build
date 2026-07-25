# Setup

1. Crée le projet Flutter.
2. Remplace le contenu par ce starter.
3. Copie `dart_define.example.json` vers `dart_define.json`.
4. Mets les clés Supabase dans `dart_define.json`.
5. Exécute `supabase/schema.sql`.
6. Ajoute `google-services.json` dans `android/app/`.
7. Lance `flutter pub get`.
8. Lance l’app avec `flutter run --dart-define-from-file=dart_define.json`.

Les clés Supabase sont injectées à la compilation (`String.fromEnvironment`)
et ne sont plus embarquées comme asset dans le binaire compilé.
`dart_define.json` est ignoré par git (voir `.gitignore`) : ne jamais
committer ce fichier une fois rempli avec de vraies clés.
