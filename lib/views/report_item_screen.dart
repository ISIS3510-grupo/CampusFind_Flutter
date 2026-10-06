import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/item_viewmodel.dart';
import '../models/campus_locations.dart';

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

  // Color amarillo característico de la interfaz de UniAndes
  static const Color uniandesYellow = Color(0xFFFFF200);

  @override
  void initState() {
    super.initState();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: uniandesYellow,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'uniandes',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'Reportar Objeto',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa un título' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Ingresa una descripción'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa una categoría' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Uniandes',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa tu correo' : null,
              ),
              const SizedBox(height: 20),

              // --- SECCIÓN DE UBICACIÓN INTELIGENTE (GPS + Campus) ---
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
                      isExpanded: true, // <-- CORRIGE EL OVERFLOW HORIZONTAL
                      value: viewModel.selectedLocation,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        prefixIcon: Icon(Icons.location_on, color: Colors.black),
                      ),
                      items: viewModel.locations.map((loc) {
                        final bool isClosest =
                            loc == viewModel.locations.first;
                        return DropdownMenuItem<CampusLocation>(
                          value: loc,
                          child: Text(
                            isClosest
                                ? '${loc.name} (Sugerido - Más cercano)'
                                : loc.name,
                            overflow: TextOverflow.ellipsis, // <-- MUESTRA "..." SI ES MUY LARGO
                            maxLines: 1,
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
                            side: const BorderSide(color: Colors.black, width: 1.5),
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