import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/project_task.dart';

class PlanningNotificationsService {
  PlanningNotificationsService._();

  static final PlanningNotificationsService instance =
      PlanningNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> notifyForTasks({
    required String projectName,
    required List<ProjectTask> tasks,
  }) async {
    await ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dayKey(today);

    final datedTasks = tasks
        .where((task) =>
            task.plannedStartDate != null && task.plannedEndDate != null)
        .toList();

    for (final task in datedTasks) {
      final plannedStart = _dateOnly(task.plannedStartDate!);
      final plannedEnd = _dateOnly(task.plannedEndDate!);
      final nowDate = _dateOnly(today);

      final dueToday = _sameDay(plannedEnd, nowDate);
      final startToday = _sameDay(plannedStart, nowDate);
      final overdue = plannedEnd.isBefore(nowDate) &&
          task.status != 'terminee' &&
          task.status != 'archivee';
      final dueSoon = plannedEnd.isAfter(nowDate) &&
          plannedEnd.difference(nowDate).inDays <= 3 &&
          task.status != 'terminee' &&
          task.status != 'archivee';

      String? title;
      String? body;
      String type = 'planning';

      if (overdue) {
        title = 'Tâche en retard';
        body =
            '$projectName • ${task.title} devait finir le ${_frDate(plannedEnd)}';
        type = 'overdue';
      } else if (dueToday) {
        title = 'Échéance aujourd’hui';
        body = '$projectName • ${task.title} finit aujourd’hui';
        type = 'due_today';
      } else if (startToday) {
        title = 'Démarrage aujourd’hui';
        body = '$projectName • ${task.title} commence aujourd’hui';
        type = 'start_today';
      } else if (dueSoon) {
        title = 'Échéance proche';
        body =
            '$projectName • ${task.title} finit le ${_frDate(plannedEnd)}';
        type = 'due_soon';
      }

      if (title == null || body == null) {
        continue;
      }

      final dedupeKey = 'planning_notif_${todayKey}_${task.id}_$type';
      final alreadySent = prefs.getBool(dedupeKey) ?? false;

      if (alreadySent) {
        continue;
      }

      await _plugin.show(
        id: _notificationId(task.id, type),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'planning_deadlines',
            'Planning deadlines',
            channelDescription:
                'Notifications de rappel des échéances du planning',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

      await prefs.setBool(dedupeKey, true);
    }
  }

  int _notificationId(String taskId, String type) {
    return Object.hash(taskId, type) & 0x7fffffff;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayKey(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _frDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}
