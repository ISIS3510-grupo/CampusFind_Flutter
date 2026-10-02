import 'package:image_picker/image_picker.dart';

// Opens the camera and returns the local path of the photo, or null if the
// student cancels. Abstract so widget tests do not need a real camera.
abstract class PhotoPicker {
  Future<String?> takePhoto();
}

class CameraPhotoPicker implements PhotoPicker {
  const CameraPhotoPicker();

  @override
  Future<String?> takePhoto() async {
    // Resized and compressed so the upload stays far below the 5 MB limit.
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 70,
    );
    return photo?.path;
  }
}
