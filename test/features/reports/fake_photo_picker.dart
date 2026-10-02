import 'package:campusfind_flutter/features/reports/data/photo_picker.dart';

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.path = '/photos/calculator.jpg'});

  // Null simulates the student closing the camera without a photo.
  final String? path;
  int calls = 0;

  @override
  Future<String?> takePhoto() async {
    calls++;
    return path;
  }
}
