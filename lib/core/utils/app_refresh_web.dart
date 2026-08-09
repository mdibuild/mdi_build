// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// "Actualiser" doit vraiment récupérer la dernière version : un simple
/// reload() ne suffit pas car Flutter Web installe un service worker qui
/// sert l'app depuis son propre cache local, indépendamment du cache HTTP
/// du navigateur.
Future<void> reloadApp() async {
  try {
    final registrations =
        await html.window.navigator.serviceWorker?.getRegistrations();
    if (registrations != null) {
      for (final registration in registrations) {
        await registration.unregister();
      }
    }
  } catch (_) {
    // Pas bloquant : on tente quand même le reload ci-dessous.
  }

  try {
    final cacheStorage = html.window.caches;
    if (cacheStorage != null) {
      final keys = await cacheStorage.keys();
      for (final key in keys) {
        await cacheStorage.delete(key);
      }
    }
  } catch (_) {
    // Idem.
  }

  html.window.location.reload();
}
