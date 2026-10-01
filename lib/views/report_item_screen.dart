import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/item_viewmodel.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key, required this.reportType})
    : assert(reportType == 'found' || reportType == 'lost');

  final String reportType;

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submitForm(ItemViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      bool success = await viewModel.reportItem(
        reportType: widget.reportType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Objeto reportado con éxito con ubicación GPS'),
            ),
          );
          _formKey.currentState!.reset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.errorMessage ?? 'Error al guardar'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ItemViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reportType == 'found'
              ? 'Report Found Item'
              : 'Report Lost Item',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa un título'
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa una descripción'
                    : null,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa una categoría'
                    : null,
              ),
              const SizedBox(height: 20),
              viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _submitForm(viewModel),
                      child: const Text('Guardar y Obtener Ubicación'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
