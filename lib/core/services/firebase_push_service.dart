import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_navigation.dart';

class FirebasePushService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Nouveaux éléments reçus par module depuis la dernière ouverture du
  /// module (affichés dans la notification et en pastille sur l'icône).
  static final Map<String, int> _counts = {};

  /// Dernières lignes reçues par module (aperçu dans la notification).
  static final Map<String, List<String>> _lines = {};

  /// Chemin de l'écran affiché, tenu à jour par l'application : pas de
  /// notification pour le module que l'utilisateur est déjà en train de voir.
  static String currentLocation = '';

  static bool _ready = false;

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      // Toucher une notification affichée pendant que l'appli était ouverte.
      onDidReceiveNotificationResponse: (response) =>
          PushNavigation.open(_decode(response.payload)),
    );
    _ready = true;

    // Notification reçue appli ouverte : on l'affiche nous-mêmes.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Toucher une notification système, appli en arrière-plan.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => PushNavigation.open(message.data),
    );

    // Appli lancée (fermée) en touchant une notification système.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      PushNavigation.open(initial.data);
    }

    // Appli lancée en touchant une notification affichée par nos soins.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      PushNavigation.open(_decode(launch!.notificationResponse?.payload));
    }
  }

  static Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return const {};
    }
  }

  /// Identifiant stable par module : la notification du module est mise à
  /// jour (compteur, dernières lignes) au lieu de s'empiler.
  static int _idFor(String module) => module.hashCode & 0x7fffffff;

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }
    final module = moduleForPushData(message.data);
    final route = routeForPushData(message.data);
    if (currentLocation.startsWith(route) && route != '/dashboard') {
      return; // l'utilisateur regarde déjà ce module
    }

    final count = (_counts[module] ?? 0) + 1;
    _counts[module] = count;
    final line = [notification.title, notification.body]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(' : ');
    final lines = (_lines[module] ?? <String>[])..add(line);
    if (lines.length > 6) {
      lines.removeAt(0);
    }
    _lines[module] = lines;

    final label = _moduleLabel(module);
    final title = count > 1
        ? '$label · $count nouveaux ${module == 'chat' ? 'messages' : 'éléments'}'
        : (notification.title ?? label);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mdi_build_channel',
        'MDI Build Notifications',
        channelDescription: 'Notifications chantier',
        importance: Importance.max,
        priority: Priority.high,
        // Compteur affiché sur l'icône de l'appli (selon le téléphone).
        number: count,
        channelShowBadge: true,
        styleInformation: InboxStyleInformation(
          lines,
          contentTitle: title,
          summaryText: count > 1 ? '$count au total' : null,
        ),
      ),
    );

    await _plugin.show(
      id: _idFor(module),
      title: title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  static String _moduleLabel(String module) {
    switch (module) {
      case 'chat':
        return 'Chat';
      case 'achats':
        return 'Achats';
      case 'planning':
        return 'Planning';
      default:
        return 'MDI Build';
    }
  }

  /// À appeler quand l'utilisateur ouvre un module : remet son compteur à
  /// zéro et retire sa notification.
  static Future<void> clearModule(String module) async {
    _counts.remove(module);
    _lines.remove(module);
    if (kIsWeb || !_ready) {
      return;
    }
    try {
      await _plugin.cancel(id: _idFor(module));
    } catch (_) {
      // Jamais bloquant.
    }
  }
}
