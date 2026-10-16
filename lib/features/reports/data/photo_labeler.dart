import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';

// Asks the backend what is in the photo. Abstract so widget tests do not call
// Firebase.
abstract class PhotoLabeler {
  // Null when there is nothing useful to suggest or the service is not
  // reachable; the form works the same without a suggestion.
  Future<PhotoSuggestion?> suggest(String photoPath);
}

// Sends the photo to the suggestPhotoLabels Cloud Function, which calls
// Google Cloud Vision.
class VisionPhotoLabeler implements PhotoLabeler {
  const VisionPhotoLabeler({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  @override
  Future<PhotoSuggestion?> suggest(String photoPath) async {
    try {
      // Reading and encoding the photo runs in another isolate, so the form
      // keeps responding while a ~300 KB file is turned into base64.
      final image = await Isolate.run(
        () => base64Encode(File(photoPath).readAsBytesSync()),
      );
      final result = await FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable(
            'suggestPhotoLabels',
            options: HttpsCallableOptions(timeout: timeout),
          )
          .call({'image': image});
      final data = result.data;
      if (data is! Map) return null;
      final suggestion = PhotoSuggestion.fromMap(data);
      return suggestion.isEmpty ? null : suggestion;
    } catch (_) {
      // Offline, timeout or Vision unavailable.
      return null;
    }
  }
}
