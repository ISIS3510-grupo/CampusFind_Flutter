import '../../../core/models/found_item.dart';
import '../../../core/models/lost_report.dart';

abstract class MatchingStrategy {
  double calculateScore(LostReport lost, FoundItem found);
}
