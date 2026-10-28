import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/models/checklist_item.dart';
import '../../../core/providers/module_refresh_provider.dart';
import '../../../core/services/firebase_push_service.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../data/checklist_repository.dart';

/// Rappels qui concernent l'utilisateur : tâches qui lui sont destinées ou
/// qu'il a émises (le rappel concerne les deux) ; non faites, avec un
/// rappel à venir.
List<ChecklistItem> remindersFor(
  List<ChecklistItem> items,
  String userId, {
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  return [
    for (final item in items)
      if (!item.isDone &&
          item.reminderAt != null &&
          item.reminderAt!.isAfter(moment) &&
          (item.assignedTo == userId || item.createdBy == userId))
        item,
  ];
}

/// Identifiant stable de la notification d'un élément (hors de la plage
/// utilisée par les notifications de modules).
int reminderNotificationId(String itemId) =>
    0x40000000 | (itemId.hashCode & 0x3fffffff);

/// Programme les notifications locales du téléphone (Android / iPhone) et
/// annule celles qui ne servent plus (tâche faite, supprimée, déplacée).
class ChecklistReminders {
  ChecklistReminders._();

  static const _key = 'checklist_reminder_ids';

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> sync(List<ChecklistItem> mine) async {
    if (!_supported || !FirebasePushService.ready) {
      return;
    }
    final plugin = FirebasePushService.plugin;
    final prefs = await SharedPreferences.getInstance();
    final previous = (prefs.getStringList(_key) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final wanted = <int>{};

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (final item in mine) {
      final at = item.reminderAt;
      if (at == null) {
        continue;
      }
      final id = reminderNotificationId(item.id);
      wanted.add(id);
      final minutes = item.reminderMinutes ?? 0;
      try {
        await plugin.zonedSchedule(
          id: id,
          title: minutes == 0
              ? 'Échéance : ${item.title}'
              : 'Rappel : ${item.title}',
          body: minutes == 0
              ? 'C’est l’heure prévue pour cette tâche de la check-list.'
              : 'Échéance dans ${_delay(minutes)}.',
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          androidScheduleMode: mode,
          payload: jsonEncode({'type': 'checklist'}),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'mdi_checklist_reminders',
              'Rappels de la check-list',
              channelDescription: 'Échéances des tâches de la check-list',
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (error) {
        debugPrint('Rappel non programmé : $error');
      }
    }
    for (final id in previous.difference(wanted)) {
      try {
        await plugin.cancel(id: id);
      } catch (_) {}
    }
    await prefs.setStringList(_key, [for (final id in wanted) '$id']);
  }

  static String _delay(int minutes) {
    if (minutes % 1440 == 0) {
      final d = minutes ~/ 1440;
      return d == 1 ? '1 jour' : '$d jours';
    }
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 heure' : '$h heures';
    }
    return '$minutes minutes';
  }
}

/// Relit les tâches de l'entreprise à chaque actualisation, reprogramme les
/// rappels de l'utilisateur connecté et renvoie le nombre de tâches non
/// faites qui lui sont destinées (pastille rouge du menu Check-list).
final checklistRemindersSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return 0;
  }
  try {
    final items =
        await ChecklistRepository().fetchItems(companyId: profile.companyId);
    await ChecklistReminders.sync(remindersFor(items, profile.id));
    return items.where((i) => i.assignedTo == profile.id && !i.isDone).length;
  } catch (error) {
    debugPrint('Rappels de la check-list indisponibles : $error');
    return 0;
  }
});
