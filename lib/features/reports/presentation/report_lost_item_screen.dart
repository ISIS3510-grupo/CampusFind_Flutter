import 'dart:io';

import 'package:flutter/material.dart';

import 'package:campusfind_flutter/features/analytics/data/firestore_feature_usage_tracker.dart';
import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_tracker.dart';
import 'package:campusfind_flutter/features/reports/data/lost_report_repository_impl.dart';
import 'package:campusfind_flutter/features/reports/data/photo_picker.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_controller.dart';

class ReportLostItemScreen extends StatefulWidget {
  const ReportLostItemScreen({
    super.key,
    this.repository,
    this.featureUsageTracker = const FirestoreFeatureUsageTracker(),
    this.photoPicker = const CameraPhotoPicker(),
  });

  // Injected in tests; the app uses the Firestore implementation.
  final LostReportRepository? repository;
  final FeatureUsageTracker featureUsageTracker;
  final PhotoPicker photoPicker;

  @override
  State<ReportLostItemScreen> createState() => _ReportLostItemScreenState();
}

class _ReportLostItemScreenState extends State<ReportLostItemScreen> {
  static const _yellow = Color(0xFFFEFD05);
  static const _border = Color(0xFFE2DEDE);
  static const _grey = Color(0xFF999798);

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _privateDetail = TextEditingController();
  String? _category;
  String? _photoPath;

  late final ReportLostItemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReportLostItemController(
      widget.repository ?? LostReportRepositoryImpl(),
    )..loadCategories();
  }

  @override
  void dispose() {
    _controller.dispose();
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _privateDetail.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final path = await widget.photoPicker.takePhoto();
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the camera.')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await _controller.submit(
      LostReportDraft(
        title: _title.text.trim(),
        category: _category!,
        description: _description.text.trim(),
        locationName: _location.text.trim(),
        privateVerificationDetail: _privateDetail.text.trim().isEmpty
            ? null
            : _privateDetail.text.trim(),
        imagePath: _photoPath,
      ),
    );
    if (!mounted || result == null) return;
    widget.featureUsageTracker.track(AppFeature.submitLostReport);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.photoFailed
              ? 'Report sent, but the photo could not be uploaded.'
              : 'Report sent. We will let you know if we find it.',
        ),
      ),
    );
    Navigator.of(context).pop(result);
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty)
      ? 'This field is required.'
      : null;

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: _grey, fontWeight: FontWeight.w300),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  String _label(String category) =>
      category[0].toUpperCase() + category.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _yellow,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'I lost an item',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  const Text(
                    'Tell us what you lost',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      'Item',
                      hint: 'Scientific calculator',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _decoration('Category'),
                    items: [
                      for (final category in _controller.categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(_label(category)),
                        ),
                    ],
                    onChanged: _controller.loadingCategories
                        ? null
                        : (value) => setState(() => _category = value),
                    validator: (value) =>
                        value == null ? 'Choose a category.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      'Description',
                      hint: 'Color, brand, stickers, anything visible',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _location,
                    decoration: _decoration(
                      'Where did you lose it?',
                      hint: 'ML building, 5th floor',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Private verification detail',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Something only the owner would know. Only Lost & Found staff can see it.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: _grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _privateDetail,
                    decoration: _decoration(
                      'Detail',
                      hint: 'Name engraved on the back (optional)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  if (_photoPath == null)
                    OutlinedButton.icon(
                      onPressed: _controller.submitting ? null : _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take a photo (optional)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: _border),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_photoPath!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 72,
                              height: 72,
                              child: Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Photo added')),
                        TextButton(
                          onPressed: _controller.submitting
                              ? null
                              : () => setState(() => _photoPath = null),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  if (_controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _controller.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _controller.submitting ? null : _submit,
                      child: _controller.submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Send report',
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
          );
        },
      ),
    );
  }
}
