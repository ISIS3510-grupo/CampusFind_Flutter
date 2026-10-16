import 'package:image_picker/image_picker.dart';

// Gets a photo of the lost item and returns its local path, or null if the
// student cancels. Abstract so widget tests do not need a real camera.
abstract class PhotoPicker {
  // Camera (the phone sensor): a similar item, its box or the receipt.
  Future<String?> takePhoto();

  // A photo the student already had of the item, the usual case when
  // something is lost.
  Future<String?> pickFromGallery();
}

class CameraPhotoPicker implements PhotoPicker {
  const CameraPhotoPicker();

  @override
  Future<String?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    // Resized and compressed so the upload stays far below the 5 MB limit.
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    return photo?.path;
  }
}
