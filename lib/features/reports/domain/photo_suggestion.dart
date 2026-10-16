// What Google Cloud Vision suggests for the photo of a lost item.
class PhotoSuggestion {
  const PhotoSuggestion({
    this.category,
    this.description,
    this.keywords = const [],
  });

  factory PhotoSuggestion.fromMap(Map<Object?, Object?> data) {
    final keywords = data['keywords'];
    return PhotoSuggestion(
      category: data['suggestedCategory'] as String?,
      description: data['suggestedDescription'] as String?,
      keywords: keywords is List ? keywords.whereType<String>().toList() : [],
    );
  }

  // One of the category ids of appConfig/general, or null if unsure.
  final String? category;
  final String? description;
  final List<String> keywords;

  bool get isEmpty => category == null && description == null;
}
