import 'package:flutter/material.dart';

import 'project_workspace_toolbar.dart';

/// Marks a module displayed as a tab of another module (e.g. Métré inside
/// « Métré & Quantitatif »): the host already provides the title, the tabs
/// and the project toolbar.
class EmbeddedModuleScope extends InheritedWidget {
  const EmbeddedModuleScope({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmbeddedModuleScope>() != null;

  @override
  bool updateShouldNotify(EmbeddedModuleScope oldWidget) => false;
}

/// Keeps project selection inside every module, below its title and tabs.
/// It remains available while the module is loading or displaying an error.
class ProjectModuleScaffold extends StatelessWidget {
  const ProjectModuleScaffold({
    super.key,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (EmbeddedModuleScope.contains(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        body: body ?? const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: ProjectWorkspaceScope(
        child: LayoutBuilder(builder: (context, constraints) {
          return Column(children: [
            ProjectWorkspaceToolbar(dense: constraints.maxHeight < 220),
            const Divider(height: 1),
            Expanded(child: body ?? const SizedBox.shrink()),
          ]);
        }),
      ),
    );
  }
}
