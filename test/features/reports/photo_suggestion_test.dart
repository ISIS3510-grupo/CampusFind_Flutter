import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the answer of the suggestPhotoLabels function', () {
    final suggestion = PhotoSuggestion.fromMap({
      'suggestedCategory': 'bags',
      'suggestedDescription': 'Black backpack',
      'dominantColor': 'black',
      'detectedText': null,
      'keywords': ['backpack', 'bag', 7],
    });

    expect(suggestion.category, 'bags');
    expect(suggestion.description, 'Black backpack');
    expect(suggestion.keywords, ['backpack', 'bag']);
    expect(suggestion.isEmpty, isFalse);
  });

  test('an answer without category nor description is empty', () {
    final suggestion = PhotoSuggestion.fromMap({
      'keywords': ['floor'],
    });
    expect(suggestion.isEmpty, isTrue);
    expect(suggestion.keywords, ['floor']);
  });
}
