import 'dart:async';

import 'package:campusfind_flutter/features/reports/data/photo_labeler.dart';
import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';

class FakePhotoLabeler implements PhotoLabeler {
  FakePhotoLabeler({this.suggestion, this.pending});

  // Null simulates no connection or nothing useful in the photo.
  final PhotoSuggestion? suggestion;
  // Lets a test decide when the answer arrives.
  final Completer<PhotoSuggestion?>? pending;
  final requested = <String>[];

  @override
  Future<PhotoSuggestion?> suggest(String photoPath) async {
    requested.add(photoPath);
    return pending == null ? suggestion : pending!.future;
  }
}
