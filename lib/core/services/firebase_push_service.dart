import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebasePushService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) {
        return;
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'mdi_build_channel',
          'MDI Build Notifications',
          channelDescription: 'Notifications chantier',
          importance: Importance.max,
          priority: Priority.high,
        ),
      );

      await _plugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
      );
    });
  }
}
