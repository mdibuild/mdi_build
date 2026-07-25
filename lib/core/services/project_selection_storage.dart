import 'package:shared_preferences/shared_preferences.dart';

class ProjectSelectionStorage {
  static const _key = 'mdi_build_selected_project_id';

  Future<String?> readSelectedProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> writeSelectedProjectId(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, projectId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
