import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

// Uploads the photo of a lost report to Storage (lostReports/{reportId}.jpg).
// The Storage rules only accept it after the report exists in Firestore.
class ReportPhotoStorage {
  ReportPhotoStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static String pathFor(String reportId) => 'lostReports/$reportId.jpg';

  // Returns the Storage path that is saved as photoPath in the report.
  Future<String> upload(String reportId, String localPath) async {
    final path = pathFor(reportId);
    await _storage
        .ref(path)
        .putFile(File(localPath), SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }
}
