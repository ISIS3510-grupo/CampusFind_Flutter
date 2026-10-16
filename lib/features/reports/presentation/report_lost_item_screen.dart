import 'dart:io';

import 'package:flutter/material.dart';

import 'package:campusfind_flutter/features/analytics/data/firestore_feature_usage_tracker.dart';
import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_tracker.dart';
import 'package:campusfind_flutter/features/reports/data/lost_report_repository_impl.dart';
import 'package:campusfind_flutter/features/reports/data/photo_labeler.dart';
import 'package:campusfind_flutter/features/reports/data/photo_picker.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';
import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_controller.dart';

class ReportLostItemScreen extends StatefulWidget {
  const ReportLostItemScreen({
    super.key,
    this.repository,
    this.featureUsageTracker = const FirestoreFeatureUsageTracker(),
    this.photoPicker = const CameraPhotoPicker(),
    this.photoLabeler = const VisionPhotoLabeler(),
  });

  // Injected in tests; the app uses the Firestore implementation.
  final LostReportRepository? repository;
  final FeatureUsageTracker featureUsageTracker;
  final PhotoPicker photoPicker;
  final PhotoLabeler photoLabeler;

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
      photoLabeler: widget.photoLabeler,
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

  Future<void> _takePhoto() =>
      _addPhoto(widget.photoPicker.takePhoto, 'Unable to open the camera.');

  Future<void> _pickFromGallery() => _addPhoto(
    widget.photoPicker.pickFromGallery,
    'Unable to open the gallery.',
  );

  Future<void> _addPhoto(
    Future<String?> Function() pick,
    String errorMessage,
  ) async {
    try {
      final path = await pick();
      if (path != null && mounted) {
        setState(() => _photoPath = path);
        _controller.analyzePhoto(path);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _removePhoto() {
    setState(() => _photoPath = null);
    _controller.clearPhotoSuggestion();
  }

  void _applySuggestion(PhotoSuggestion suggestion) {
    setState(() {
      final category = suggestion.category;
      if (category != null && _controller.categories.contains(category)) {
        _category = category;
      }
      final description = suggestion.description;
      if (description != null && _description.text.trim().isEmpty) {
        _description.text = description;
      }
    });
    _controller.clearPhotoSuggestion();
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _controller.submitting ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: _border),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPhotoSuggestion() {
    if (_controller.analyzingPhoto) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Analyzing the photo...', style: TextStyle(color: _grey)),
          ],
        ),
      );
    }
    final suggestion = _controller.photoSuggestion;
    if (suggestion == null) return const SizedBox.shrink();
    final category = suggestion.category;
    final summary = [
      if (category != null && _controller.categories.contains(category))
        _label(category),
      if (suggestion.description != null) suggestion.description!,
    ].join(' · ');
    if (summary.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE6),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16),
              SizedBox(width: 6),
              Text(
                'Suggested by Google Cloud Vision',
                style: TextStyle(fontSize: 12, color: _grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _controller.clearPhotoSuggestion,
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: () => _applySuggestion(suggestion),
                child: const Text('Use suggestion'),
              ),
            ],
          ),
        ],
      ),
    );
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
        content: Text(switch (result) {
          SubmitResult(status: SubmitStatus.queuedOffline) => 'No connection. Your report is saved and will be sent automatically.',
          SubmitResult(photoFailed: true) => 'Report sent. The photo will be uploaded when the connection improves.',
          _ => 'Report sent. We will let you know if we find it.',
        }),
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
                    // initialValue is only read once; the key rebuilds the
                    // field when the photo suggestion picks the category.
                    key: ValueKey('category-$_category'),
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
                    'Photo (optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A photo you already have helps staff recognize it.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: _grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_photoPath == null) ...[
                    _photoButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Choose from gallery',
                      onPressed: _pickFromGallery,
                    ),
                    const SizedBox(height: 10),
                    _photoButton(
                      icon: Icons.photo_camera_outlined,
                      label:
                          'Take a photo of a similar item, its box or receipt',
                      onPressed: _takePhoto,
                    ),
                  ] else
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
                              : _removePhoto,
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  _buildPhotoSuggestion(),
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
