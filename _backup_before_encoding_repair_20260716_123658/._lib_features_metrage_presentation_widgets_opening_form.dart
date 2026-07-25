import 'package:flutter/material.dart';

import '../../../../core/models/opening_item.dart';

class OpeningFormValue {
  const OpeningFormValue({
    required this.name,
    required this.openingType,
    required this.width,
    required this.height,
    required this.quantity,
  });

  final String name;
  final String openingType;
  final double width;
  final double height;
  final double quantity;
}

class OpeningForm extends StatefulWidget {
  const OpeningForm({
    super.key,
    this.initialValue,
    required this.onSubmit,
  });

  final OpeningItem? initialValue;
  final Future<void> Function(OpeningFormValue value) onSubmit;

  @override
  State<OpeningForm> createState() => _OpeningFormState();
}

class _OpeningFormState extends State<OpeningForm> {
  late final TextEditingController nameController;
  late final TextEditingController typeController;
  late final TextEditingController widthController;
  late final TextEditingController heightController;
  late final TextEditingController quantityController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final opening = widget.initialValue;
    nameController = TextEditingController(text: opening?.name ?? '');
    typeController =
        TextEditingController(text: opening?.openingType ?? 'fenetre');
    widthController = TextEditingController(
        text: opening == null ? '' : opening.width.toString());
    heightController = TextEditingController(
        text: opening == null ? '' : opening.height.toString());
    quantityController = TextEditingController(
        text: opening == null ? '1' : opening.quantity.toString());
  }

  Future<void> submit() async {
    setState(() => saving = true);
    await widget.onSubmit(
      OpeningFormValue(
        name: nameController.text.trim(),
        openingType: typeController.text.trim(),
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
        TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom')),
        const SizedBox(height: 12),
        TextField(
            controller: typeController,
            decoration: const InputDecoration(labelText: 'Type ouverture')),
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
