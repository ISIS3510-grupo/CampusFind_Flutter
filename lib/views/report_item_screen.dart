import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/item_viewmodel.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForm(ItemViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      bool success = await viewModel.reportItem(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        userEmail: _emailController.text,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Objeto reportado con éxito con ubicación GPS')),
          );
          _formKey.currentState!.reset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(viewModel.errorMessage ?? 'Error al guardar')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ItemViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar Objeto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa un título' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa una descripción' : null,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa una categoría' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Uniandes'),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa tu correo' : null,
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