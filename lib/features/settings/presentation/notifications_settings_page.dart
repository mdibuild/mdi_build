import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../planning/services/planning_notifications_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends State<NotificationsSettingsPage> {
  bool _loading = true;
  bool _planningEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _planningEnabled = prefs.getBool(planningNotificationsPrefKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setPlanningEnabled(bool value) async {
    setState(() => _planningEnabled = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(planningNotificationsPrefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Alertes planning'),
                    subtitle: const Text(
                      'Notifie les tâches en retard, à échéance aujourd\'hui ou proche.',
                    ),
                    value: _planningEnabled,
                    onChanged: _setPlanningEnabled,
                  ),
                ),
              ],
            ),
    );
  }
}
