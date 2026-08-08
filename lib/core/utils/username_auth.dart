/// Supabase Auth n'a pas de notion de "nom d'utilisateur" — seulement email
/// ou téléphone. Pour permettre une connexion par simple nom d'utilisateur,
/// on dérive un email interne, jamais montré à l'utilisateur ni utilisé pour
/// envoyer quoi que ce soit (aucune adresse réelle derrière). Doit rester
/// identique à la normalisation faite côté fonction serveur (admin-users).
String usernameToPseudoEmail(String username) {
  final sanitized = username
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '.')
      .replaceAll(RegExp(r'[^a-z0-9._-]'), '');

  return '$sanitized@mdibuild.local';
}
