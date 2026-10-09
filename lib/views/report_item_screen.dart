import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/item_viewmodel.dart';
import '../models/campus_locations.dart';

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

  static const Color uniandesYellow = Color(0xFFFFF200);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ItemViewModel>().loadPrioritizedLocations();
    });
  }

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
              backgroundColor: Colors.black,
              content: Text(
                'Objeto reportado con éxito con ubicación del campus',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
          _formKey.currentState!.reset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red[700],
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa una descripción'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa una categoría'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Ubicación en el Campus',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              viewModel.isLoadingLocation
                  ? const LinearProgressIndicator(
                      color: Colors.black,
                      backgroundColor: uniandesYellow,
                    )
                  : DropdownButtonFormField<CampusLocation>(
                      initialValue: viewModel.selectedLocation,
                      // Long building names are cut with "..." instead of
                      // overflowing the form on small screens.
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: Colors.black,
                        ),
                      ),
                      items: viewModel.locations.map((loc) {
                        final bool isClosest = loc == viewModel.locations.first;
                        return DropdownMenuItem<CampusLocation>(
                          value: loc,
                          child: Text(
                            isClosest
                                ? '${loc.name} (Sugerido - Más cercano)'
                                : loc.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isClosest
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isClosest ? Colors.black : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (CampusLocation? newLocation) {
                        viewModel.selectLocation(newLocation);
                      },
                    ),

              const SizedBox(height: 24),

              viewModel.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: uniandesYellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: () => _submitForm(viewModel),
                        child: const Text(
                          'Guardar Reporte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
