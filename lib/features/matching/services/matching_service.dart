import '../../../core/models/found_item.dart';
import '../../../core/models/lost_report.dart';
import '../domain/match_result.dart';
import '../domain/matching_strategy.dart';

class MatchingService {
  const MatchingService({required this.strategy, this.threshold = 0.70});

  final MatchingStrategy strategy;
  final double threshold;

  double compare(LostReport lost, FoundItem found) {
    return strategy.calculateScore(lost, found);
  }

  List<MatchResult> findPossibleMatches(
    LostReport lost,
    List<FoundItem> foundItems,
  ) {
    final results = <MatchResult>[];
    for (final found in foundItems) {
      if (found.status != 'available') continue;
      final score = strategy.calculateScore(lost, found);
      if (score >= threshold) {
        results.add(MatchResult(foundItem: found, score: score));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}
