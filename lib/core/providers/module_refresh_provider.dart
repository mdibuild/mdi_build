import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refreshes fetched data while retaining each screen's filters and drafts.
final moduleRefreshRevisionProvider =
    NotifierProvider<ModuleRefreshRevisionNotifier, int>(
  ModuleRefreshRevisionNotifier.new,
);

class ModuleRefreshRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}
