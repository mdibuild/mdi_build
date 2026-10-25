import 'package:flutter/material.dart';

import 'project_workspace_toolbar.dart';

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
  Widget build(BuildContext context) => Scaffold(
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
