import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/item_viewmodel.dart';
import '../models/campus_locations.dart'; // <-- Importa el modelo de ubicación

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
  void initState() {
    super.initState();
    // Carga la ubicación del GPS y ordena los edificios por cercanía al abrir la pantalla
    // Usamos addPostFrameCallback para asegurarnos de que el contexto esté listo para llamar al ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemViewModel>().loadPrioritizedLocations();
    });
  }

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
            const SnackBar(
              content: Text(
                'Objeto reportado con éxito con ubicación del campus',
              ),
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
    // Escuchamos el ViewModel para reaccionar a cambios de estado
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
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa un título' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (val) => val == null || val.isEmpty
                    ? 'Ingresa una descripción'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa una categoría' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Uniandes'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa tu correo' : null,
              ),
              const SizedBox(height: 20),

              // --- SECCIÓN DE UBICACIÓN INTELIGENTE (GPS + Campus) ---
              const Text(
                'Ubicación en el Campus',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              viewModel.isLoadingLocation
                  ? const LinearProgressIndicator() // Muestra barra de carga mientras el GPS calcula el más cercano
                  : DropdownButtonFormField<CampusLocation>(
                      value: viewModel.selectedLocation,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: viewModel.locations.map((loc) {
                        final bool isClosest = loc == viewModel.locations.first;
                        return DropdownMenuItem<CampusLocation>(
                          value: loc,
                          child: Text(
                            isClosest
                                ? '${loc.name} (Sugerido - Más cercano)'
                                : loc.name,
                            style: TextStyle(
                              fontWeight: isClosest
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isClosest
                                  ? Colors.blue[800]
                                  : Colors.black87,
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
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _submitForm(viewModel),
                      child: const Text('Guardar Reporte'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
