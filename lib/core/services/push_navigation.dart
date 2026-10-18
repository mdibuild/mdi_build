/// Route de l'application à ouvrir quand l'utilisateur touche une
/// notification, d'après le champ `type` envoyé par le serveur :
/// - `chat` → messagerie ;
/// - `achats` → achats ;
/// - `planning` / `task_deadline` (échéance de tâche) → planning ;
/// - autre ou absent → tableau de bord.
String routeForPushData(Map<String, dynamic> data) {
  switch ((data['type'] ?? '').toString()) {
    case 'chat':
      return '/chat';
    case 'achats':
      return '/achats';
    case 'planning':
    case 'task_deadline':
      return '/planning';
    default:
      return '/dashboard';
  }
}

/// Module (clé de regroupement des notifications) d'une notification.
String moduleForPushData(Map<String, dynamic> data) {
  switch ((data['type'] ?? '').toString()) {
    case 'chat':
      return 'chat';
    case 'achats':
      return 'achats';
    case 'planning':
    case 'task_deadline':
      return 'planning';
    default:
      return 'autre';
  }
}

typedef PushOpenHandler = Future<void> Function(Map<String, dynamic> data);

/// Relais entre les notifications (reçues avant même que l'interface soit
/// prête, par exemple au lancement de l'application depuis une notification)
/// et la navigation de l'application.
class PushNavigation {
  PushNavigation._();

  static PushOpenHandler? _handler;
  static Map<String, dynamic>? _pending;

  /// Branche la navigation ; une notification touchée avant ce moment est
  /// traitée immédiatement.
  static void attach(PushOpenHandler handler) {
    _handler = handler;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      handler(pending);
    }
  }

  /// Demande l'ouverture de l'écran correspondant à la notification.
  static void open(Map<String, dynamic> data) {
    final handler = _handler;
    if (handler == null) {
      _pending = Map<String, dynamic>.from(data);
    } else {
      handler(data);
    }
  }
}
