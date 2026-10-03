import '../../../core/models/found_item.dart';

class MatchResult {
  const MatchResult({required this.foundItem, required this.score});

  final FoundItem foundItem;
  final double score;
}
