import 'package:campusfind_flutter/features/reports/data/photo_picker.dart';

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({
    this.path = '/photos/calculator.jpg',
    this.galleryPath = '/gallery/calculator.jpg',
  });

  // Null simulates the student closing the camera or the gallery.
  final String? path;
  final String? galleryPath;
  int calls = 0;
  int galleryCalls = 0;

  @override
  Future<String?> takePhoto() async {
    calls++;
    return path;
  }

  @override
  Future<String?> pickFromGallery() async {
    galleryCalls++;
    return galleryPath;
  }
}
