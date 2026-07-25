import 'package:flutter/material.dart';

import '../../../../core/enums/space_type.dart';
import '../../../../core/models/space_item.dart';

class SpaceFormValue {
  const SpaceFormValue({
    required this.name,
    required this.levelName,
    required this.type,
    required this.length,
    required this.width,
    required this.height,
    required this.quantity,
  });

  final String name;
  final String levelName;
  final SpaceType type;
  final double length;
  final double width;
  final double height;
  final double quantity;
}

class SpaceForm extends StatefulWidget {
  const SpaceForm({
    super.key,
    this.initialValue,
    required this.onSubmit,
  });

  final SpaceItem? initialValue;
  final Future<void> Function(SpaceFormValue value) onSubmit;

  @override
  State<SpaceForm> createState() => _SpaceFormState();
}

class _SpaceFormState extends State<SpaceForm> {
  late final TextEditingController nameController;
  late final TextEditingController levelController;
  late final TextEditingController lengthController;
  late final TextEditingController widthController;
  late final TextEditingController heightController;
  late final TextEditingController quantityController;

  late SpaceType selectedType;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final space = widget.initialValue;
    nameController = TextEditingController(text: space?.name ?? '');
    levelController = TextEditingController(text: space?.levelName ?? 'RDC');
    lengthController = TextEditingController(
        text: space == null ? '' : space.length.toString());
    widthController = TextEditingController(
        text: space == null ? '' : space.width.toString());
    heightController = TextEditingController(
        text: space == null ? '2.8' : space.height.toString());
    quantityController = TextEditingController(
        text: space == null ? '1' : space.quantity.toString());
    selectedType = space?.type ?? SpaceType.piece;
  }

  Future<void> submit() async {
    setState(() => saving = true);
    await widget.onSubmit(
      SpaceFormValue(
        name: nameController.text.trim(),
        levelName: levelController.text.trim(),
        type: selectedType,
        length: double.tryParse(lengthController.text.trim()) ?? 0,
        width: double.tryParse(widthController.text.trim()) ?? 0,
        height: double.tryParse(heightController.text.trim()) ?? 0,
        quantity: double.tryParse(quantityController.text.trim()) ?? 1,
      ),
    );
    if (mounted) {
      setState(() => saving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        DropdownButtonFormField<SpaceType>(
          value: selectedType,
          items: SpaceType.values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item.label)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => selectedType = value);
            }
          },
          decoration: const InputDecoration(labelText: 'Type'),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom')),
        const SizedBox(height: 12),
        TextField(
            controller: levelController,
            decoration: const InputDecoration(labelText: 'Niveau')),
        const SizedBox(height: 12),
        TextField(
            controller: lengthController,
            decoration: const InputDecoration(labelText: 'Longueur')),
        const SizedBox(height: 12),
        TextField(
            controller: widthController,
            decoration: const InputDecoration(labelText: 'Largeur')),
        const SizedBox(height: 12),
        TextField(
            controller: heightController,
            decoration: const InputDecoration(labelText: 'Hauteur')),
        const SizedBox(height: 12),
        TextField(
            controller: quantityController,
            decoration: const InputDecoration(labelText: 'QuantitÃƒÆ’Ã‚Â©')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: saving ? null : submit,
          child: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}
