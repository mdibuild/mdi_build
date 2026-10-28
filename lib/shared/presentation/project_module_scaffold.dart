import 'package:flutter/material.dart';

import 'project_workspace_toolbar.dart';
import '../../core/providers/navigation_history.dart';

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
      appBar: _withBackButton(context, appBar),
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

  /// Ajoute le bouton « Retour » aux modules ouverts depuis le menu (ils
  /// n'ont pas de pile de navigation, donc pas de retour automatique).
  static PreferredSizeWidget? _withBackButton(
      BuildContext context, PreferredSizeWidget? bar) {
    if (bar is! AppBar || bar.leading != null) {
      return bar;
    }
    if (Navigator.maybeOf(context)?.canPop() ?? false) {
      return bar; // écran poussé : retour automatique de l'AppBar
    }
    return AppBar(
      key: bar.key,
      leading: const ModuleBackButton(),
      title: bar.title,
      actions: bar.actions,
      bottom: bar.bottom,
      centerTitle: bar.centerTitle,
      backgroundColor: bar.backgroundColor,
      foregroundColor: bar.foregroundColor,
      elevation: bar.elevation,
      flexibleSpace: bar.flexibleSpace,
      toolbarHeight: bar.toolbarHeight,
      titleSpacing: bar.titleSpacing,
    );
  }
}
