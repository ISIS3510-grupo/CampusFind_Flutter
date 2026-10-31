import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/item_viewmodel.dart';
import '../models/campus_locations.dart';

class ReportItemScreen extends StatefulWidget { //Stateful widget is used for forms since it is necessay a dynamic interactions
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

  static const Color _yellow = Color(0xFFFEFD05);
  static const Color _border = Color(0xFFE2DEDE);
  static const Color _grey = Color(0xFF999798);

  @override
  void initState() {
    super.initState(); //se ejecuta una sola vez al crear el widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemViewModel>().loadPrioritizedLocations(); //se utiliza .read porque no se suscribe a escuchar cambios. 
    });//comienza el flujo. Es una función que se llama una vez empieza el flujo. 
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submitForm(ItemViewModel viewModel) {
    if (!_formKey.currentState!.validate()) return;

    viewModel.reportItem(
      reportType: widget.reportType,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryController.text.trim(),
      onDone: (bool success) {
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.black,
              content: Text(
                'Item reported successfully with campus location',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
          _formKey.currentState!.reset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.black,
              content: Text(
                viewModel.errorMessage ?? 'Error saving report',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      },
    );
  }

  InputDecoration _decoration(String label, {String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      hintStyle: const TextStyle(color: _grey, fontWeight: FontWeight.w300),
      labelStyle: const TextStyle(color: Colors.black87),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // once he receives updates from notifyListeners he rebuilds the view. He is an Observer 
    final viewModel = context.watch<ItemViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _yellow,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.reportType == 'found'
              ? 'Report Found Item'
              : 'Report Lost Item',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: _decoration('Title', hint: 'Name of the item'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _decoration(
                  'Description',
                  hint: 'Color, brand, visible details...',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoryController,
                decoration: _decoration('Category', hint: 'Electronics, clothing, etc.'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a category'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Campus Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              viewModel.isLoadingLocation
                  ? const LinearProgressIndicator(
                      color: Colors.black,
                      backgroundColor: _yellow,
                    )
                  : DropdownButtonFormField<CampusLocation>( // muestra la sugerencia
                      // Nombres largos se cortan con "..." en vez de desbordar.
                      isExpanded: true,
                      initialValue: viewModel.selectedLocation,
                      decoration: _decoration(
                        'Location',
                        prefixIcon: const Icon(
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
                                ? '${loc.name} (Suggested - Closest)'
                                : loc.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isClosest
                                  ? FontWeight.w500
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
              const SizedBox(height: 28),
              viewModel.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _yellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _submitForm(viewModel),
                        child: const Text(
                          'Save Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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


