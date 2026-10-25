import 'package:flutter/material.dart';

/// Consistent, wrapping filter controls for both phones and desktop screens.
class ModuleFilterBar extends StatefulWidget {
  const ModuleFilterBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.searchHint = 'Rechercher…',
    this.filters = const [],
    this.onReset,
    this.resultLabel,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;
  final List<Widget> filters;
  final VoidCallback? onReset;
  final String? resultLabel;

  @override
  State<ModuleFilterBar> createState() => _ModuleFilterBarState();
}

class _ModuleFilterBarState extends State<ModuleFilterBar> {
  late final TextEditingController _search =
      TextEditingController(text: widget.searchQuery);

  @override
  void didUpdateWidget(covariant ModuleFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.searchQuery) {
      _search.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final searchWidth =
          constraints.maxWidth < 600 ? constraints.maxWidth : 320.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: searchWidth,
                child: TextField(
                  controller: _search,
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    labelText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: widget.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            onPressed: () {
                              _search.clear();
                              widget.onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              for (final filter in widget.filters)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: filter,
                ),
              if (widget.onReset != null)
                TextButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Réinitialiser'),
                ),
            ],
          ),
          if (widget.resultLabel != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(widget.resultLabel!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      );
    });
  }
}

class ModuleFilterDropdown<T> extends StatelessWidget {
  const ModuleFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.width = 210,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final validValue = items.any((item) => item.value == value) ? value : null;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        key: ValueKey(validValue),
        initialValue: validValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
